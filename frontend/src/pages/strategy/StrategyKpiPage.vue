<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  IconPlus, IconPencil, IconTrash, IconChevronRight, IconChevronLeft,
} from '@tabler/icons-vue'
import VueApexCharts from 'vue3-apexcharts'
import { useOrganization } from '@/composables/useOrganization'
import { useBrandKit } from '@/composables/useBrandKit'
import {
  listKpis, createKpi, updateKpi, deleteKpi, listStrategicObjectives, listStrategyPeople,
  listKpiTargets, upsertKpiTarget, deleteKpiTarget,
  listKpiResults, upsertKpiResult, deleteKpiResult,
} from '@/services/strategy'
import type { Kpi, KpiTarget, KpiResult, KpiDirection, KpiFrequency } from '@/types/strategy'

import StrategyReview from '@/components/StrategyReview.vue'
import StrategyHistory from '@/components/StrategyHistory.vue'
import { required, numberInRange, validatePeriod, normalizeCrossing, kpiAssessment } from '@/domain/strategy-workflows'
const reviewed = ref(false)
const saving = ref(false)
const router = useRouter()
const { activeOrganization, loadOrganizations } = useOrganization()
const {colors}=useBrandKit()

const objectives=ref<import('@/types/strategy').StrategicObjective[]>([])
const people=ref<{id:string;full_name:string}[]>([])
const kpis = ref<Kpi[]>([])
const selectedKpiId = ref<string>('')
const targets = ref<KpiTarget[]>([])
const results = ref<KpiResult[]>([])
const loading = ref(false)
const error = ref('')

async function loadKpis() {
  if (!activeOrganization.value) await loadOrganizations()
  if (!activeOrganization.value) return
  try {
    ;[kpis.value,objectives.value,people.value] = await Promise.all([listKpis(activeOrganization.value.id),listStrategicObjectives(activeOrganization.value.id),listStrategyPeople()])
    if (!kpis.value.some(k=>k.id===selectedKpiId.value)) selectedKpiId.value = kpis.value[0]?.id ?? ''
  } catch (e) { error.value = (e as Error).message }
}
async function loadDetails() {
  targets.value=[]; results.value=[]
  if (!selectedKpiId.value) return
  loading.value = true
  try {
    const selected = selectedKpiId.value
    const [t, r] = await Promise.all([
      listKpiTargets(selectedKpiId.value),
      listKpiResults(selectedKpiId.value),
    ])
    if(selected!==selectedKpiId.value) return
    targets.value = t
    results.value = r
  } catch (e) { error.value = (e as Error).message } finally { loading.value = false }
}
onMounted(() => { void loadKpis() })
watch(selectedKpiId, () => { showTargetModal.value=false; showResultModal.value=false; void loadDetails() })

const selectedKpi = computed(() => kpis.value.find(k => k.id === selectedKpiId.value))

const showKpiModal = ref(false)
const editingKpi = ref<Partial<Kpi>>({ direction: 'higher_is_better', frequency: 'monthly', active: true })
function openNewKpi() {
  error.value = ''; reviewed.value = false
  editingKpi.value = { organization_id: activeOrganization.value?.id, direction: 'higher_is_better', frequency: 'monthly', active: true }
  showKpiModal.value = true
}
function openEditKpi(k: Kpi) {
  error.value = ''; reviewed.value = false
  editingKpi.value = { ...k }
  showKpiModal.value = true
}
async function saveKpi() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    required(editingKpi.value.name,'Nome'); required(editingKpi.value.code,'Código')
    if (editingKpi.value.id) await updateKpi(editingKpi.value.id, editingKpi.value, reviewed.value)
    else await createKpi(editingKpi.value, reviewed.value)
    showKpiModal.value = false
    await loadKpis()
  } catch (e) { error.value = (e as Error).message }
  finally { saving.value = false }
}
async function removeKpi(id: string) {
  if (!confirm('Eliminar KPI?')) return
  try { await deleteKpi(id, kpis.value?.find(row => row.id === id)?.updated_at, true); await loadKpis() } catch (e) { error.value = (e as Error).message }
}

const showTargetModal = ref(false)
const editingTarget = ref<Partial<KpiTarget>>({})
function openNewTarget() {
  error.value = ''; reviewed.value = false
  editingTarget.value = { kpi_id: selectedKpiId.value }
  showTargetModal.value = true
}
function openEditTarget(t: KpiTarget) {
  error.value = ''; reviewed.value = false
  editingTarget.value = { ...t }
  showTargetModal.value = true
}
async function saveTarget() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    validatePeriod(editingTarget.value.period, selectedKpi.value?.frequency)
    numberInRange(editingTarget.value.target_value,'Valor')
    await upsertKpiTarget(editingTarget.value, reviewed.value)
    showTargetModal.value = false
    await loadDetails()
  } catch (e) { error.value = (e as Error).message }
  finally { saving.value = false }
}
async function removeTarget(id: string) {
  if (!confirm('Eliminar este registo? A alteração fica no histórico.')) return
  try { await deleteKpiTarget(id, targets.value?.find(row => row.id === id)?.updated_at, true); await loadDetails() } catch (e) { error.value = (e as Error).message }
}

