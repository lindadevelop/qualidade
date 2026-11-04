<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  IconPlus, IconPencil, IconTrash, IconChevronRight, IconChevronLeft, IconInfoCircle,
} from '@tabler/icons-vue'
import { useOrganization } from '@/composables/useOrganization'
import { useBrandKit } from '@/composables/useBrandKit'
import {
  listSwotCampaigns, listSwotItems, listTowsCrossings,
  createTowsCrossing, updateTowsCrossing, deleteTowsCrossing, createRiskOpportunity,
} from '@/services/strategy'
import type { SwotCampaign, SwotItem, TowsCrossing, TowsStrategyType, SwotQuadrant } from '@/types/strategy'
import { TOWS_LABEL, QUADRANT_LABEL } from '@/types/strategy'

import StrategyReview from '@/components/StrategyReview.vue'
import StrategyHistory from '@/components/StrategyHistory.vue'
import { required, numberInRange, validatePeriod, normalizeCrossing, kpiAssessment } from '@/domain/strategy-workflows'
const reviewed = ref(false)
const saving = ref(false)
const router = useRouter()
const { activeOrganization, loadOrganizations } = useOrganization()
useBrandKit()

const campaigns = ref<SwotCampaign[]>([])
const selectedCampaignId = ref<string>('')
const swotItems = ref<SwotItem[]>([])
const crossings = ref<TowsCrossing[]>([])
const loading = ref(false)
const error = ref('')

const strategyTypes: TowsStrategyType[] = ['so', 'wo', 'st', 'wt']
const selectedType = ref<TowsStrategyType>('so')

const typeDescription: Record<TowsStrategyType, string> = {
  so: 'Usar Forças para aproveitar Oportunidades.',
  wo: 'Usar Oportunidades para superar Fraquezas.',
  st: 'Usar Forças para reduzir Ameaças.',
  wt: 'Minimizar Fraquezas e evitar Ameaças.',
}

async function loadCampaigns() {
  if (!activeOrganization.value) await loadOrganizations()
  if (!activeOrganization.value) return
  campaigns.value = await listSwotCampaigns(activeOrganization.value.id)
  if (campaigns.value.length && !selectedCampaignId.value) selectedCampaignId.value = campaigns.value[0].id
}

async function loadData() {
  if (!selectedCampaignId.value) return
  loading.value = true
  try {
    const campaign = selectedCampaignId.value
    const [i, c] = await Promise.all([
      listSwotItems(selectedCampaignId.value),
      listTowsCrossings(selectedCampaignId.value),
    ])
    if (campaign !== selectedCampaignId.value) return
    swotItems.value = i
    crossings.value = c
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    loading.value = false
  }
}

onMounted(() => { void loadCampaigns().catch(e => error.value = e.message) })
watch(selectedCampaignId, () => { showModal.value=false; swotItems.value=[]; crossings.value=[]; void loadData() })

const strengths = computed(() => swotItems.value.filter(i => i.quadrant === 'strengths'))
const weaknesses = computed(() => swotItems.value.filter(i => i.quadrant === 'weaknesses'))
const opportunities = computed(() => swotItems.value.filter(i => i.quadrant === 'opportunities'))
const threats = computed(() => swotItems.value.filter(i => i.quadrant === 'threats'))

function sourceOptions(type: TowsStrategyType): { label: string, items: SwotItem[] }[] {
  switch (type) {
    case 'so': return [{ label: 'Força', items: strengths.value }, { label: 'Oportunidade', items: opportunities.value }]
    case 'wo': return [{ label: 'Fraqueza', items: weaknesses.value }, { label: 'Oportunidade', items: opportunities.value }]
    case 'st': return [{ label: 'Força', items: strengths.value }, { label: 'Ameaça', items: threats.value }]
    case 'wt': return [{ label: 'Fraqueza', items: weaknesses.value }, { label: 'Ameaça', items: threats.value }]
  }
}

function crossingsByType(type: TowsStrategyType) {
  return crossings.value.filter(c => c.strategy_type === type)
}

const showModal = ref(false)
const editing = ref<Partial<TowsCrossing> & { strategy_type: TowsStrategyType }>({ strategy_type: 'so', priority: 'medium', disposition: 'monitor' })

