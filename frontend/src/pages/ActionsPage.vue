<script setup lang="ts">
import {API_BASE} from '@/lib/api-base'

import PageHeader from '@/components/PageHeader.vue'
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { IconSearch } from '@tabler/icons-vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { actionStatusBadge, actionStatusLabel, deadlineLabel, deadlineTone, formatDate } from '@/utils/format'
import TablePagination from '@/components/TablePagination.vue'
import GroupHeader from '@/components/GroupHeader.vue'

const router = useRouter()
const auth = useAuthStore()

type SortKey = 'reference' | 'deadline' | 'status' | 'responsible'

const rows = ref<any[]>([])
const loading = ref(true)
const tab = ref<'all'|'mine'|'overdue'|'done'>('all')
const search = ref('')
const sortKey = ref<SortKey>('deadline')
const sortDir = ref<'asc'|'desc'>('asc')
const groupBy = ref<'none'|'status'|'responsible'>('status')
const page = ref(1)
const perPage = ref(10)
const total = ref(0)
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / perPage.value)))

let searchTimer: ReturnType<typeof setTimeout> | null = null

async function load() {
  loading.value = true
  // Usar fetch direto ao proxy REST (controlo total da sintaxe).
  // O supabase-js com foreignTable gera "profiles.order=..." que o PostgREST ignora;
  // a forma correta de ordenar por relação é "order=profiles(full_name).asc".
  const { data: s } = await supabase.auth.getSession()
  const token = s.session?.access_token
  if (!token) { loading.value = false; return }

  const params = new URLSearchParams({
    select: 'id,reference,description,deadline,status,occurrence_id,responsible_user_id,quality_occurrences(reference),profiles:responsible_user_id(full_name)',
  })

  if (tab.value === 'mine' && auth.profile) params.set('responsible_user_id', `eq.${auth.profile.id}`)
  if (tab.value === 'overdue') {
    params.set('status', 'in.("TODO","IN_PROGRESS")')
    params.set('deadline', `lt.${new Date().toISOString().slice(0, 10)}`)
  }
  if (tab.value === 'done') params.set('status', 'eq.COMPLETED')
  if (search.value.trim()) {
    const t = search.value.trim().replace(/%/g, '')
    params.set('or', `(reference.ilike.*${t}*,description.ilike.*${t}*)`)
  }

  const orderBy: Record<SortKey, string> = {
    reference: 'reference', deadline: 'deadline', status: 'status', responsible: 'full_name',
  }
  const orderCol = sortKey.value === 'responsible' ? 'profiles(full_name)' : orderBy[sortKey.value]
  params.set('order', `${orderCol}.${sortDir.value}${sortKey.value === 'deadline' && sortDir.value === 'asc' ? '.nullsfirst' : ''}`)

  const from = (page.value - 1) * perPage.value
  const url = `${API_BASE}/rest/v1/quality_actions?${params.toString()}&offset=${from}&limit=${perPage.value}`

  const res = await fetch(url, {
    headers: {
      apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
      Authorization: `Bearer ${token}`,
      Prefer: 'count=exact',
    },
  })
  if (!res.ok) {
    const j = await res.json().catch(() => null)
    if (j?.code === 'PGRST103') {
      // não há filtros dessa combinação -> sem resultados
      rows.value = []; total.value = 0
    } else { rows.value = []; total.value = 0 }
    loading.value = false
    return
  }
  const data = await res.json()
  rows.value = data ?? []
  const cr = res.headers.get('content-range') || ''
  // content-range: <from>-<to>/<total>
  const m = cr.match(/\/(\d+)$/)
  total.value = m ? Number(m[1]) : rows.value.length
  if (page.value > totalPages.value) page.value = totalPages.value
  loading.value = false
}

function onSearch() {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { page.value = 1; load() }, 350)
}
function sort(col: SortKey) {
  if (sortKey.value === col) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  else { sortKey.value = col; sortDir.value = 'asc' }
  page.value = 1
  load()
}
function go(p: number) { if (p >= 1 && p <= totalPages.value) { page.value = p; load() } }
function switchTab(t: 'all'|'mine'|'overdue'|'done') { tab.value = t; page.value = 1; load() }

watch(perPage, () => { page.value = 1; load() })
onMounted(load)

// grupos colapsados (por chave do grupo)
const collapsed = ref<Set<string>>(new Set())
function toggleGroup(key: string) {
  const s = new Set(collapsed.value)
  s.has(key) ? s.delete(key) : s.add(key)
  collapsed.value = s
}

