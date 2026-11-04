<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import VueApexCharts from 'vue3-apexcharts'
import {
  IconAlertTriangle, IconArrowUpCircle, IconBan, IconTarget, IconChevronRight, IconMaximize, IconX,
} from '@tabler/icons-vue'
import {
  fetchDashboardMetrics, fetchEvolution, fetchByStatus, fetchByOrigin, fetchByArea,
  fetchActionsByResponsible, fetchUrgentActions, fetchQualityHealth, type DashboardMetrics,
} from '@/services/dashboard'
import { useAuthStore } from '@/stores/auth'
import {
  OCCURRENCE_STATUS_LABEL, deadlineLabel, deadlineTone, initials,
} from '@/utils/format'

const router = useRouter()
const auth = useAuthStore()

const loading = ref(true)
const error = ref('')
const metrics = ref<DashboardMetrics | null>(null)
const health = ref<any | null>(null) // eslint-disable-line @typescript-eslint/no-explicit-any
const evolution = ref<any[]>([])
const byStatus = ref<any[]>([])
const byOrigin = ref<any[]>([])
const byArea = ref<any[]>([])
const areaFullscreen = ref(false)
const topByArea = computed(() => byArea.value.slice(0, 7))
const byResponsible = ref<any[]>([])
const urgent = ref<any[]>([])
const trend = ref(12)

const isDark = computed(() => document.documentElement.getAttribute('data-bs-theme') === 'dark')
const chartText = computed(() => isDark.value ? '#b7b9d0' : '#5d596c')
const chartGrid = computed(() => isDark.value ? '#3b3b53' : '#e7e7ef')

onMounted(async () => {
  try {
    const [
      m, ev, st, or, ar, resp, urg,
    ] = await Promise.all([
      fetchDashboardMetrics(), fetchEvolution(trend.value), fetchByStatus(),
      fetchByOrigin(), fetchByArea(), fetchActionsByResponsible(), fetchUrgentActions(8),
    ])
    metrics.value = m; evolution.value = ev; byStatus.value = st; byOrigin.value = or
    // saúde operacional do Copiloto (aditivo — se falhar, não bloqueia o dashboard)
    fetchQualityHealth().then((h) => { health.value = h }).catch(() => { health.value = null })
    byArea.value = ar; byResponsible.value = resp; urgent.value = urg
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    loading.value = false
  }
})

async function reload() {
  loading.value = true
  try {
    evolution.value = await fetchEvolution(trend.value)
    byResponsible.value = await fetchActionsByResponsible()
    urgent.value = await fetchUrgentActions(8)
  } finally {
    loading.value = false
  }
}

// Segunda linha: Evolução (agregar por tipo/mês)
const evolutionSeries = computed(() => {
  const months = [...new Set(evolution.value.map((r) => r.period))].sort()
  const series: { name: string; data: number[] }[] = []
  for (const t of ['NC', 'OM', 'CLOSED']) {
    const key = t
    series.push({
      name: key.replace('CLOSED', 'Encerradas'),
      data: months.map((m) => evolution.value.find((r) => r.period === m && r.typeKey === key)?.cnt ?? 0),
    })
  }
  return series
})

const evolutionLabels = computed(() => [...new Set(evolution.value.map((r) => r.period))].sort())

// Donut por estado
const donut = computed(() => ({
  labels: (byStatus.value as any[]).map((s) => OCCURRENCE_STATUS_LABEL[s.status] ?? s.status),
  series: (byStatus.value as any[]).map((s) => s.cnt),
}))

// Relatório: evolução — ajustar agregar tipoKey a partir de type
const kpis = computed(() => [
  { label: 'NC Abertas', value: metrics.value?.open_nc ?? 0, icon: IconBan, color: '#ea5455', route: '/ocorrencias?tab=open&type=NC' },
  { label: 'OM Abertas', value: metrics.value?.open_om ?? 0, icon: IconTarget, color: '#7367f0', route: '/ocorrencias?tab=open&type=OM' },
  { label: 'Ações em atraso', value: metrics.value?.overdue_actions ?? 0, icon: IconAlertTriangle, color: '#ff9f43', route: '/acoes?tab=atraso' },
  { label: 'A aguardar eficácia', value: metrics.value?.awaiting_effectiveness ?? 0, icon: IconArrowUpCircle, color: '#00cfe8', route: '/eficacia' },
])

