<script setup lang="ts">
import {API_BASE} from '@/lib/api-base'

import PageHeader from '@/components/PageHeader.vue'
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { IconSearch } from '@tabler/icons-vue'
import { supabase } from '@/lib/supabase'
import { occurrenceTypeBadge, formatDate } from '@/utils/format'
import TablePagination from '@/components/TablePagination.vue'
import GroupHeader from '@/components/GroupHeader.vue'

const router = useRouter()
const rows = ref<any[]>([])
const loading = ref(true)
const error = ref('')
const mode = ref<'pending' | 'history'>('pending')
const search = ref('')
const sortKey = ref<'reference' | 'occurrence_date' | 'area' | 'status'>('occurrence_date')
const sortDir = ref<'asc' | 'desc'>('desc')
const groupBy = ref<'none' | 'status' | 'area'>('none')
const page = ref(1)
const perPage = ref(10)
const count = ref(0)
const totalPages = computed(() => Math.max(1, Math.ceil(count.value / perPage.value)))

let searchTimer: ReturnType<typeof setTimeout> | null = null

async function load() {
  loading.value = true
  error.value = ''
  const { data: s } = await supabase.auth.getSession()
  const token = s.session?.access_token
  if (!token) { loading.value = false; return }

  const params = new URLSearchParams({
    select: 'id,reference,type,description,status,occurrence_date,area_id,effectiveness_status,effectiveness_validated_at,quality_areas(name)',
  })

  if (mode.value === 'pending') params.set('status', 'eq.AWAITING_EFFECTIVENESS')
  else params.set('effectiveness_validated_at', 'not.is.null')

  if (search.value.trim()) {
    const t = search.value.trim().replace(/%/g, '')
    params.set('or', `(reference.ilike.*${t}*,description.ilike.*${t}*)`)
  }

  const ORDER: Record<string, string> = {
    reference: 'reference', occurrence_date: 'occurrence_date', status: 'status', area: 'quality_areas(name)',
  }
  params.set('order', `${ORDER[sortKey.value]}.${sortDir.value}`)

  const offset = (page.value - 1) * perPage.value
  const url = `${API_BASE}/rest/v1/quality_occurrences?${params.toString()}&offset=${offset}&limit=${perPage.value}`

  try {
    const res = await fetch(url, {
      headers: { apikey: import.meta.env.VITE_SUPABASE_ANON_KEY, Authorization: `Bearer ${token}`, Prefer: 'count=exact' },
    })
    if (!res.ok) throw new Error(`Erro (${res.status})`)
    const data = await res.json()
    rows.value = data ?? []
    const cr = res.headers.get('content-range') || ''
    const m = cr.match(/\/(\d+)$/)
    count.value = m ? Number(m[1]) : rows.value.length
  } catch (e) {
    error.value = (e as Error).message
    rows.value = []
  } finally {
    loading.value = false
  }
}

function switchMode(m: 'pending' | 'history') { mode.value = m; page.value = 1; load() }
function sort(col: 'reference' | 'occurrence_date' | 'area' | 'status') {
  if (sortKey.value === col) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  else { sortKey.value = col; sortDir.value = 'asc' }
  page.value = 1
  load()
}
function go(p: number) { if (p >= 1 && p <= totalPages.value) { page.value = p; load() } }
function onSearch() {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { page.value = 1; load() }, 350)
}
watch(perPage, () => { page.value = 1; load() })
onMounted(load)

// grupos colapsados (por chave do grupo)
const collapsed = ref<Set<string>>(new Set())
function toggleGroup(key: string) {
  const s = new Set(collapsed.value)
  s.has(key) ? s.delete(key) : s.add(key)
  collapsed.value = s
}

const grouped = computed(() => {
  if (groupBy.value === 'none' || !rows.value.length) return [{ key: '', items: rows.value }]
  const map = new Map<string, any[]>()
  for (const r of rows.value) {
    const k = groupBy.value === 'status'
      ? (r.effectiveness_status === 'EFFECTIVE' ? 'Eficaz' : 'Não eficaz')
      : (r.quality_areas?.name || 'Sem área')
    if (!map.has(k)) map.set(k, [])
    map.get(k)!.push(r)
  }
  return [...map.entries()].map(([key, items]) => ({ key, items }))
})