// agrupamento das linhas da página atual (por estado ou responsável)
const grouped = computed(() => {
  if (groupBy.value === 'none' || !rows.value.length) return [{ key: '', items: rows.value }]
  const map = new Map<string, any[]>()
  for (const r of rows.value) {
    const k = groupBy.value === 'status' ? (actionStatusLabel(r.status) || 'Indefinido')
      : (r.profiles?.full_name || 'Sem responsável')
    if (!map.has(k)) map.set(k, [])
    map.get(k)!.push(r)
  }
  return [...map.entries()].map(([key, items]) => ({ key, items }))
})

function sortIcon(col: SortKey) {
  if (sortKey.value !== col) return ''
  return sortDir.value === 'asc' ? '↑' : '↓'
}
</script>

<template>
  <div>
    <PageHeader><template #title>Plano de Ações</template><template #breadcrumb>Plano de Ações › Todas as Ações</template></PageHeader>

    <div class="sq-tabs">
      <button class="sq-tab" :class="{active:tab==='all'}" @click="switchTab('all')">Todas</button>
      <button class="sq-tab" :class="{active:tab==='mine'}" @click="switchTab('mine')">Minhas</button>
      <button class="sq-tab" :class="{active:tab==='overdue'}" @click="switchTab('overdue')">Em atraso</button>
      <button class="sq-tab" :class="{active:tab==='done'}" @click="switchTab('done')">Concluídas</button>
    </div>

    <div class="sq-card">
      <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-2">
        <div class="input-group" style="max-width:340px">
          <span class="input-group-text sq-muted"><IconSearch :size="16" /></span>
          <input v-model="search" class="form-control form-control-sm" placeholder="Pesquisar por ref, descrição ou responsável…" @input="onSearch" />
        </div>
        <div class="d-flex align-items-center gap-2 flex-wrap">
          <div class="sq-muted" style="font-size:.78rem">{{ total }} ação(ões)</div>
          <select v-model="groupBy" class="form-select form-select-sm" style="max-width:170px">
            <option value="none">Sem agrupamento</option>
            <option value="status">Agrupar por estado</option>
            <option value="responsible">Agrupar por responsável</option>
          </select>
        </div>
      </div>

      <div v-if="loading" class="sq-skeleton" style="height:200px"></div>
      <div v-else class="table-responsive">
        <table class="sq-table">
          <thead>
            <tr>
              <th @click="sort('reference')" title="Ordenar por ID" style="cursor:pointer">ID {{ sortIcon('reference') }}</th>
              <th @click="sort('reference')" title="Ordenar por ocorrência" style="cursor:pointer">Ocorrência {{ sortIcon('reference') }}</th>
              <th>Ação</th>
              <th @click="sort('responsible')" title="Ordenar por responsável" style="cursor:pointer">Responsável {{ sortIcon('responsible') }}</th>
              <th @click="sort('deadline')" title="Ordenar por prazo" style="cursor:pointer">Prazo {{ sortIcon('deadline') }}</th>
              <th @click="sort('status')" title="Ordenar por estado" style="cursor:pointer">Estado {{ sortIcon('status') }}</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="grp in grouped" :key="grp.key">
              <GroupHeader
                v-if="groupBy!=='none'"
                :label="grp.key" :count="grp.items.length" :cols="6"
                :collapsed="collapsed.has(grp.key)" @toggle="toggleGroup(grp.key)" />
              <tr v-for="r in grp.items" v-if="groupBy==='none' || !collapsed.has(grp.key)" :key="r.id" style="cursor:pointer" @click="r.occurrence_id && router.push('/ocorrencias/' + r.occurrence_id)">
                <td class="sq-ref">{{ r.reference }}</td>
                <td style="color:var(--sq-heading)">{{ r.quality_occurrences?.reference }}</td>
                <td style="max-width:280px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ r.description }}</td>
                <td>{{ r.profiles?.full_name ?? '—' }}</td>
                <td>
                  <span class="sq-badge" :class="deadlineTone(r.deadline, r.status==='COMPLETED') === 'overdue' ? 'badge-soft-danger' : deadlineTone(r.deadline, r.status==='COMPLETED') === 'today' ? 'badge-soft-warning' : r.status==='COMPLETED' ? 'badge-soft-success' : 'badge-soft-secondary'">
                    {{ deadlineLabel(r.deadline, r.status==='COMPLETED') }}
                  </span>
                </td>
                <td><span class="sq-badge" :class="actionStatusBadge(r.status)">{{ actionStatusLabel(r.status) }}</span></td>
              </tr>
            </template>
          </tbody>
        </table>
        <div v-if="!rows.length" class="sq-empty">Sem ações neste filtro.</div>

        <!-- paginação server-side -->
        <TablePagination
          v-if="total > perPage"
          :page="page" :per-page="perPage" :total="total"
          @update:page="go" @update:per-page="perPage = $event" />
      </div>
    </div>
  </div>
</template>