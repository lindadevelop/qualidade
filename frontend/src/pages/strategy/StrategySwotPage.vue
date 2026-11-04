<script setup lang="ts">
import {supabase} from '@/lib/supabase'
import PageHeader from '@/components/PageHeader.vue'
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  IconPlus, IconPencil, IconTrash, IconChevronRight, IconInfoCircle,
} from '@tabler/icons-vue'
import { useOrganization } from '@/composables/useOrganization'
import { useBrandKit } from '@/composables/useBrandKit'
import {
  listSwotCampaigns, listSwotItems, createSwotItem, updateSwotItem, deleteSwotItem,
} from '@/services/strategy'
import type { SwotCampaign, SwotItem, SwotQuadrant } from '@/types/strategy'
import { QUADRANT_LABEL } from '@/types/strategy'

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
const items = ref<SwotItem[]>([])
const loading = ref(false)
const error = ref('')
const thematicAreas=ref<any[]>([]),areaFilter=ref(''),contextFilter=ref('')
const scopeLabels:Record<string,string>={own_team:'Equipa representada',organization:'Organização / Corporativa',other_team:'Outra equipa'}

const selectedCampaign = computed(() => campaigns.value.find(c => c.id === selectedCampaignId.value))

const quadrants: SwotQuadrant[] = ['strengths', 'weaknesses', 'opportunities', 'threats']
function itemsByQuadrant(q: SwotQuadrant) {
  return items.value.filter(i => i.quadrant === q&&(!areaFilter.value||(i as any).thematic_area_id===areaFilter.value)&&(!contextFilter.value||(i as any).contribution_scope===contextFilter.value))
}

async function loadCampaigns() {
  if (!activeOrganization.value) await loadOrganizations()
  if (!activeOrganization.value) return
  try {
    campaigns.value = await listSwotCampaigns(activeOrganization.value.id)
    const a=await supabase.from('strategy_thematic_areas').select('id,name').eq('organization_id',activeOrganization.value.id).order('name');if(a.error)throw a.error;thematicAreas.value=a.data||[]
    if (campaigns.value.length && !selectedCampaignId.value) {
      selectedCampaignId.value = campaigns.value[0].id
    }
  } catch (e) {
    error.value = (e as Error).message
  }
}

async function loadItems() {
  if (!selectedCampaignId.value) return
  loading.value = true
  try {
    const campaign = selectedCampaignId.value
    const data = await listSwotItems(campaign)
    if (campaign === selectedCampaignId.value) items.value = data
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    loading.value = false
  }
}

onMounted(() => { void loadCampaigns() })
watch(activeOrganization,()=>{selectedCampaignId.value='';items.value=[];campaigns.value=[];void loadCampaigns()})
watch(selectedCampaignId, () => { showModal.value = false; items.value = []; void loadItems() })

// Modal de edição/criação
const showModal = ref(false)
const editing = ref<Partial<SwotItem> & { quadrant: SwotQuadrant }>({ quadrant: 'strengths' })

function openNew(q: SwotQuadrant) {
 void router.push({path:'/estrategia/campanhas',query:{campaign:selectedCampaignId.value,quadrant:q}})
}
function openEdit(item: SwotItem) {
  error.value = ''; reviewed.value = false
  editing.value = { ...item }
  showModal.value = true
}
async function saveItem() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    required(editing.value.title, 'Título')
    if (editing.value.id) {
      await updateSwotItem(editing.value.id, editing.value, reviewed.value)
    } else {
      await createSwotItem(editing.value, reviewed.value)
    }
    showModal.value = false
    await loadItems()
  } catch (e) {
    error.value = (e as Error).message
  }
  finally { saving.value = false }
}
async function remove(id: string) {
  if (!confirm('Eliminar este item SWOT?')) return
  try {
    await deleteSwotItem(id, items.value?.find(row => row.id === id)?.updated_at, true)
    await loadItems()
  } catch (e) {
    error.value = (e as Error).message
  }
}

const impactOptions = ['low', 'medium', 'high']
const impactLabel: Record<string, string> = { low: 'Baixo', medium: 'Médio', high: 'Alto' }
const impactBadge: Record<string, string> = { low: 'badge-soft-secondary', medium: 'badge-soft-warning', high: 'badge-soft-danger' }