function sortIcon(col: string) {
  if (sortKey.value !== col) return ''
  return sortDir.value === 'asc' ? '↑' : '↓'
}
</script>

<template>
  <div>
    <PageHeader><template #title>Eficácia</template><template #breadcrumb>Eficácia › {{ mode==='pending' ? 'A aguardar validação' : 'Histórico de validações' }}</template></PageHeader>

    <div class="sq-tabs">
      <button class="sq-tab" :class="{active:mode==='pending'}" @click="switchMode('pending')">A aguardar validação</button>
      <button class="sq-tab" :class="{active:mode==='history'}" @click="switchMode('history')">Histórico de validações</button>
    </div>

    <div class="sq-card">
      <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-2">
        <div class="input-group" style="max-width:340px">
          <span class="input-group-text sq-muted"><IconSearch :size="16" /></span>
          <input v-model="search" class="form-control form-control-sm" placeholder="Pesquisar por ref ou descrição…" @input="onSearch" />
        </div>
        <div class="d-flex align-items-center gap-2 flex-wrap">
          <div class="sq-muted" style="font-size:.78rem">{{ count }} ocorrência(s)</div>
          <select v-model="groupBy" class="form-select form-select-sm" style="max-width:190px">
            <option value="none">Sem agrupamento</option>
            <option value="status">Agrupar por resultado</option>
            <option value="area">Agrupar por área</option>
          </select>
        </div>
      </div>

      <div v-if="loading" class="sq-skeleton" style="height:200px"></div>
      <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
      <div v-else>
        <div class="table-responsive">
          <table class="sq-table">
            <thead>
              <tr>
                <th @click="sort('reference')" title="Ordenar por ID" style="cursor:pointer">ID {{ sortIcon('reference') }}</th>
                <th @click="sort('reference')" title="Ordenar por tipo" style="cursor:pointer">Tipo {{ sortIcon('reference') }}</th>
                <th>Ação/Ocorrência</th>
                <th @click="sort('area')" title="Ordenar por área" style="cursor:pointer">Área {{ sortIcon('area') }}</th>
                <th @click="sort('occurrence_date')" title="Ordenar por data" style="cursor:pointer">Data {{ sortIcon('occurrence_date') }}</th>
                <th v-if="mode==='history'" @click="sort('status')" title="Ordenar por resultado" style="cursor:pointer">Resultado {{ sortIcon('status') }}</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="grp in grouped" :key="grp.key">
                <GroupHeader
                  v-if="groupBy!=='none'"
                  :label="grp.key" :count="grp.items.length" :cols="mode==='history' ? 6 : 5"
                  :collapsed="collapsed.has(grp.key)" @toggle="toggleGroup(grp.key)" />
                <tr v-for="r in grp.items" v-if="groupBy==='none' || !collapsed.has(grp.key)" :key="r.id" style="cursor:pointer" @click="router.push('/ocorrencias/'+r.id)">
                  <td class="sq-ref">{{ r.reference }}</td>
                  <td><span class="sq-badge" :class="occurrenceTypeBadge(r.type)">{{ r.type }}</span></td>
                  <td style="max-width:340px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ r.description }}</td>
                  <td>{{ r.quality_areas?.name || '—' }}</td>
                  <td class="sq-muted">{{ formatDate(r.occurrence_date) }}</td>
                  <td v-if="mode==='history'">
                    <span class="sq-badge" :class="r.effectiveness_status==='EFFECTIVE'?'badge-soft-success':'badge-soft-danger'">
                      {{ r.effectiveness_status==='EFFECTIVE' ? 'Eficaz' : 'Não eficaz' }}
                    </span>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
        <div v-if="!rows.length" class="sq-empty">
          {{ mode==='pending' ? 'Sem ocorrências a aguardar validação de eficácia 🎉' : 'Sem histórico de validações.' }}
        </div>

        <!-- paginação server-side -->
        <TablePagination
          v-if="count > perPage"
          :page="page" :per-page="perPage" :total="count"
          @update:page="go" @update:per-page="perPage = $event" />
      </div>
    </div>
  </div>
</template>