<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  IconPlus, IconSearch, IconRefresh, IconChevronRight,
} from '@tabler/icons-vue'
import { listOccurrencesPage, listAreas, listOrigins, listProfiles, type OccurrenceFilters, type OccurrenceRow, type OccurrenceSortKey } from '@/services/occurrences'
import { useAuthStore } from '@/stores/auth'
import TablePagination from '@/components/TablePagination.vue'
import GroupHeader from '@/components/GroupHeader.vue'
import {
  occurrenceTypeBadge, occurrenceStatusBadge, occurrenceStatusLabel, formatDate, initials,
} from '@/utils/format'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const rows = ref<OccurrenceRow[]>([])
const count = ref(0)
const loading = ref(true)
const error = ref('')

const areas = ref<any[]>([])
const origins = ref<any[]>([])
const profiles = ref<any[]>([])

const tab = ref<'open' | 'all' | 'closed'>((route.query.tab as any) || 'open')
const filters = ref<OccurrenceFilters>({
  year: route.query.year ? Number(route.query.year) : new Date().getFullYear(),
  type: (route.query.type as any) || '',
  origin_id: (route.query.origin as any) || null,
  area_id: (route.query.area as any) || null,
  responsible_user_id: (route.query.responsible as any) || null,
  status: (route.query.status as any) || '',
  search: '',
})

const sortKey = ref<OccurrenceSortKey>('occurrence_date')
const sortDir = ref<'asc' | 'desc'>('desc')
const groupBy = ref<'none' | 'status' | 'type' | 'area' | 'responsible'>('status')
const page = ref(1)
const perPage = ref(10)
const totalPages = computed(() => Math.max(1, Math.ceil(count.value / perPage.value)))

const yearOpts = computed(() => {
  const y = new Date().getFullYear()
  return [y - 1, y, y + 1]
})

let searchTimer: ReturnType<typeof setTimeout> | null = null

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await listOccurrencesPage({
      ...filters.value,
      tab: tab.value,
      orderBy: sortKey.value,
      ascending: sortDir.value === 'asc',
      offset: (page.value - 1) * perPage.value,
      limit: perPage.value,
    })
    rows.value = res.rows
    count.value = res.count
    if (page.value > totalPages.value) page.value = totalPages.value
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  ;[areas.value, origins.value, profiles.value] = await Promise.all([listAreas(), listOrigins(), listProfiles()])
  await load()
})

function setTab(t: 'open' | 'all' | 'closed') {
  tab.value = t
  page.value = 1
  if (t === 'all') filters.value.status = ''
  void load()
}
function applyFilters() { page.value = 1; void load() }
function reset() {
  filters.value = { year: new Date().getFullYear(), type: '', origin_id: null, area_id: null, responsible_user_id: null, status: '', search: '' }
  page.value = 1
  void load()
}
function sort(col: OccurrenceSortKey) {
  if (sortKey.value === col) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  else { sortKey.value = col; sortDir.value = 'asc' }
  page.value = 1
  load()
}
function go(p: number) { if (p >= 1 && p <= totalPages.value) { page.value = p; load() } }
function onSearch() {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(applyFilters, 350)
}
watch(perPage, () => { page.value = 1; load() })

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
    const k = groupBy.value === 'status' ? (occurrenceStatusLabel(r.status) || 'Indefinido')
      : groupBy.value === 'type' ? (r.type || '—')
      : groupBy.value === 'area' ? (r.quality_areas?.name || 'Sem área')
      : (r.profiles?.full_name || 'Sem responsável')
    if (!map.has(k)) map.set(k, [])
    map.get(k)!.push(r)
  }
  return [...map.entries()].map(([key, items]) => ({ key, items }))
})