function badgeForImpact(i?: string | null) {
  return impactBadge[i ?? 'medium'] ?? 'badge-soft-secondary'
}
function badgeForProbability(i?: string | null) {
  return impactBadge[i ?? 'medium'] ?? 'badge-soft-secondary'
}
watch(editing, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
      <div>
        <PageHeader><template #title>SWOT</template><template #breadcrumb>Estratégia › SWOT</template></PageHeader>
      </div>
      <button class="btn btn-primary d-flex align-items-center gap-2" @click="router.push('/estrategia/tows')">
        TOWS <IconChevronRight :size="16"/>
      </button>
    </div>

    <div v-if="error" class="alert alert-danger py-2">{{ error }}</div>

    <div class="sq-card mb-3">
      <div class="d-flex flex-wrap align-items-center gap-3">
        <div>
          <label class="form-label mb-1">Campanha</label>
          <select v-model="selectedCampaignId" class="form-select" style="min-width:260px">
            <option v-for="c in campaigns" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <label>Contexto<select v-model="contextFilter" class="form-select"><option value="">Todos os contextos</option><option v-for="(label,key) in scopeLabels" :key="key" :value="key">{{label}}</option></select></label><label>Área temática<select v-model="areaFilter" class="form-select"><option value="">Todas as áreas</option><option v-for="a in thematicAreas" :key="a.id" :value="a.id">{{a.name}} · {{items.filter((i:any)=>i.thematic_area_id===a.id).length}} itens</option></select></label><div v-if="selectedCampaign?.description" class="sq-muted" style="font-size:.85rem">
          {{ selectedCampaign.description }}
        </div>
      </div>
    </div>

    <div v-if="!selectedCampaign" class="sq-card text-center py-5">
      <IconInfoCircle :size="32" class="sq-muted mb-2" />
      <p class="sq-muted">Nenhuma campanha SWOT encontrada para {{ activeOrganization?.name || 'a organização' }}.</p>
    </div>

    <div v-else class="row g-3">
      <div v-for="q in quadrants" :key="q" class="col-12 col-lg-6">
        <div class="sq-card h-100" style="border-top:4px solid var(--sq-primary)">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <h6 class="sq-card-title mb-0">{{ QUADRANT_LABEL[q] }}</h6>
            <button :disabled="loading || saving" class="btn btn-sm btn-outline-primary" @click="openNew(q)"><IconPlus :size="14"/> Novo</button>
          </div>
          <div v-if="loading" class="sq-skeleton" style="height:80px"></div>
          <div v-else-if="!itemsByQuadrant(q).length" class="sq-empty" style="padding:1rem">Nenhum item.</div>
          <ul v-else class="list-group list-group-flush">
            <li v-for="item in itemsByQuadrant(q)" :key="item.id" class="list-group-item px-0 d-flex justify-content-between align-items-start"
                style="background:transparent;border-color:var(--sq-border)">
              <div class="flex-grow-1">
                <div class="fw-semibold" style="color:var(--sq-heading)">{{ item.title }}</div>
                <div v-if="item.description" class="sq-muted" style="font-size:.8rem">{{ item.description }}</div><small v-if="(item as any).contribution_scope" class="d-block">{{scopeLabels[(item as any).contribution_scope]}}</small><small v-if="(item as any).thematic_area_id">{{thematicAreas.find(a=>a.id===(item as any).thematic_area_id)?.name}}</small>
                <div class="d-flex gap-2 mt-2">
                  <span class="sq-badge" :class="badgeForImpact(item.impact)">Impacto: {{ impactLabel[item.impact || 'medium'] }}</span>
                  <span class="sq-badge" :class="badgeForProbability(item.probability)">Prob.: {{ impactLabel[item.probability || 'medium'] }}</span>
                </div>
              </div>
              <div class="d-flex gap-1 ms-2">
                <button class="btn btn-sm btn-link p-1" @click="openEdit(item)"><IconPencil :size="16"/></button>
                <button class="btn btn-sm btn-link p-1 text-danger" @click="remove(item.id)"><IconTrash :size="16"/></button>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editing.id ? 'Editar item SWOT' : 'Novo item SWOT' }}</h5>
            <button type="button" class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="mb-3">
              <label class="form-label">Quadrante</label>
              <select v-model="editing.quadrant" class="form-select">
                <option v-for="q in quadrants" :key="q" :value="q">{{ QUADRANT_LABEL[q] }}</option>
              </select>
            </div>
            <div class="mb-3">
              <label class="form-label">Título</label>
              <input v-model="editing.title" class="form-control" />
            </div>
            <div class="mb-3">
              <label class="form-label">Descrição</label>
              <textarea v-model="editing.description" class="form-control" rows="3"></textarea>
            </div>
            <div class="row g-3">
              <div class="col-6">
                <label class="form-label">Impacto</label>
                <select v-model="editing.impact" class="form-select">
                  <option v-for="o in impactOptions" :key="o" :value="o">{{ impactLabel[o] }}</option>
                </select>
              </div>
              <div class="col-6">
                <label class="form-label">Probabilidade</label>
                <select v-model="editing.probability" class="form-select">
                  <option v-for="o in impactOptions" :key="o" :value="o">{{ impactLabel[o] }}</option>
                </select>
              </div>
            </div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="swot_items" :record-id="editing.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="saveItem">Guardar</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