function openNew(type: TowsStrategyType) {
  selectedType.value = type
  error.value = ''; reviewed.value = false
  editing.value = { campaign_id: selectedCampaignId.value, strategy_type: type, priority: 'medium', disposition: 'monitor' }
  showModal.value = true
}
function openEdit(c: TowsCrossing) {
  selectedType.value = c.strategy_type
  error.value = ''; reviewed.value = false
  editing.value = { ...c }
  showModal.value = true
}
async function saveCrossing() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    const payload = normalizeCrossing(editing.value, swotItems.value)
    if (editing.value.id) await updateTowsCrossing(editing.value.id, payload, reviewed.value)
    else await createTowsCrossing(payload, reviewed.value)
    showModal.value = false
    await loadData()
  } catch (e) { error.value = (e as Error).message }
  finally { saving.value = false }
}
async function remove(id: string) {
  if (!confirm('Eliminar cruzamento?')) return
  try { await deleteTowsCrossing(id, crossings.value?.find(row => row.id === id)?.updated_at, true); await loadData() } catch (e) { error.value = (e as Error).message }
}

const priorityOptions = ['low', 'medium', 'high']
const priorityLabel: Record<string, string> = { low: 'Baixa', medium: 'Média', high: 'Alta' }
const priorityBadge: Record<string, string> = { low: 'badge-soft-secondary', medium: 'badge-soft-warning', high: 'badge-soft-danger' }