function statusLabel(s: string) { return occurrenceStatusLabel(s) }
function sortIcon(col: OccurrenceSortKey) {
  if (sortKey.value !== col) return ''
  return sortDir.value === 'asc' ? '↑' : '↓'
}
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-end flex-wrap gap-2">
      <div>
        <PageHeader><template #title>Não Conformidades / Oportunidades de Melhoria</template><template #breadcrumb>Qualidade › Ocorrências</template></PageHeader>
      </div>
      <router-link v-if="auth.canManage" to="/ocorrencias/nova" class="btn btn-primary d-flex align-items-center gap-1" style="background:#7367f0;border-color:#7367f0">
        <IconPlus :size="16" /> Nova ocorrência
      </router-link>
    </div>

    <div class="sq-tabs">
      <button class="sq-tab" :class="{ active: tab === 'open' }" @click="setTab('open')">Abertas</button>
      <button class="sq-tab" :class="{ active: tab === 'all' }" @click="setTab('all')">Todas</button>
      <button class="sq-tab" :class="{ active: tab === 'closed' }" @click="setTab('closed')">Encerradas</button>
    </div>

    <!-- Filtros -->
    <div class="sq-card mb-3">
      <div class="row g-2 align-items-end">
        <div class="col-12 col-md">
          <label class="form-label small sq-muted mb-1">Pesquisar</label>
          <div class="input-group">
            <span class="input-group-text"><IconSearch :size="15" /></span>
            <input v-model="filters.search" class="form-control" placeholder="Referência ou descrição…" @input="onSearch" />
          </div>
        </div>
        <div class="col-6 col-md-2">
          <label class="form-label small sq-muted mb-1">Ano</label>
          <select v-model="filters.year" class="form-select" @change="applyFilters">
            <option :value="null">Todos</option>
            <option v-for="y in yearOpts" :value="y" :key="y">{{ y }}</option>
          </select>
        </div>
        <div class="col-6 col-md-2">
          <label class="form-label small sq-muted mb-1">Tipo</label>
          <select v-model="filters.type" class="form-select" @change="applyFilters">
            <option value="">Todos</option>
            <option value="NC">NC</option>
            <option value="OM">OM</option>
          </select>
        </div>
        <div class="col-6 col-md-2">
          <label class="form-label small sq-muted mb-1">Estado</label>
          <select v-model="filters.status" class="form-select" @change="applyFilters">
            <option value="">Todos</option>
            <option value="OPEN">Aberta</option>
            <option value="IN_PROGRESS">Em curso</option>
            <option value="AWAITING_EFFECTIVENESS">A aguardar eficácia</option>
            <option value="CLOSED">Encerrada</option>
          </select>
        </div>
        <div class="col-6 col-md-2">
          <label class="form-label small sq-muted mb-1">Origem</label>
          <select v-model="filters.origin_id" class="form-select" @change="applyFilters">
            <option :value="null">Todas</option>
            <option v-for="o in origins" :value="o.id" :key="o.id">{{ o.name }}</option>
          </select>
        </div>
        <div class="col-6 col-md-2">
          <label class="form-label small sq-muted mb-1">Área</label>
          <select v-model="filters.area_id" class="form-select" @change="applyFilters">
            <option :value="null">Todas</option>
            <option v-for="a in areas" :value="a.id" :key="a.id">{{ a.name }}</option>
          </select>
        </div>
        <div class="col-6 col-md-2">
          <label class="form-label small sq-muted mb-1">Responsável</label>
          <select v-model="filters.responsible_user_id" class="form-select" @change="applyFilters">
            <option :value="null">Todos</option>
            <option v-for="p in profiles" :value="p.id" :key="p.id">{{ p.full_name }}</option>
          </select>
        </div>
        <div class="col-12 col-md-auto d-flex gap-2">
          <button class="btn btn-outline-secondary" @click="reset"><IconRefresh :size="15" /> Limpar</button>
        </div>
      </div>
    </div>

    <div v-if="error" class="alert alert-danger">{{ error }}</div>

    <div class="sq-card">
      <div v-if="loading" class="row g-3 p-1">
        <div v-for="i in 6" :key="i"><div class="sq-skeleton" style="height:36px"></div></div>
      </div>
      <template v-else>
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-2">
          <div class="sq-muted" style="font-size:.78rem">{{ count }} ocorrência(s)</div>
          <select v-model="groupBy" class="form-select form-select-sm" style="max-width:200px">
            <option value="none">Sem agrupamento</option>
            <option value="status">Agrupar por estado</option>
            <option value="type">Agrupar por tipo</option>
            <option value="area">Agrupar por área</option>
            <option value="responsible">Agrupar por responsável</option>
          </select>
        </div>

        <div class="table-responsive">
          <table class="sq-table">
            <thead>
              <tr>
                <th @click="sort('reference')" title="Ordenar por ID" style="cursor:pointer">ID {{ sortIcon('reference') }}</th>
                <th @click="sort('type')" title="Ordenar por tipo" style="cursor:pointer">Tipo {{ sortIcon('type') }}</th>
                <th>Descrição</th>
                <th @click="sort('area')" title="Ordenar por área" style="cursor:pointer">Área {{ sortIcon('area') }}</th>
                <th @click="sort('responsible')" title="Ordenar por responsável" style="cursor:pointer">Responsável {{ sortIcon('responsible') }}</th>
                <th @click="sort('status')" title="Ordenar por estado" style="cursor:pointer">Estado {{ sortIcon('status') }}</th>
                <th @click="sort('occurrence_date')" title="Ordenar por data" style="cursor:pointer">Data {{ sortIcon('occurrence_date') }}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <template v-for="grp in grouped" :key="grp.key">
                <GroupHeader
                  v-if="groupBy!=='none'"
                  :label="grp.key" :count="grp.items.length" :cols="8"
                  :collapsed="collapsed.has(grp.key)" @toggle="toggleGroup(grp.key)" />
                <tr v-for="r in grp.items" v-if="groupBy==='none' || !collapsed.has(grp.key)" :key="r.id" style="cursor:pointer" @click="router.push('/ocorrencias/' + r.id)">
                  <td class="sq-ref">{{ r.reference }}</td>
                  <td><span class="sq-badge" :class="occurrenceTypeBadge(r.type)">{{ r.type }}</span></td>
                  <td style="max-width:280px">
                    <div style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ r.description }}</div>
                  </td>
                  <td>{{ r.quality_areas?.name ?? '—' }}</td>
                  <td>
                    <span v-if="r.profiles?.full_name" class="d-flex align-items-center gap-2">
                      <span class="sq-avatar" style="width:22px;height:22px;font-size:.6rem">{{ initials(r.profiles.full_name) }}</span>
                      {{ r.profiles.full_name }}
                    </span>
                    <span v-else class="sq-muted">—</span>
                  </td>
                  <td><span class="sq-badge" :class="occurrenceStatusBadge(r.status)">{{ statusLabel(r.status) }}</span></td>
                  <td class="sq-muted">{{ formatDate(r.occurrence_date) }}</td>
                  <td><IconChevronRight :size="16" class="sq-muted" /></td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
        <div v-if="!rows.length" class="sq-empty">
          <p class="mb-1 fw-semibold" style="color:var(--sq-heading)">Nenhuma ocorrência</p>
          <p class="sq-muted" style="font-size:.85rem">Ajusta os filtros ou cria uma nova ocorrência.</p>
        </div>

        <!-- paginação server-side -->
        <TablePagination
          v-if="count > perPage"
          :page="page" :per-page="perPage" :total="count"
          @update:page="go" @update:per-page="perPage = $event" />
      </template>
    </div>
  </div>
</template>