<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import {
  IconPlus, IconPencil, IconTrash, IconChevronRight, IconChevronLeft,
} from '@tabler/icons-vue'
import { useOrganization } from '@/composables/useOrganization'
import { useBrandKit } from '@/composables/useBrandKit'
import {
  listRiskOpportunities, createRiskOpportunity, updateRiskOpportunity, deleteRiskOpportunity, listTowsCrossings, listStrategyPeople,
} from '@/services/strategy'
import type { RiskOpportunity, RiskOpportunityType, RiskOpportunityStatus } from '@/types/strategy'

import StrategyReview from '@/components/StrategyReview.vue'
import StrategyHistory from '@/components/StrategyHistory.vue'
import { required, numberInRange, validatePeriod, normalizeCrossing, kpiAssessment } from '@/domain/strategy-workflows'
const reviewed = ref(false)
const saving = ref(false)
const router = useRouter()
const route = useRoute()
const people = ref<{id:string;full_name:string}[]>([])
const cell = ref<{p:number;i:number}|null>(null)
const { activeOrganization, loadOrganizations } = useOrganization()
useBrandKit()

const items = ref<RiskOpportunity[]>([])
const loading = ref(false)
const error = ref('')
const filterType = ref<RiskOpportunityType | 'all'>('all')

async function load() {
  if (!activeOrganization.value) await loadOrganizations()
  if (!activeOrganization.value) return
  loading.value = true
  try {
    items.value = await listRiskOpportunities(activeOrganization.value.id)
  } catch (e) { error.value = (e as Error).message } finally { loading.value = false }
}
onMounted(async () => {
  await load()
  try {
    people.value = await listStrategyPeople()
    if (typeof route.query.tows === 'string' && typeof route.query.campaign === 'string') {
      const crossing = (await listTowsCrossings(route.query.campaign)).find(c => c.id === route.query.tows)
      if (crossing) { openNew(); editing.value = {...editing.value, title: crossing.name, description: crossing.description, source_tows_id: crossing.id, type: route.query.type === 'opportunity' ? 'opportunity' : 'risk'} }
    }
  } catch(e) { error.value = (e as Error).message }
})

const filtered = computed(() => {
  return items.value.filter(i => (filterType.value === 'all' || i.type === filterType.value) && (!cell.value || (i.probability === cell.value.p && i.impact === cell.value.i)))
})

const showModal = ref(false)
const editing = ref<Partial<RiskOpportunity>>({ type: 'risk', status: 'identified', probability: 3, impact: 3 })

function openNew() {
  error.value = ''; reviewed.value = false
  editing.value = { organization_id: activeOrganization.value?.id, type: 'risk', status: 'identified', probability: 3, impact: 3 }
  showModal.value = true
}
function openEdit(item: RiskOpportunity) {
  error.value = ''; reviewed.value = false
  editing.value = { ...item }
  showModal.value = true
}
async function save() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    required(editing.value.title,'Título')
    for (const field of ['probability','impact'] as const) { const n=numberInRange(editing.value[field],field==='impact'?'Impacto':'Probabilidade',1,5); if(!Number.isInteger(n)) throw new Error('Usa valores inteiros de 1 a 5.') }
    if (editing.value.id) await updateRiskOpportunity(editing.value.id, editing.value, reviewed.value)
    else await createRiskOpportunity(editing.value, reviewed.value)
    showModal.value = false
    await load()
  } catch (e) { error.value = (e as Error).message }
  finally { saving.value = false }
}
async function remove(id: string) {
  if (!confirm('Eliminar?')) return
  try { await deleteRiskOpportunity(id, items.value?.find(row => row.id === id)?.updated_at, true); await load() } catch (e) { error.value = (e as Error).message }
}

function scoreColor(score?: number | null) {
  if (!score) return 'badge-soft-secondary'
  if (score >= 12) return 'badge-soft-danger'
  if (score >= 6) return 'badge-soft-warning'
  return 'badge-soft-success'
}

