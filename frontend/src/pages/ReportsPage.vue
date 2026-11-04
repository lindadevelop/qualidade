<script setup lang="ts">
import {useBrandKit} from '@/composables/useBrandKit'
import PageHeader from '@/components/PageHeader.vue'
import { computed, onMounted, ref, watch } from 'vue'
import VueApexCharts from 'vue3-apexcharts'
import { listOccurrencesPage, fetchAllOccurrences, listAreas, listOrigins, listProfiles, type OccurrenceSortKey } from '@/services/occurrences'
import { fetchDashboardMetrics, fetchByArea, fetchByOrigin, fetchActionsByResponsible } from '@/services/dashboard'
import { utils as XlsxUtils, writeFile as XlsxWrite } from 'xlsx'
import { formatDate } from '@/utils/format'
import { IconSearch } from '@tabler/icons-vue'
import TablePagination from '@/components/TablePagination.vue'

const {colors}=useBrandKit()
const origins = ref<any[]>([])
const areas = ref<any[]>([])
const profiles = ref<any[]>([])
const metrics = ref<any>({})
const byArea = ref<any[]>([])
const byOrigin = ref<any[]>([])
const byResp = ref<any[]>([])
const rows = ref<any[]>([])
const count = ref(0)
const loading = ref(true)
const exporting = ref(false)

const sortKey = ref<OccurrenceSortKey>('occurrence_date')
const sortDir = ref<'asc' | 'desc'>('desc')
const page = ref(1)
const perPage = ref(10)
const totalPages = computed(() => Math.max(1, Math.ceil(count.value / perPage.value)))

const filters = ref<{
  date_from: string; date_to: string; year: any; type: string;
  origin_id: string; area_id: string; responsible_user_id: string; status: string; search: string;
}>({
  date_from: '', date_to: '', year: '', type: '', origin_id: '', area_id: '', responsible_user_id: '', status: '', search: '',
})

const isDark = ref(document.documentElement.getAttribute('data-bs-theme') === 'dark')
const chartText = () => isDark.value ? '#b7b9d0' : '#5d596c'
const chartGrid = () => isDark.value ? '#3b3b53' : '#e7e7ef'

let searchTimer: ReturnType<typeof setTimeout> | null = null

onMounted(async () => {
  ;[origins.value, areas.value, profiles.value, metrics.value, byArea.value, byOrigin.value, byResp.value] =
    await Promise.all([listOrigins(), listAreas(), listProfiles(), fetchDashboardMetrics(), fetchByArea(), fetchByOrigin(), fetchActionsByResponsible()])
  await run()
})

async function run() {
  loading.value = true
  try {
    const res = await listOccurrencesPage({
      year: filters.value.year || null,
      type: (filters.value.type || null) as any,
      origin_id: filters.value.origin_id || null,
      area_id: filters.value.area_id || null,
      responsible_user_id: filters.value.responsible_user_id || null,
      status: (filters.value.status || null) as any,
      date_from: filters.value.date_from || null,
      date_to: filters.value.date_to || null,
      search: filters.value.search,
      tab: 'all',
      orderBy: sortKey.value,
      ascending: sortDir.value === 'asc',
      offset: (page.value - 1) * perPage.value,
      limit: perPage.value,
    })
    rows.value = res.rows
    count.value = res.count
  } finally {
    loading.value = false
  }
}

function sort(col: OccurrenceSortKey) {
  if (sortKey.value === col) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  else { sortKey.value = col; sortDir.value = 'asc' }
  page.value = 1
  run()
}
function go(p: number) { if (p >= 1 && p <= totalPages.value) { page.value = p; run() } }
function onSearch() {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { page.value = 1; run() }, 350)
}
watch(perPage, () => { page.value = 1; run() })
function sortIcon(col: OccurrenceSortKey) {
  if (sortKey.value !== col) return ''
  return sortDir.value === 'asc' ? '↑' : '↓'
}

