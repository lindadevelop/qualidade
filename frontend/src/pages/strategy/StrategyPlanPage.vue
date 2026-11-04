<script setup lang="ts">
import {datePT} from '@/domain/dates'
import PageHeader from '@/components/PageHeader.vue'
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  IconPlus, IconPencil, IconTrash, IconChevronRight, IconChevronLeft,
} from '@tabler/icons-vue'
import { useOrganization } from '@/composables/useOrganization'
import { useBrandKit } from '@/composables/useBrandKit'
import {
  listStrategicObjectives, createStrategicObjective, updateStrategicObjective, deleteStrategicObjective,
  listStrategicActions, createStrategicAction, updateStrategicAction, deleteStrategicAction, listRiskOpportunities, listKpis, listStrategyPeople,
} from '@/services/strategy'
import type { StrategicObjective, StrategicAction, StrategicActionStatus, StrategicObjectiveStatus } from '@/types/strategy'

import StrategyReview from '@/components/StrategyReview.vue'
import StrategyHistory from '@/components/StrategyHistory.vue'
import { required, numberInRange, validatePeriod, normalizeCrossing, kpiAssessment } from '@/domain/strategy-workflows'
const reviewed = ref(false)
const saving = ref(false)
const router = useRouter()
const { activeOrganization, loadOrganizations } = useOrganization()
useBrandKit()

const people = ref<{id:string;full_name:string}[]>([])
const riskOptions = ref<import('@/types/strategy').RiskOpportunity[]>([])
const riskSearch=ref('')
const visibleRisks=computed(()=>riskOptions.value.filter(r=>r.title.toLocaleLowerCase().includes(riskSearch.value.toLocaleLowerCase())))
const kpis=ref<import('@/types/strategy').Kpi[]>([])
const objectives = ref<StrategicObjective[]>([])
const actionsMap = ref<Record<string, StrategicAction[]>>({})
const loading = ref(false)
const error = ref('')
const expanded = ref<Record<string, boolean>>({})

async function load() {
  if (!activeOrganization.value) await loadOrganizations()
  if (!activeOrganization.value) return
  loading.value = true
  try {
    const org=activeOrganization.value.id
    ;[objectives.value,riskOptions.value,kpis.value,people.value] = await Promise.all([listStrategicObjectives(org),listRiskOpportunities(org),listKpis(org),listStrategyPeople()])
    const map: Record<string, StrategicAction[]> = {}
    for (const obj of objectives.value) {
      map[obj.id] = await listStrategicActions(obj.id)
      expanded.value[obj.id] = true
    }
    actionsMap.value = map
  } catch (e) { error.value = (e as Error).message } finally { loading.value = false }
}
onMounted(load)

const objModal = ref(false)
const editingObj = ref<Partial<StrategicObjective>>({ status: 'draft', progress: 0, weight: 1, risk_ids: [] })
function openNewObj() {
  error.value = ''; reviewed.value = false
  editingObj.value = { organization_id: activeOrganization.value?.id, status: 'draft', progress: 0, weight: 1, risk_ids: [] }
  objModal.value = true
}
function openEditObj(o: StrategicObjective) {
  error.value = ''; reviewed.value = false
  editingObj.value = { ...o }
  objModal.value = true
}
async function saveObj() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    required(editingObj.value.code,'Código'); required(editingObj.value.name,'Nome'); numberInRange(editingObj.value.progress,'Progresso',0,100)
    if (editingObj.value.id) await updateStrategicObjective(editingObj.value.id, editingObj.value, reviewed.value)
    else await createStrategicObjective(editingObj.value, reviewed.value)
    objModal.value = false
    await load()
  } catch (e) { error.value = (e as Error).message }
  finally { saving.value = false }
}
async function removeObj(id: string) {
  if (!confirm('Eliminar objetivo e ações associadas?')) return
  try { await deleteStrategicObjective(id, objectives.value?.find(row => row.id === id)?.updated_at, true); await load() } catch (e) { error.value = (e as Error).message }
}