const showResultModal = ref(false)
const editingResult = ref<Partial<KpiResult>>({})
function openNewResult() {
  error.value = ''; reviewed.value = false
  editingResult.value = { kpi_id: selectedKpiId.value }
  showResultModal.value = true
}
function openEditResult(r: KpiResult) {
  error.value = ''; reviewed.value = false
  editingResult.value = { ...r }
  showResultModal.value = true
}
async function saveResult() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    validatePeriod(editingResult.value.period, selectedKpi.value?.frequency)
    numberInRange(editingResult.value.value,'Valor')
    await upsertKpiResult(editingResult.value, reviewed.value)
    showResultModal.value = false
    await loadDetails()
  } catch (e) { error.value = (e as Error).message }
  finally { saving.value = false }
}
async function removeResult(id: string) {
  if (!confirm('Eliminar este registo? A alteração fica no histórico.')) return
  try { await deleteKpiResult(id, results.value?.find(row => row.id === id)?.updated_at, true); await loadDetails() } catch (e) { error.value = (e as Error).message }
}

const invalidPeriods=computed(()=>[...new Set([...targets.value.map(t=>t.period),...results.value.map(r=>r.period)])].filter(period=>{try{validatePeriod(period,selectedKpi.value?.frequency);return false}catch{return true}}))
const frequencyLabel: Record<string,string> = {daily:'Diária',weekly:'Semanal',monthly:'Mensal',quarterly:'Trimestral',yearly:'Anual'}
const comparison = computed(() => [...new Set([...targets.value.map(t=>t.period),...results.value.map(r=>r.period)])].sort().map(period=>{
  const target=targets.value.find(t=>t.period===period), result=results.value.find(r=>r.period===period)
  return {period, target:target?.target_value, value:result?.value, state:kpiAssessment(result?.value,target?.target_value,target?.warning_value,selectedKpi.value?.direction)}
}))
const chartSeries=computed(()=>[{name:'Meta',data:comparison.value.map(r=>({x:r.period,y:r.target ?? null}))},{name:'Resultado',data:comparison.value.map(r=>({x:r.period,y:r.value ?? null}))}])
const chartOptions = computed(() => ({
  chart: { type: 'line' as const, toolbar: { show: false }, fontFamily: 'inherit' },
  stroke: { curve: 'straight' as const, width: 3 },
  colors: [colors.value.secondary, colors.value.primary],
  xaxis: { type: 'category' as const, title: { text: 'Período' } },
  yaxis: { title: { text: selectedKpi.value?.unit || 'Valor' } },
  markers: { size: 5 },
  grid: { borderColor: 'var(--sq-border)' },
  theme: { mode: (document.documentElement.getAttribute('data-bs-theme') === 'dark' ? 'dark' : 'light') as 'dark' | 'light' },
}))