function itemTitle(id?: string | null) {
  return swotItems.value.find(i => i.id === id)?.title ?? ''
}
watch(editing, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
      <div>
        <PageHeader><template #title>TOWS — Cruzamentos Estratégicos</template><template #breadcrumb>Estratégia › TOWS</template></PageHeader>
      </div>
      <div class="d-flex gap-2">
        <button class="btn btn-outline-secondary d-flex align-items-center gap-2" @click="router.push('/estrategia/swot')">
          <IconChevronLeft :size="16"/> SWOT
        </button>
        <button class="btn btn-primary d-flex align-items-center gap-2" @click="router.push('/estrategia/riscos')">
          Riscos <IconChevronRight :size="16"/>
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-danger py-2">{{ error }}</div>

    <div class="sq-card mb-3">
      <label class="form-label">Campanha SWOT</label>
      <select v-model="selectedCampaignId" class="form-select" style="max-width:400px">
        <option v-for="c in campaigns" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
    </div>

    <div v-if="!selectedCampaignId" class="sq-card text-center py-5">
      <IconInfoCircle :size="32" class="sq-muted mb-2" />
      <p class="sq-muted">Seleciona uma campanha SWOT.</p>
    </div>

    <div v-else>
      <div class="row g-3">
        <div v-for="type in strategyTypes" :key="type" class="col-12 col-lg-6">
          <div class="sq-card h-100" style="border-top:4px solid var(--sq-secondary)">
            <div class="d-flex justify-content-between align-items-center mb-2">
              <h6 class="sq-card-title mb-0">{{ TOWS_LABEL[type] }}</h6>
              <button :disabled="loading || saving" class="btn btn-sm btn-outline-secondary" @click="openNew(type)"><IconPlus :size="14"/> Novo</button>
            </div>
            <p class="sq-muted" style="font-size:.8rem">{{ typeDescription[type] }}</p>
            <div v-if="loading" class="sq-skeleton" style="height:60px"></div>
            <ul v-else class="list-group list-group-flush">
              <li v-for="c in crossingsByType(type)" :key="c.id" class="list-group-item px-0" style="background:transparent;border-color:var(--sq-border)">
                <div class="d-flex justify-content-between">
                  <div class="fw-semibold" style="color:var(--sq-heading)">{{ c.name }}</div>
                  <div class="d-flex gap-1">
                    <button class="btn btn-sm btn-link p-1" @click="openEdit(c)"><IconPencil :size="16"/></button>
                    <button class="btn btn-sm btn-link p-1 text-danger" @click="remove(c.id)"><IconTrash :size="16"/></button>
                  </div>
                </div>
                <div class="sq-muted" style="font-size:.8rem">{{ c.description }}</div>
                <div class="mt-2">{{ c.disposition === 'not_relevant' ? 'Não relevante' : c.disposition === 'risk' ? 'Proposta de risco' : c.disposition === 'opportunity' ? 'Proposta de oportunidade' : 'Monitorizar' }}</div>
                <button v-if="c.disposition === 'risk' || c.disposition === 'opportunity'" class="btn btn-sm btn-outline-primary mt-2" @click="router.push({path:'/estrategia/riscos',query:{tows:c.id,campaign:c.campaign_id,type:c.disposition}})">Rever proposta em Riscos</button>
                <div class="d-flex flex-wrap gap-2 mt-2">
                  <span v-if="itemTitle(c.s_item_id)" class="sq-badge badge-soft-primary">F: {{ itemTitle(c.s_item_id) }}</span>
                  <span v-if="itemTitle(c.w_item_id)" class="sq-badge badge-soft-warning">W: {{ itemTitle(c.w_item_id) }}</span>
                  <span v-if="itemTitle(c.o_item_id)" class="sq-badge badge-soft-success">O: {{ itemTitle(c.o_item_id) }}</span>
                  <span v-if="itemTitle(c.t_item_id)" class="sq-badge badge-soft-danger">T: {{ itemTitle(c.t_item_id) }}</span>
                  <span class="sq-badge" :class="priorityBadge[c.priority || 'medium']">Prioridade: {{ priorityLabel[c.priority || 'medium'] }}</span>
                </div>
              </li>
              <li v-if="!crossingsByType(type).length" class="list-group-item px-0 sq-empty" style="background:transparent;border:none">Nenhum cruzamento.</li>
            </ul>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editing.id ? 'Editar' : 'Novo' }} Cruzamento {{ TOWS_LABEL[editing.strategy_type] }}</h5>
            <button type="button" class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="mb-3">
              <label class="form-label">Estratégia</label>
              <select v-model="editing.strategy_type" class="form-select">
                <option v-for="t in strategyTypes" :key="t" :value="t">{{ TOWS_LABEL[t] }}</option>
              </select>
            </div>
            <div class="mb-3">
              <label class="form-label">Nome</label>
              <input v-model="editing.name" class="form-control" />
            </div>
            <div class="mb-3">
              <label class="form-label">Descrição</label>
              <textarea v-model="editing.description" class="form-control" rows="3"></textarea>
            </div>
            <div class="row g-3 mb-3">
              <div class="col-6">
                <label class="form-label">{{ editing.strategy_type === 'so' || editing.strategy_type === 'st' ? 'Força' : 'Fraqueza' }}</label>
                <select v-model="editing.s_item_id" v-if="editing.strategy_type === 'so' || editing.strategy_type === 'st'" class="form-select">
                  <option :value="undefined">Nenhum</option>
                  <option v-for="it in strengths" :key="it.id" :value="it.id">{{ it.title }}</option>
                </select>
                <select v-model="editing.w_item_id" v-else class="form-select">
                  <option :value="undefined">Nenhum</option>
                  <option v-for="it in weaknesses" :key="it.id" :value="it.id">{{ it.title }}</option>
                </select>
              </div>
              <div class="col-6">
                <label class="form-label">{{ editing.strategy_type === 'so' || editing.strategy_type === 'wo' ? 'Oportunidade' : 'Ameaça' }}</label>
                <select v-model="editing.o_item_id" v-if="editing.strategy_type === 'so' || editing.strategy_type === 'wo'" class="form-select">
                  <option :value="undefined">Nenhum</option>
                  <option v-for="it in opportunities" :key="it.id" :value="it.id">{{ it.title }}</option>
                </select>
                <select v-model="editing.t_item_id" v-else class="form-select">
                  <option :value="undefined">Nenhum</option>
                  <option v-for="it in threats" :key="it.id" :value="it.id">{{ it.title }}</option>
                </select>
              </div>
            </div>

            <div class="mb-3">
              <label class="form-label">Destino / decisão</label>
              <select v-model="editing.disposition" class="form-select mb-3"><option value="monitor">Monitorizar</option><option value="not_relevant">Não relevante</option><option value="risk">Propor risco</option><option value="opportunity">Propor oportunidade</option></select>
              <label class="form-label">Prioridade</label>
              <select v-model="editing.priority" class="form-select">
                <option v-for="p in priorityOptions" :key="p" :value="p">{{ priorityLabel[p] }}</option>
              </select>
            </div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="tows_crossings" :record-id="editing.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="saveCrossing">Guardar</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