const actModal = ref(false)
const editingAct = ref<Partial<StrategicAction>>({ status: 'todo', progress: 0 })
const activeObjectiveId = ref<string>('')
function openNewAct(objectiveId: string) {
  activeObjectiveId.value = objectiveId
  error.value = ''; reviewed.value = false
  editingAct.value = { objective_id: objectiveId, status: 'todo', progress: 0 }
  actModal.value = true
}
function openEditAct(a: StrategicAction) {
  activeObjectiveId.value = a.objective_id
  error.value = ''; reviewed.value = false
  editingAct.value = { ...a }
  actModal.value = true
}
async function saveAct() {
  if (saving.value) return
  saving.value = true
  error.value = ''
  try {
    if (!reviewed.value) throw new Error('Confirma a revisão humana.')
    required(editingAct.value.name,'Nome'); numberInRange(editingAct.value.progress,'Progresso',0,100)
    if (editingAct.value.id) await updateStrategicAction(editingAct.value.id, editingAct.value, reviewed.value)
    else await createStrategicAction(editingAct.value, reviewed.value)
    actModal.value = false
    await load()
  } catch (e) { error.value = (e as Error).message }
  finally { saving.value = false }
}
async function removeAct(id: string, objectiveId: string) {
  if (!confirm('Eliminar ação?')) return
  try { await deleteStrategicAction(id, actionsMap.value[objectiveId]?.find(row => row.id === id)?.updated_at, true); actionsMap.value[objectiveId] = actionsMap.value[objectiveId]?.filter(a => a.id !== id) ?? [] } catch (e) { error.value = (e as Error).message }
}