const directionOptions: KpiDirection[] = ['higher_is_better','lower_is_better','target']
const frequencyOptions: KpiFrequency[] = ['daily','weekly','monthly','quarterly','yearly']
const directionLabel: Record<string,string> = { higher_is_better:'Quanto maior melhor', lower_is_better:'Quanto menor melhor', target:'Alvo' }
watch(editingKpi, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
watch(editingTarget, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
watch(editingResult, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
      <div>
        <PageHeader><template #title>KPIs e Indicadores</template><template #breadcrumb>Estratégia › KPIs</template></PageHeader>
      </div>
      <div class="d-flex gap-2">
        <button class="btn btn-outline-secondary d-flex align-items-center gap-2" @click="router.push('/estrategia/plano')">
          <IconChevronLeft :size="16"/> Plano
        </button>
        <button class="btn btn-primary d-flex align-items-center gap-2" @click="router.push('/apresentacoes')">
          Apresentações <IconChevronRight :size="16"/>
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-danger py-2">{{ error }}</div>

    <div class="sq-card mb-3">
      <div class="d-flex flex-wrap gap-2 justify-content-between align-items-center">
        <div class="d-flex gap-2 align-items-center">
          <label class="form-label mb-0">KPI</label>
          <select v-model="selectedKpiId" class="form-select" style="min-width:260px">
            <option v-for="k in kpis" :key="k.id" :value="k.id">{{ k.code }} — {{ k.name }}</option>
          </select>
        </div>
        <button class="btn btn-primary d-flex align-items-center gap-2" @click="openNewKpi"><IconPlus :size="14"/> Novo KPI</button>
      </div>
    </div>

    <div v-if="!selectedKpi" class="sq-card text-center py-5">
      <p class="sq-muted">Nenhum KPI selecionado.</p>
    </div>

    <div v-else>
      <div class="row g-3 mb-3">
        <div class="col-12 col-lg-8">
          <div class="sq-card">
            <div class="d-flex justify-content-between align-items-start">
              <div>
                <h6 class="sq-card-title">{{ selectedKpi.code }} — {{ selectedKpi.name }} {{ selectedKpi.active === false ? '(Inativo)' : '' }}</h6>
                <p class="sq-muted" style="font-size:.85rem">{{ selectedKpi.description }}</p>
                <div class="d-flex gap-2">
                  <span class="sq-badge badge-soft-secondary">{{ selectedKpi.unit || 'Sem unidade' }}</span>
                  <span class="sq-badge badge-soft-info">{{ directionLabel[selectedKpi.direction || 'higher_is_better'] }}</span>
                  <span class="sq-badge badge-soft-warning">{{ frequencyLabel[selectedKpi.frequency || 'monthly'] }}</span>
                </div>
              </div>
              <div class="d-flex gap-1">
                <button class="btn btn-sm btn-link p-1" @click="openEditKpi(selectedKpi)"><IconPencil :size="16"/></button>
                <button class="btn btn-sm btn-link p-1 text-danger" @click="removeKpi(selectedKpi.id)"><IconTrash :size="16"/></button>
              </div>
            </div>

            <div v-if="invalidPeriods.length" class="alert alert-warning mt-3">Períodos antigos incompatíveis com a frequência: {{ invalidPeriods.join(', ') }}. Edita as metas/resultados para indicar o período correto.</div><div class="table-responsive mt-3"><table class="sq-table"><thead><tr><th>Período</th><th>Meta</th><th>Resultado</th><th>Avaliação</th></tr></thead><tbody><tr v-for="r in comparison" :key="r.period"><td>{{ r.period }}</td><td>{{ r.target ?? '—' }}</td><td>{{ r.value ?? '—' }}</td><td>{{ r.state }}</td></tr></tbody></table></div>
            <div class="mt-4" v-if="comparison.length">
              <VueApexCharts type="line" height="300" :options="chartOptions" :series="chartSeries" />
            </div>
            <div v-else class="sq-empty">Sem resultados para mostrar.</div>
          </div>
        </div>

        <div class="col-12 col-lg-4">
          <div class="sq-card mb-3">
            <div class="d-flex justify-content-between align-items-center mb-3">
              <h6 class="sq-card-title mb-0">Metas</h6>
              <button class="btn btn-sm btn-outline-secondary" @click="openNewTarget"><IconPlus :size="14"/> Meta</button>
            </div>
            <table class="sq-table">
              <thead><tr><th>Período</th><th>Meta</th><th>Alerta</th><th></th></tr></thead>
              <tbody>
                <tr v-if="loading"><td colspan="4"><div class="sq-skeleton" style="height:20px"></div></td></tr>
                <tr v-else-if="!targets.length"><td colspan="4" class="text-center sq-muted">Nenhuma meta.</td></tr>
                <tr v-for="t in targets" :key="t.id">
                  <td>{{ t.period }}</td>
                  <td>{{ t.target_value }}</td>
                  <td>{{ t.warning_value ?? '—' }}</td>
                  <td>
                    <div class="d-flex gap-1">
                      <button class="btn btn-sm btn-link p-1" @click="openEditTarget(t)"><IconPencil :size="16"/></button>
                      <button class="btn btn-sm btn-link p-1 text-danger" @click="removeTarget(t.id)"><IconTrash :size="16"/></button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="sq-card">
            <div class="d-flex justify-content-between align-items-center mb-3">
              <h6 class="sq-card-title mb-0">Resultados</h6>
              <button class="btn btn-sm btn-outline-secondary" @click="openNewResult"><IconPlus :size="14"/> Resultado</button>
            </div>
            <table class="sq-table">
              <thead><tr><th>Período</th><th>Valor</th><th></th></tr></thead>
              <tbody>
                <tr v-if="loading"><td colspan="3"><div class="sq-skeleton" style="height:20px"></div></td></tr>
                <tr v-for="r in results" :key="r.id">
                  <td>{{ r.period }}</td>
                  <td class="sq-ref">{{ r.value }}</td>
                  <td>
                    <div class="d-flex gap-1">
                      <button class="btn btn-sm btn-link p-1" @click="openEditResult(r)"><IconPencil :size="16"/></button>
                      <button class="btn btn-sm btn-link p-1 text-danger" @click="removeResult(r.id)"><IconTrash :size="16"/></button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- KPI Modal -->
    <div v-if="showKpiModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingKpi.id ? 'Editar' : 'Novo' }} KPI</h5>
            <button type="button" class="btn-close" @click="showKpiModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="row g-3 mb-3">
              <div class="col-6"><label class="form-label">Código</label><input v-model="editingKpi.code" class="form-control"/></div>
              <div class="col-6"><label class="form-label">Unidade</label><input v-model="editingKpi.unit" class="form-control"/></div>
            </div>
            <div class="mb-3"><label class="form-label">Nome</label><input v-model="editingKpi.name" class="form-control"/></div>
            <div class="mb-3"><label class="form-label">Descrição</label><textarea v-model="editingKpi.description" class="form-control" rows="2"></textarea></div>
            <div class="row g-3 mb-3">
              <div class="col-6">
                <label class="form-label">Direção</label>
                <select v-model="editingKpi.direction" class="form-select">
                  <option v-for="d in directionOptions" :key="d" :value="d">{{ directionLabel[d] }}</option>
                </select>
              </div>
              <div class="col-6">
                <label class="form-label">Frequência</label>
                <select v-model="editingKpi.frequency" class="form-select">
                  <option v-for="f in frequencyOptions" :key="f" :value="f">{{ frequencyLabel[f] }}</option>
                </select>
              </div>
            </div>
            <div class="mb-3"><label class="form-label">Objetivo</label><select v-model="editingKpi.objective_id" class="form-select mb-3"><option :value="null">Sem objetivo</option><option v-for="o in objectives" :key="o.id" :value="o.id">{{ o.code }} — {{ o.name }}</option></select>
            <label class="form-label">Responsável</label><select v-model="editingKpi.responsible_id" class="form-select mb-3"><option :value="null">Por atribuir</option><option v-for="p in people" :key="p.id" :value="p.id">{{ p.full_name }}</option></select>
            <label class="form-check mb-3"><input type="checkbox" class="form-check-input" v-model="editingKpi.active"/> KPI ativo</label><label class="form-label">Fórmula</label><input v-model="editingKpi.formula" class="form-control"/></div>
            <div class="mb-3"><label class="form-label">Fonte de dados</label><input v-model="editingKpi.data_source" class="form-control"/></div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="kpis" :record-id="editingKpi.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showKpiModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="saveKpi">Guardar</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Target Modal -->
    <div v-if="showTargetModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered modal-sm">
        <div class="modal-content">
          <div class="modal-header"><h5 class="modal-title">Meta</h5><button type="button" class="btn-close" @click="showTargetModal=false"></button></div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="mb-3"><label class="form-label">Período</label><input v-model="editingTarget.period" class="form-control" :placeholder="({daily:'2026-09-30',weekly:'2026-W40',monthly:'2026-09',quarterly:'2026-Q3',yearly:'2026'})[selectedKpi?.frequency || 'monthly']"/></div>
            <div class="mb-3"><label class="form-label">Meta</label><input v-model.number="editingTarget.target_value" type="number" step="0.0001" class="form-control"/></div>
            <div class="mb-3"><label class="form-label">{{ selectedKpi?.direction === 'target' ? 'Tolerância absoluta' : 'Limite de alerta' }}</label><input v-model.number="editingTarget.warning_value" type="number" step="0.0001" class="form-control"/></div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="kpi_targets" :record-id="editingTarget.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showTargetModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="saveTarget">Guardar</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Result Modal -->
    <div v-if="showResultModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered modal-sm">
        <div class="modal-content">
          <div class="modal-header"><h5 class="modal-title">Resultado</h5><button type="button" class="btn-close" @click="showResultModal=false"></button></div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="mb-3"><label class="form-label">Período</label><input v-model="editingResult.period" class="form-control" :placeholder="({daily:'2026-09-30',weekly:'2026-W40',monthly:'2026-09',quarterly:'2026-Q3',yearly:'2026'})[selectedKpi?.frequency || 'monthly']"/></div>
            <div class="mb-3"><label class="form-label">Valor</label><input v-model.number="editingResult.value" type="number" step="0.0001" class="form-control"/></div>
            <div class="mb-3"><label class="form-label">Notas</label><textarea v-model="editingResult.notes" class="form-control" rows="2"></textarea></div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="kpi_results" :record-id="editingResult.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showResultModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="saveResult">Guardar</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