const summary = ref([
  { label: 'NC abertas', key: 'open_nc' },
  { label: 'OM abertas', key: 'open_om' },
  { label: 'Ações em atraso', key: 'overdue_actions' },
  { label: 'A aguardar eficácia', key: 'awaiting_effectiveness' },
  { label: 'Encerradas', key: 'closed' },
  { label: 'Ações abertas', key: 'total_actions_open' },
])

async function exportExcel() {
  exporting.value = true
  try {
    const all = await fetchAllOccurrences({
      year: filters.value.year || null,
      type: (filters.value.type || null) as any,
      origin_id: filters.value.origin_id || null,
      area_id: filters.value.area_id || null,
      responsible_user_id: filters.value.responsible_user_id || null,
      status: (filters.value.status || null) as any,
      date_from: filters.value.date_from || null,
      date_to: filters.value.date_to || null,
      tab: 'all',
    })
    const data = all.map(r => ({
      Referência: r.reference, Tipo: r.type, Descrição: r.description,
      Origem: r.quality_origins?.name, Área: r.quality_areas?.name,
      Responsável: r.profiles?.full_name, Estado: r.status, Data: formatDate(r.occurrence_date),
    }))
    const ws = XlsxUtils.json_to_sheet(data)
    const wb = XlsxUtils.book_new()
    XlsxUtils.book_append_sheet(wb, ws, 'Ocorrências')
    XlsxWrite(wb, 'samsys_qualidade_ocorrencias.xlsx')
  } finally {
    exporting.value = false
  }
}

function exportPdf() {
  window.print()
}
</script>