const statusOptions: StrategicObjectiveStatus[] = ['draft','approved','active','achieved','cancelled']
const actionStatusOptions: StrategicActionStatus[] = ['todo','in_progress','completed','cancelled']
const statusLabel: Record<string,string> = { draft:'Rascunho', approved:'Aprovado', active:'Ativo', achieved:'Alcançado', cancelled:'Cancelado', todo:'Por iniciar', in_progress:'Em curso', completed:'Concluída' }
const perspectiveOptions = ['financial','customer','internal','learning','custom']
const perspectiveLabel: Record<string,string> = { financial:'Financeira', customer:'Cliente', internal:'Processos Internos', learning:'Aprendizagem', custom:'Outra' }
watch(editingObj, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
watch(editingAct, () => { reviewed.value = false }, { deep: true, flush: 'sync' })
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
      <div>
        <PageHeader><template #title>Plano Estratégico</template><template #breadcrumb>Estratégia › Plano</template></PageHeader>
      </div>
      <div class="d-flex gap-2">
        <button class="btn btn-outline-secondary d-flex align-items-center gap-2" @click="router.push('/estrategia/riscos')">
          <IconChevronLeft :size="16"/> Riscos
        </button>
        <button class="btn btn-primary d-flex align-items-center gap-2" @click="router.push('/estrategia/kpis')">
          KPIs <IconChevronRight :size="16"/>
        </button>
      </div>
    </div>

    <div v-if="error" class="alert alert-danger py-2">{{ error }}</div>

    <div class="sq-card mb-3">
      <button class="btn btn-primary d-flex align-items-center gap-2" @click="openNewObj"><IconPlus :size="14"/> Novo Objetivo</button>
    </div>

    <div v-if="loading" class="sq-skeleton" style="height:120px"></div>
    <div v-else-if="!objectives.length" class="sq-card text-center py-5">
      <p class="sq-muted">Nenhum objetivo estratégico.</p>
    </div>

    <div v-else class="row g-3">
      <div v-for="obj in objectives" :key="obj.id" class="col-12">
        <div class="sq-card">
          <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
            <div>
              <div class="d-flex gap-2 align-items-center">
                <span class="sq-badge badge-soft-primary">{{ obj.code }}</span>
                <span class="sq-badge badge-soft-info">{{ statusLabel[obj.status] ?? obj.status }}</span>
                <span v-if="obj.perspective" class="sq-badge badge-soft-secondary">{{ perspectiveLabel[obj.perspective] ?? obj.perspective }}</span>
              </div>
              <h6 class="sq-card-title mt-2 mb-1">{{ obj.name }}</h6>
              <p class="sq-muted mb-0" style="font-size:.85rem">{{ obj.description }}</p>
            </div>
            <div class="d-flex gap-1">
              <button :disabled="loading || saving" class="btn btn-sm btn-outline-secondary" @click="openNewAct(obj.id)"><IconPlus :size="14"/> Ação</button>
              <button class="btn btn-sm btn-link p-1" @click="openEditObj(obj)"><IconPencil :size="16"/></button>
              <button class="btn btn-sm btn-link p-1 text-danger" @click="removeObj(obj.id)"><IconTrash :size="16"/></button>
            </div>
          </div>

          <div class="mt-3">
            <div class="d-flex justify-content-between mb-1" style="font-size:.8rem">
              <span>Progresso validado do objetivo</span><span>{{ obj.progress ?? 0 }}%</span>
            </div>
            <div class="sq-progress"><span :style="{width: (obj.progress ?? 0) + '%'}"></span></div>
          </div>

          <div class="d-flex flex-wrap gap-2 mt-2"><span v-if="!actionsMap[obj.id]?.length" class="sq-badge badge-soft-warning">Sem ações</span><span v-if="!kpis.some(k=>k.objective_id===obj.id)" class="sq-badge badge-soft-warning">Sem KPI</span><span v-if="!obj.risk_ids?.length" class="sq-badge badge-soft-warning">Sem risco/oportunidade</span><span v-if="!obj.responsible_id" class="sq-badge badge-soft-warning">Sem responsável</span><span v-if="obj.due_date && obj.due_date < new Date().toLocaleDateString('sv-SE') && !['achieved','cancelled'].includes(obj.status)" class="sq-badge badge-soft-danger">Atrasado</span></div>
          <div class="small mt-2" v-for="risk in riskOptions.filter(r=>obj.risk_ids?.includes(r.id))" :key="risk.id">Origem: {{ risk.title }}</div>
          <div v-if="actionsMap[obj.id]?.length" class="mt-3 table-responsive">
            <table class="sq-table">
              <thead><tr><th>Ação</th><th>Estado</th><th>Prioridade</th><th>Progresso</th><th>Prazo</th><th></th></tr></thead>
              <tbody>
                <tr v-for="a in actionsMap[obj.id]" :key="a.id">
                  <td class="sq-ref">{{ a.name }}</td>
                  <td><span class="sq-badge badge-soft-info">{{ statusLabel[a.status] ?? a.status }}</span></td>
                  <td>{{ a.priority ?? '—' }}</td>
                  <td>{{ a.progress ?? 0 }}%</td><td>{{ datePT(a.due_date) }}</td>
                  <td>
                    <div class="d-flex gap-1">
                      <button class="btn btn-sm btn-link p-1" @click="openEditAct(a)"><IconPencil :size="16"/></button>
                      <button class="btn btn-sm btn-link p-1 text-danger" @click="removeAct(a.id, obj.id)"><IconTrash :size="16"/></button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Objetivo -->
    <div v-if="objModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingObj.id ? 'Editar' : 'Novo' }} Objetivo Estratégico</h5>
            <button type="button" class="btn-close" @click="objModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="row g-3 mb-3">
              <div class="col-6"><label class="form-label">Código</label><input v-model="editingObj.code" class="form-control"/></div>
              <div class="col-6">
                <label class="form-label">Perspetiva BSC</label>
                <select v-model="editingObj.perspective" class="form-select">
                  <option v-for="p in perspectiveOptions" :key="p" :value="p">{{ perspectiveLabel[p] }}</option>
                </select>
              </div>
            </div>
            <div class="mb-3"><label class="form-label">Nome</label><input v-model="editingObj.name" class="form-control"/></div><div class="mb-3"><label class="form-label">Responsável</label><select v-model="editingObj.responsible_id" class="form-select"><option :value="null">Por atribuir</option><option v-for="p in people" :key="p.id" :value="p.id">{{ p.full_name }}</option></select></div><div class="mb-3"><label class="form-label">Riscos / oportunidades associados</label><input v-model="riskSearch" class="form-control mb-2" placeholder="Pesquisar riscos"/><select v-model="editingObj.risk_ids" multiple class="form-select"><option v-for="r in visibleRisks" :key="r.id" :value="r.id">{{ r.title }}</option></select><small>Usa Ctrl para selecionar vários.</small></div>
            <div class="mb-3"><label class="form-label">Descrição</label><textarea v-model="editingObj.description" class="form-control" rows="3"></textarea></div>
            <div class="row g-3 mb-3">
              <div class="col-6">
                <label class="form-label">Estado</label>
                <select v-model="editingObj.status" class="form-select">
                  <option v-for="s in statusOptions" :key="s" :value="s">{{ statusLabel[s] }}</option>
                </select>
              </div>
              <div class="col-6"><label class="form-label">Progresso (%)</label><input v-model.number="editingObj.progress" type="number" min="0" max="100" class="form-control"/></div>
            </div>
            <div class="row g-3">
              <div class="col-6"><label class="form-label">Data início</label><PtDateInput v-model="editingObj.start_date" type="date" class="form-control"/></div>
              <div class="col-6"><label class="form-label">Data fim</label><PtDateInput v-model="editingObj.due_date" type="date" class="form-control"/></div>
            </div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="strategic_objectives" :record-id="editingObj.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="objModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="saveObj">Guardar</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Ação -->
    <div v-if="actModal" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,.4)">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingAct.id ? 'Editar' : 'Nova' }} Ação</h5>
            <button type="button" class="btn-close" @click="actModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
            <div class="mb-3"><label class="form-label">Nome</label><input v-model="editingAct.name" class="form-control"/></div><div class="mb-3"><label class="form-label">Responsável</label><select v-model="editingAct.responsible_id" class="form-select"><option :value="null">Por atribuir</option><option v-for="p in people" :key="p.id" :value="p.id">{{ p.full_name }}</option></select></div><div class="row mb-3"><div class="col"><label class="form-label">Início</label><PtDateInput type="date" v-model="editingAct.start_date" class="form-control"/></div><div class="col"><label class="form-label">Prazo</label><PtDateInput type="date" v-model="editingAct.due_date" class="form-control"/></div></div><div class="row mb-3"><div class="col"><label class="form-label">Orçamento</label><input type="number" min="0" step="0.01" v-model.number="editingAct.budget" class="form-control"/></div><div class="col"><label class="form-label">Custo real</label><input type="number" min="0" step="0.01" v-model.number="editingAct.actual_cost" class="form-control"/></div></div>
            <div class="mb-3"><label class="form-label">Descrição</label><textarea v-model="editingAct.description" class="form-control" rows="2"></textarea></div>
            <div class="row g-3 mb-3">
              <div class="col-6">
                <label class="form-label">Estado</label>
                <select v-model="editingAct.status" class="form-select">
                  <option v-for="s in actionStatusOptions" :key="s" :value="s">{{ statusLabel[s] }}</option>
                </select>
              </div>
              <div class="col-6"><label class="form-label">Prioridade</label><input v-model="editingAct.priority" class="form-control" placeholder="high/medium/low"/></div>
            </div>
            <div class="mb-3"><label class="form-label">Progresso (%)</label><input v-model.number="editingAct.progress" type="number" min="0" max="100" class="form-control"/></div>
          </div>
          <div class="px-3"><StrategyReview v-model="reviewed" /><StrategyHistory table="strategic_actions" :record-id="editingAct.id" /></div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="actModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving || !reviewed" @click="saveAct">Guardar</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