function go(route: string) {
  router.push(route)
}

// Progresso por responsável
function respPct(r: any): number {
  if (!r.total) return 0
  return Math.round((r.completed / r.total) * 100)
}
</script>

<template>
  <div v-if="loading" class="row g-3">
    <div v-for="i in 4" :key="'sk'+i" class="col-sm-6 col-xl-3">
      <div class="sq-card"><div class="sq-skeleton" style="height:76px"></div></div>
    </div>
  </div>

  <template v-else>
    <div v-if="error" class="alert alert-danger">{{ error }}</div>

    <!-- Cards KPI (1ª linha) -->
    <div class="row g-3 mb-3">
      <div v-for="k in kpis" :key="k.label" class="col-sm-6 col-xl-3">
        <div class="sq-card d-flex align-items-center gap-3" style="cursor:pointer" @click="go(k.route)">
          <div class="sq-kpi-icon" :style="{ background: k.color + '1f', color: k.color }">
            <component :is="k.icon" :size="22" />
          </div>
          <div>
            <div class="sq-kpi-value">{{ k.value }}</div>
            <div class="sq-kpi-label">{{ k.label }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- 2ª linha: Evolução + Donut estado -->
    <div class="row g-3 mb-3">
      <div class="col-xl-8">
        <div class="sq-card">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <h6 class="sq-card-title mb-0">Evolução da Qualidade</h6>
            <select v-model="trend" class="form-select form-select-sm w-auto" @change="reload">
              <option :value="12">Últimos 12 meses</option>
              <option :value="24">Últimos 24 meses</option>
            </select>
          </div>
          <VueApexCharts
            type="area" height="300"
            :options="{
              chart: { toolbar: { show: false }, foreColor: chartText },
              stroke: { curve: 'smooth', width: 2 },
              colors: ['#ea5455', '#7367f0', '#28c76f'],
              fill: { type: 'gradient', gradient: { opacityFrom: 0.25, opacityTo: 0.02 } },
              grid: { borderColor: chartGrid },
              xaxis: { categories: evolutionLabels, labels: { style: { colors: chartText } } },
              yaxis: { labels: { style: { colors: chartText } } },
              legend: { labels: { colors: chartText } },
            }"
            :series="evolutionSeries"
          />
        </div>
      </div>
      <div class="col-xl-4">
        <div class="sq-card">
          <h6 class="sq-card-title">Distribuição por estado</h6>
          <VueApexCharts
            type="donut" height="300"
            :options="{
              labels: donut.labels,
              stroke: { width: 0 },
              colors: ['#82828f', '#ff9f43', '#00cfe8', '#28c76f'],
              dataLabels: { enabled: false },
              legend: { position: 'bottom', labels: { colors: chartText } },
              plotOptions: { pie: { donut: { size: '72%' } } },
            }"
            :series="donut.series"
            @dataPointSelection="(_e: any, _c: any, opts: any) => go('/ocorrencias?tab=open&status=' + (byStatus[opts.dataPointIndex]?.status ?? ''))"
          />
        </div>
      </div>
    </div>

    <!-- 3ª linha: por origem + por área -->
    <div class="row g-3 mb-3">
      <div class="col-xl-6">
        <div class="sq-card">
          <h6 class="sq-card-title">Ocorrências por origem</h6>
          <VueApexCharts
            type="bar" height="260"
            :options="{
              chart: { toolbar: { show: false }, foreColor: chartText },
              colors: ['#7367f0'],
              plotOptions: { bar: { borderRadius: 4, columnWidth: '45%' } },
              grid: { borderColor: chartGrid },
              xaxis: { categories: (byOrigin as any[]).map((o) => o.origin_name) },
              yaxis: { labels: { style: { colors: chartText } } },
            }"
            :series="[{ name: 'Ocorrências', data: (byOrigin as any[]).map((o) => o.cnt) }]"
          />
        </div>
      </div>
      <div class="col-xl-6">
        <div class="sq-card">
          <div class="d-flex justify-content-between align-items-center mb-1">
            <h6 class="sq-card-title mb-0">Ocorrências por área</h6>
            <button class="btn btn-sm btn-icon" style="border:none;background:transparent;color:var(--sq-heading)" @click="areaFullscreen = true" title="Ecrã completo (todas as áreas)">
              <IconMaximize :size="18" />
            </button>
          </div>
          <div class="sq-muted mb-1" style="font-size:.72rem">Top {{ topByArea.length }} de {{ byArea.length }} áreas · clique no ícone para ver todas</div>
          <VueApexCharts
            type="bar" height="260"
            :options="{
              chart: { toolbar: { show: false }, foreColor: chartText },
              colors: ['#00cfe8'],
              plotOptions: { bar: { borderRadius: 4, horizontal: true, barHeight: '40%' } },
              grid: { borderColor: chartGrid },
              xaxis: { labels: { style: { colors: chartText } } },
              yaxis: { labels: { style: { colors: chartText } } },
              dataLabels: { enabled: true, style: { colors: [chartText] } },
              ...({ xaxis: { categories: topByArea.map((a) => a.area_name) } } as any),
            }"
            :series="[{ name: 'Ocorrências', data: topByArea.map((a) => a.cnt) }]"
          />
        </div>
      </div>
    </div>

    <!-- Copiloto — sinais operacionais -->
    <div class="row g-3 mb-3">
      <div class="col-12">
        <div class="sq-card" style="border-left:4px solid #7367f0">
          <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-2">
            <h6 class="sq-card-title mb-0">🤖 Copiloto de Qualidade — sinais de atenção</h6>
            <router-link to="/assistente-ia" class="btn btn-sm btn-outline-primary">Ver assistente <IconChevronRight :size="14" /></router-link>
          </div>
          <div v-if="!health" class="sq-muted" style="font-size:.85rem">A carregar sinais operacionais…</div>
          <div v-else class="row g-2">
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(234,84,85,.1)"><div class="fw-bold text-danger">{{ health.prazos?.fora_de_prazo?.total ?? 0 }}</div><div class="sq-muted" style="font-size:.7rem">Ações vencidas</div></div></div>
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(255,159,67,.12)"><div class="fw-bold" style="color:#b25c00">{{ health.prazos?.a_vencer_3_dias?.total ?? 0 }}</div><div class="sq-muted" style="font-size:.7rem">A vencer em 3 dias</div></div></div>
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(115,103,240,.1)"><div class="fw-bold" style="color:#7367f0">{{ (health.dados_incompletos?.ocorrencias_sem_responsavel?.total ?? 0) + (health.dados_incompletos?.ocorrencias_sem_causa?.total ?? 0) }}</div><div class="sq-muted" style="font-size:.7rem">NCs incompletas</div></div></div>
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(0,207,232,.1)"><div class="fw-bold" style="color:#009faf">{{ health.eficacia_pendente?.total ?? 0 }}</div><div class="sq-muted" style="font-size:.7rem">Eficácia por validar</div></div></div>
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(130,130,143,.12)"><div class="fw-bold">{{ health.riscos?.paradas_30dias?.total ?? 0 }}</div><div class="sq-muted" style="font-size:.7rem">Paradas +30d</div></div></div>
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(115,103,240,.08)"><div class="fw-bold" style="color:#7367f0">{{ health.reincidencias?.descricoes_repetidas?.length ?? 0 }}</div><div class="sq-muted" style="font-size:.7rem">Reincidências</div></div></div>
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(234,84,85,.08)"><div class="fw-bold text-danger">{{ health.riscos?.sem_acao_em_curso?.total ?? 0 }}</div><div class="sq-muted" style="font-size:.7rem">NCs sem ação</div></div></div>
            <div class="col-6 col-md-3"><div class="p-2 rounded" style="background:rgba(40,199,111,.1)"><div class="fw-bold text-success">{{ health.tendencias?.variacao ?? 0 }}</div><div class="sq-muted" style="font-size:.7rem">Variação mês ({{ health.tendencias?.tendencia || '—' }})</div></div></div>
          </div>
        </div>
      </div>
    </div>

    <!-- 4ª linha: responsáveis + ações urgentes -->
    <div class="row g-3">
      <div class="col-xl-7">
        <div class="sq-card">
          <h6 class="sq-card-title">Ações por responsável</h6>
          <div v-for="r in byResponsible.slice(0, 6)" :key="r.full_name" class="d-flex align-items-center gap-3 mb-3">
            <span class="sq-avatar">{{ initials((r.full_name as string) ?? null) }}</span>
            <div class="flex-grow-1">
              <div class="d-flex justify-content-between mb-1">
                <span style="font-size:.85rem">{{ r.full_name }}</span>
                <span class="sq-muted" style="font-size:.78rem">
                  {{ r.open_cnt }} abertas · {{ r.overdue }} atrasadas · {{ r.completed }} concluídas
                </span>
              </div>
              <div class="sq-progress"><span :style="{ width: respPct(r) + '%' }"></span></div>
            </div>
            <span class="fw-bold" style="font-size:.85rem;color:var(--sq-heading)">{{ respPct(r) }}%</span>
          </div>
          <div v-if="!byResponsible.length" class="sq-empty">Sem dados de responsáveis</div>
        </div>
      </div>

      <div class="col-xl-5">
        <div class="sq-card">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <h6 class="sq-card-title mb-0">Ações a necessitar de atenção</h6>
            <router-link to="/acoes" class="sq-muted d-flex align-items-center" style="font-size:.8rem;text-decoration:none">
              Ver todas <IconChevronRight :size="14" />
            </router-link>
          </div>
          <div style="max-height:320px;overflow:auto">
            <div v-for="a in urgent" :key="a.action_id" class="d-flex align-items-start gap-2 py-2 border-bottom" style="cursor:pointer"
                 @click="a.occurrence_id && router.push('/ocorrencias/' + a.occurrence_id)">
              <span class="sq-badge mt-1"
                    :class="deadlineTone(a.deadline) === 'overdue' ? 'badge-soft-danger' : deadlineTone(a.deadline) === 'today' ? 'badge-soft-warning' : 'badge-soft-primary'">
                {{ deadlineLabel(a.deadline) }}
              </span>
              <div class="flex-grow-1" style="min-width:0">
                <div style="font-size:.84rem;color:var(--sq-heading);font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ a.action_description }}</div>
                <div class="sq-muted" style="font-size:.75rem">{{ a.occurrence_ref }} · {{ a.responsible || '—' }}</div>
              </div>
            </div>
            <div v-if="!urgent.length" class="sq-empty">Sem ações urgentes 🎉</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal fullscreen: Ocorrências por área (todas) -->
    <div v-if="areaFullscreen" class="area-fs-overlay">
      <div class="area-fs-card">
        <div class="d-flex justify-content-between align-items-center px-3 py-2 border-bottom">
          <h6 class="mb-0" style="font-size:.95rem">Ocorrências por área — todas ({{ byArea.length }})</h6>
          <button class="btn btn-sm btn-icon" style="border:none;background:transparent;color:var(--sq-heading)" @click="areaFullscreen = false" title="Fechar">
            <IconX :size="20" />
          </button>
        </div>
        <div class="area-fs-body">
          <VueApexCharts
            type="bar" height="100%"
            :options="{
              chart: { toolbar: { show: true }, foreColor: chartText },
              colors: ['#00cfe8'],
              plotOptions: { bar: { borderRadius: 4, horizontal: true, barHeight: '70%' } },
              grid: { borderColor: chartGrid },
              xaxis: { title: { text: 'Nº de ocorrências', style: { color: chartText } } },
              yaxis: { labels: { style: { colors: chartText } } },
              dataLabels: { enabled: true, style: { colors: [chartText] } },
              ...({ xaxis: { categories: byArea.map((a) => a.area_name) } } as any),
            }"
            :series="[{ name: 'Ocorrências', data: byArea.map((a) => a.cnt) }]"
          />
        </div>
      </div>
    </div>
  </template>
</template>

<style scoped>
.area-fs-overlay{position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:1055;display:flex;align-items:center;justify-content:center;padding:2rem}
.area-fs-card{background:var(--sq-surface,#fff);border-radius:.75rem;width:min(92vw,1100px);height:min(88vh,720px);display:flex;flex-direction:column;box-shadow:0 10px 40px rgba(0,0,0,.3);overflow:hidden}
.area-fs-body{padding:1rem 1.25rem 1.25rem;flex:1;min-height:0}
.area-fs-body .vue-apexcharts,.area-fs-body .apexcharts-canvas{width:100%;height:100%}
</style>