<template>
  <div>
    <PageHeader><template #title>Relatórios da Qualidade</template><template #breadcrumb>Análise › Relatórios</template></PageHeader>

    <div class="sq-card mb-3">
      <div class="row g-2 align-items-end">
        <div class="col-md-3"><label class="form-label small">Pesquisar</label>
          <div class="input-group">
            <span class="input-group-text"><IconSearch :size="15" /></span>
            <input v-model="filters.search" class="form-control" placeholder="Ref ou descrição…" @input="onSearch" />
          </div>
        </div>
        <div class="col-md-3"><label class="form-label small">De</label><PtDateInput v-model="filters.date_from" type="date" class="form-control" @change="run" /></div>
        <div class="col-md-3"><label class="form-label small">Até</label><PtDateInput v-model="filters.date_to" type="date" class="form-control" @change="run" /></div>
        <div class="col-md-2"><label class="form-label small">Ano</label><select v-model="filters.year" class="form-select" @change="run"><option :value="''">Todos</option><option value="2026">2026</option><option value="2025">2025</option></select></div>
        <div class="col-md-2"><label class="form-label small">Tipo</label><select v-model="filters.type" class="form-select" @change="run"><option value="">Todos</option><option value="NC">NC</option><option value="OM">OM</option></select></div>
        <div class="col-md-2"><label class="form-label small">Origem</label><select v-model="filters.origin_id" class="form-select" @change="run"><option :value="''">Todas</option><option v-for="o in origins" :value="o.id">{{ o.name }}</option></select></div>
        <div class="col-md-2"><label class="form-label small">Área</label><select v-model="filters.area_id" class="form-select" @change="run"><option :value="''">Todas</option><option v-for="a in areas" :value="a.id">{{ a.name }}</option></select></div>
        <div class="col-md-2"><label class="form-label small">Estado</label><select v-model="filters.status" class="form-select" @change="run"><option value="">Todos</option><option value="OPEN">Aberta</option><option value="IN_PROGRESS">Em curso</option><option value="AWAITING_EFFECTIVENESS">A aguardar eficácia</option><option value="CLOSED">Encerrada</option></select></div>
        <div class="col-md-auto d-flex gap-2">
          <button class="btn btn-primary"  @click="run">Gerar</button>
          <button class="btn btn-success" @click="exportExcel" :disabled="exporting">{{ exporting ? 'A gerar…' : 'Excel' }}</button>
          <button class="btn btn-outline-secondary" @click="exportPdf">PDF</button>
        </div>
      </div>
    </div>

    <div class="row g-3 mb-3">
      <div v-for="s in summary" :key="s.key" class="col-sm-4 col-xl-2">
        <div class="sq-card text-center">
          <div class="sq-kpi-value">{{ metrics[s.key] ?? 0 }}</div>
          <div class="sq-kpi-label">{{ s.label }}</div>
        </div>
      </div>
    </div>

    <div class="row g-3 mb-3">
      <div class="col-xl-6"><div class="sq-card">
        <h6 class="sq-card-title">Indicadores por área</h6>
        <VueApexCharts type="bar" height="260" :options="{chart:{toolbar:{show:false},foreColor:chartText()},colors:[colors.secondary],plotOptions:{bar:{borderRadius:4,horizontal:true}},grid:{borderColor:chartGrid()},yaxis:{labels:{style:{colors:chartText()}}},...( { yaxis:{categories:byArea.map(a=>a.area_name)} } as any)}" :series="[{name:'Ocorrências',data:byArea.map(a=>a.cnt)}]" />
      </div></div>
      <div class="col-xl-6"><div class="sq-card">
        <h6 class="sq-card-title">Indicadores por responsável</h6>
        <div v-for="r in byResp.slice(0,6)" :key="r.full_name" class="d-flex justify-content-between py-1 border-bottom">
          <span>{{ r.full_name }}</span><span class="sq-muted">{{ r.open_cnt }} abertas · {{ r.overdue }} atrasadas</span>
        </div>
      </div></div>
    </div>

    <div class="sq-card" id="report-table">
      <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
        <h6 class="sq-card-title mb-0">Ocorrências ({{ count }})</h6>
        <div v-if="count" class="sq-muted" style="font-size:.78rem">{{ (page-1)*perPage+1 }}–{{ Math.min(page*perPage, count) }} de {{ count }}</div>
      </div>
      <div class="table-responsive">
        <table class="sq-table">
          <thead><tr>
            <th @click="sort('reference')" title="Ordenar por referência" style="cursor:pointer">Ref {{ sortIcon('reference') }}</th>
            <th @click="sort('type')" title="Ordenar por tipo" style="cursor:pointer">Tipo {{ sortIcon('type') }}</th>
            <th>Descrição</th>
            <th>Origem</th>
            <th @click="sort('area')" title="Ordenar por área" style="cursor:pointer">Área {{ sortIcon('area') }}</th>
            <th @click="sort('status')" title="Ordenar por estado" style="cursor:pointer">Estado {{ sortIcon('status') }}</th>
            <th @click="sort('occurrence_date')" title="Ordenar por data" style="cursor:pointer">Data {{ sortIcon('occurrence_date') }}</th>
          </tr></thead>
          <tbody>
            <tr v-for="r in rows" :key="r.id">
              <td class="sq-ref">{{ r.reference }}</td>
              <td><span class="sq-badge" :class="r.type==='NC' ? 'badge-soft-danger' : 'badge-soft-primary'">{{ r.type }}</span></td>
              <td style="max-width:260px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ r.description }}</td>
              <td>{{ r.quality_origins?.name }}</td>
              <td>{{ r.quality_areas?.name }}</td>
              <td>{{ r.status }}</td>
              <td>{{ formatDate(r.occurrence_date) }}</td>
            </tr>
          </tbody>
        </table>
        <div v-if="!rows.length" class="sq-empty">Sem registos para os filtros selecionados.</div>
      </div>

      <!-- paginação server-side -->
      <TablePagination
        v-if="count > perPage"
        :page="page" :per-page="perPage" :total="count"
        @update:page="go" @update:per-page="perPage = $event" />
    </div>
  </div>
</template>