const typeLabel: Record<RiskOpportunityType, string> = { risk: 'Risco', opportunity: 'Oportunidade' }
const typeBadge: Record<RiskOpportunityType, string> = { risk: 'badge-soft-danger', opportunity: 'badge-soft-success' }
const statusOptions: RiskOpportunityStatus[] = ['identified','analyzing','mitigating','monitored','closed']
const statusLabel: Record<string,string> = { identified:'Identificado', analyzing:'Em análise', mitigating:'Em mitigação', monitored:'Monitorizado', closed:'Fechado' }
watch(editing, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
      <div>
        <PageHeader><template #title>Riscos e Oportunidades</template><template #breadcrumb>Estratégia › Riscos</template></PageHeader>
      </div>
      <div class="d-flex gap-2">
        <button class="btn btn-outline-secondary d-flex align-items-center gap-2" @click="router.push('/estrategia/tows')">
          <IconChevronLeft :size="16"/> TOWS
        </button>
        <button class="btn btn-primary d-flex align-items-center gap-2" @click="router.push('/estrategia/plano')">
          Plano <IconChevronRight :size="16"/>
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-danger py-2">{{ error }}</div>

    <div class="sq-card mb-3">
      <div class="d-flex flex-wrap gap-2 justify-content-between align-items-center">
        <div class="btn-group">
          <button class="btn btn-outline-secondary" :class="{active: filterType==='all'}" @click="filterType='all'">Todos</button>
          <button class="btn btn-outline-secondary" :class="{active: filterType==='risk'}" @click="filterType='risk'">Riscos</button>
          <button class="btn btn-outline-secondary" :class="{active: filterType==='opportunity'}" @click="filterType='opportunity'">Oportunidades</button>
        </div>
        <button class="btn btn-primary d-flex align-items-center gap-2" @click="openNew"><IconPlus :size="14"/> Novo</button>
      </div>
    </div>

    <div class="sq-card mb-3 table-responsive">
      <h2 class="h6">Matriz de impacto e probabilidade</h2>
      <p class="sq-muted">Seleciona uma célula para filtrar. Pontuação = probabilidade × impacto. Baixa: 1–5; média: 6–11; alta: 12–25.</p>
      <table class="sq-table"><caption>Probabilidade nas linhas e impacto nas colunas</caption><thead><tr><th>Prob. / Impacto</th><th v-for="i in 5" :key="i">{{ i }}</th></tr></thead><tbody>
      <tr v-for="p in [5,4,3,2,1]" :key="p"><th>{{ p }}</th><td v-for="i in 5" :key="i"><button class="btn w-100" :class="scoreColor(p*i)" :aria-label="`Probabilidade ${p}, impacto ${i}`" @click="cell={p,i}">{{ p*i }} · {{ items.filter(r => r.probability===p && r.impact===i && (filterType==='all' || r.type===filterType)).length }} registos</button></td></tr>
      </tbody></table><button v-if="cell" class="btn btn-link" @click="cell=null">Limpar filtro da matriz</button>
    </div>
    <div class="sq-card table-responsive">
      <table class="sq-table">
        <thead>
          <tr>
            <th>Tipo</th><th>Título</th><th>Prob.</th><th>Impacto</th><th>Score</th><th>Estado</th><th>Prazo</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading"><td colspan="8"><div class="sq-skeleton" style="height:24px"></div></td></tr>
          <tr v-else-if="!filtered.length"><td colspan="8" class="text-center sq-muted">Nenhum registo.</td></tr>
          <tr v-for="r in filtered" :key="r.id">
            <td><span class="sq-badge" :class="typeBadge[r.type]">{{ typeLabel[r.type] }}</span></td>
            <td class="sq-ref">{{ r.title }}<div v-if="r.source_tows_id" class="small sq-muted">Origem TOWS: {{ r.source_tows_id }}</div></td>
            <td>{{ r.probability }}</td>
            <td>{{ r.impact }}</td>
            <td><span class="sq-badge" :class="scoreColor(r.score)">{{ r.score ?? '-' }}</span></td>
            <td><span class="sq-badge badge-soft-info">{{ statusLabel[r.status] ?? r.status }}</span></td>
            <td>{{ r.due_date ? new Date(r.due_date).toLocaleDateString('pt-PT') : '—' }}</td>
            <td>
              <div class="d-flex gap-1">
                <button class="btn btn-sm btn-link p-1" @click="openEdit(r)"><IconPencil :size="16"/></button>
                <button class="btn btn-sm btn-link p-1 text-danger" @click="remove(r.id)"><IconTrash :size="16"/></button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editing.id ? 'Editar' : 'Novo' }} Risco/Oportunidade</h5>
            <button type="button" class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="row g-3 mb-3">
              <div class="col-6">
                <label class="form-label">Tipo</label>
                <select v-model="editing.type" class="form-select">
                  <option value="risk">Risco</option>
                  <option value="opportunity">Oportunidade</option>
                </select>
              </div>
              <div class="col-6">
                <label class="form-label">Estado</label>
                <select v-model="editing.status" class="form-select">
                  <option v-for="s in statusOptions" :key="s" :value="s">{{ statusLabel[s] }}</option>
                </select>
              </div>
            </div>
            <div class="mb-3">
              <label class="form-label">Referência</label>
              <input v-model="editing.reference" class="form-control" placeholder="R-2026-001"/>
            </div>
            <div class="mb-3">
              <label class="form-label">Título</label>
              <input v-model="editing.title" class="form-control" />
            </div>
            <div class="mb-3">
              <label class="form-label">Descrição</label>
              <textarea v-model="editing.description" class="form-control" rows="3"></textarea>
            </div>
            <div class="row g-3 mb-3">
              <div class="col-6">
                <label class="form-label">Probabilidade (1-5)</label>
                <input v-model.number="editing.probability" type="number" min="1" max="5" class="form-control" />
              </div>
              <div class="col-6">
                <label class="form-label">Impacto (1-5)</label>
                <input v-model.number="editing.impact" type="number" min="1" max="5" class="form-control" />
              </div>
            </div>
            <div class="mb-3">
              <label class="form-label">Mitigação / Ação</label>
              <textarea v-model="editing.mitigation" class="form-control" rows="2"></textarea>
            </div>
            <div class="mb-3">
              <label class="form-label">Responsável</label><select v-model="editing.responsible_id" class="form-select mb-3"><option :value="null">Por atribuir</option><option v-for="p in people" :key="p.id" :value="p.id">{{ p.full_name }}</option></select>
              <label class="form-label">Prazo</label>
              <PtDateInput v-model="editing.due_date" type="date" class="form-control" />
            </div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="risk_opportunities" :record-id="editing.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="save">Guardar</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
