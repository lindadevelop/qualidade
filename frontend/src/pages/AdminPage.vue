<script setup lang="ts">
import {qualityCommand,qualityWorkspace} from '@/services/quality'
import QualityCommandForm from '@/components/QualityCommandForm.vue'
import {useOrganization} from '@/composables/useOrganization'
import {watch} from 'vue'
import {useRoute} from 'vue-router'
import {API_BASE} from '@/lib/api-base'

import {useAuthStore} from '@/stores/auth'
import DataMaintenance from '@/components/DataMaintenance.vue'
import UserAdministration from '@/components/UserAdministration.vue'
import ConfigurationGuide from '@/components/ConfigurationGuide.vue'
import PageHeader from '@/components/PageHeader.vue'
import { onMounted, ref } from 'vue'
import { supabase } from '@/lib/supabase'
import { useSettingsStore } from '@/stores/settings'
import { IconPlus, IconPencil, IconCheck, IconRobot, IconLink, IconUnlink } from '@tabler/icons-vue'

const route=useRoute()
const settings = useSettingsStore()
const auth = useAuthStore()
const tab = ref<'areas'|'origins'|'users'|'config'|'ia'|'strategy'|'maintenance'>('users')
watch(()=>route.query.tab,v=>{if(v==='users')tab.value='users'},{immediate:true})
const areas = ref<any[]>([])
const origins = ref<any[]>([])
const profiles = ref<any[]>([])
const config = ref(settings.avisoDias)
const savedMsg = ref('')

const areaDialog=ref<any>(null),areaError=ref('')
const {orgId}=useOrganization();watch(orgId,load)
const newArea = ref('')
const newOrigin = ref('')

// --- IA e Canais ---
const channels = ref<any>(null)
const identities = ref<any[]>([])
const mcpTools = ref<string[]>([])
const linkCode = ref('')
const linkChannel = ref('telegram')
const linking = ref(false)

async function load() {
  ;[areas.value, origins.value, profiles.value] = await Promise.all([
    qualityWorkspace().then(r=>r.areas).catch(e=>{areaError.value=e.message;return []}),
    supabase.from('quality_origins').select('*').order('sort_order').then(r => r.data ?? []),
    supabase.from('profiles').select('*').order('full_name').then(r => r.data ?? []),
  ])
  const tk = (await supabase.auth.getSession()).data.session?.access_token
  if (tk) {
    const base = API_BASE || 'http://localhost:8000'
    channels.value = await fetch(`${base}/channels/status`, { headers: { Authorization: `Bearer ${tk}` } }).then(r => r.json()).catch(() => null)
    identities.value = await supabase.from('external_ai_identities').select('*').order('created_at', { ascending: false }).then(r => r.data ?? [])
    mcpTools.value = channels.value?.mcp?.tools ?? []
  }
}
onMounted(load)
void IconPencil

function flash(msg: string) { savedMsg.value = msg; setTimeout(() => savedMsg.value = '', 2500) }

async function addArea() {
 if(!newArea.value.trim())return
 try{await qualityCommand('area_save',null,{name:newArea.value.trim()});newArea.value='';await load();flash('Área adicionada.')}catch(e){areaError.value=(e as Error).message}
}
async function deleteArea(a:any){if(!confirm('Eliminar esta área se nunca foi utilizada?'))return;try{await qualityCommand('config_delete',a.id,{kind:'area',confirm_delete:true});await load()}catch(e){areaError.value=(e as Error).message}}
async function toggleArea(a:any){try{await qualityCommand('area_save',a.id,{name:a.name,active:!a.active});await load();flash('Alteração guardada.')}catch(e){areaError.value=(e as Error).message}}
async function areaSaved(){areaDialog.value=null;await load();flash('Designação guardada. Relações preservadas.')}
async function addOrigin(){if(!newOrigin.value.trim())return;try{await qualityCommand('origin_save',null,{name:newOrigin.value.trim()});newOrigin.value='';await load();flash('Origem adicionada.')}catch(e){areaError.value=(e as Error).message}}
async function deleteOrigin(o:any){if(!confirm('Eliminar esta origem se nunca foi utilizada?'))return;try{await qualityCommand('config_delete',o.id,{kind:'origin',confirm_delete:true});await load()}catch(e){areaError.value=(e as Error).message}}

async function toggleActive(table: string, id: string, active: boolean) {
  if(table==='quality_origins'){try{await qualityCommand('origin_save',id,{name:origins.value.find(o=>o.id===id)?.name,active:!active})}catch(e){areaError.value=(e as Error).message;return}}else await supabase.from(table).update({ active: !active }).eq('id', id)
  await load(); flash('Alterações guardadas com sucesso.')
}
function saveConfig() {
  settings.setAvisoDias(config.value)
  flash('Configurações guardadas com sucesso.')
}
function toggleLifecycle(e: Event) {
  settings.setLifecycleVisivel((e.target as HTMLInputElement).checked)
  flash(settings.lifecycleVisivel ? 'Módulo LifeCycle RH visível.' : 'Módulo LifeCycle RH ocultado.')
}
function toggleStrategy(e: Event) {
  settings.setStrategyVisivel((e.target as HTMLInputElement).checked)
  flash(settings.strategyVisivel ? 'Plataforma Estratégica v1.5 visível.' : 'Plataforma Estratégica v1.5 ocultada.')
}

// --- IA/Canais: associação ---
async function startLink() {
  linking.value = true
  const tk = (await supabase.auth.getSession()).data.session?.access_token
  try {
    const base = API_BASE || 'http://localhost:8000'
    const r = await fetch(`${base}/channels/link/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tk}` },
      body: JSON.stringify({ channel: linkChannel.value }),
    })
    const d = await r.json()
    linkCode.value = d.code || ''
    if (!linkCode.value) flash('Não foi possível gerar o código.')
  } catch { flash('Falha ao gerar código.') }
  linking.value = false
}
async function revokeIdentity(id: string) {
  await supabase.from('external_ai_identities').update({ is_active: false, revoked_at: new Date().toISOString() }).eq('id', id)
  await load(); flash('Associação revogada.')
}
</script>

<template>
  <div>
    <PageHeader><template #title>Administração geral</template><template #breadcrumb>Administração › Configuração</template></PageHeader>
    <ConfigurationGuide/>

    <div v-if="savedMsg" class="alert alert-success py-2 d-flex align-items-center gap-2"><IconCheck :size="16" /> {{ savedMsg }}</div>

    <div class="sq-tabs">
      <button class="sq-tab" :class="{active:tab==='areas'}" @click="tab='areas'">Áreas/Processos</button>
      <button class="sq-tab" :class="{active:tab==='origins'}" @click="tab='origins'">Origens</button>
      <button class="sq-tab" :class="{active:tab==='users'}" @click="tab='users'">Utilizadores</button>
      <button v-if="auth.canAdminister" class="sq-tab" :class="{active:tab==='maintenance'}" @click="tab='maintenance'">Limpeza de dados</button>
      <button v-if="auth.isGlobalAdmin" class="sq-tab" :class="{active:tab==='config'}" @click="tab='config'">Configurações</button>
      <button v-if="auth.isGlobalAdmin" class="sq-tab" :class="{active:tab==='ia'}" @click="tab='ia'"><IconRobot :size="13" /> IA e Canais</button>
      <button v-if="auth.isGlobalAdmin" class="sq-tab" :class="{active:tab==='strategy'}" @click="tab='strategy'">Estratégia v1.5</button>
    </div>

    <!-- Áreas -->
    <div v-if="tab==='areas'" class="sq-card"><div v-if="areaError" class="alert alert-danger">{{areaError}}</div><QualityCommandForm v-if="areaDialog" title="Editar área ou processo" operation="area_save" :id="areaDialog.id" :initial="areaDialog" :fields="[{key:'name',label:'Designação',required:true}]" @close="areaDialog=null" @saved="areaSaved"/>
      <div class="d-flex gap-2 mb-3">
        <input v-model="newArea" class="form-control" placeholder="Nome da nova área…" @keyup.enter="addArea" />
        <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" @click="addArea"><IconPlus :size="15" /> Adicionar</button>
      </div>
      <table class="sq-table">
        <thead><tr><th>Nome</th><th>Ativo</th><th></th></tr></thead>
        <tbody>
          <tr v-for="a in areas" :key="a.id">
            <td>{{ a.name }}</td>
            <td><span class="sq-badge" :class="a.active?'badge-soft-success':'badge-soft-secondary'">{{ a.active?'Ativo':'Inativo' }}</span></td>
            <td><button class="btn btn-sm btn-outline-primary me-2" @click="areaDialog={...a}">Editar</button><button class="btn btn-sm btn-outline-secondary" @click="toggleArea(a)">{{a.active?'Desativar':'Ativar'}}</button><button class="btn btn-sm btn-outline-danger ms-2" @click="deleteArea(a)">Eliminar</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Origens -->
    <div v-if="tab==='origins'" class="sq-card"><div v-if="areaError" class="alert alert-danger" role="alert">{{areaError}}</div>
      <div class="d-flex gap-2 mb-3">
        <input v-model="newOrigin" class="form-control" placeholder="Nome da nova origem…" @keyup.enter="addOrigin" />
        <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" @click="addOrigin"><IconPlus :size="15" /> Adicionar</button>
      </div>
      <table class="sq-table">
        <thead><tr><th>Nome</th><th>Ativo</th><th></th></tr></thead>
        <tbody>
          <tr v-for="o in origins" :key="o.id">
            <td>{{ o.name }}</td>
            <td><span class="sq-badge" :class="o.active?'badge-soft-success':'badge-soft-secondary'">{{ o.active?'Ativo':'Inativo' }}</span></td>
            <td><button class="btn btn-sm btn-outline-secondary" @click="toggleActive('quality_origins', o.id, o.active)">{{o.active?'Desativar':'Ativar'}}</button><button class="btn btn-sm btn-outline-danger ms-2" @click="deleteOrigin(o)">Eliminar</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="tab==='maintenance' && auth.canAdminister" class="sq-card"><DataMaintenance/></div>
    <div v-if="tab==='users'" class="sq-card"><UserAdministration v-if="auth.canAdminister"/></div>

    <!-- Configurações -->
    <div v-if="tab==='config'" class="sq-card" style="max-width:460px">
      <label class="form-label">Dias de aviso antes do prazo</label>
      <div class="input-group mb-4">
        <input v-model.number="config" type="number" min="0" class="form-control" />
        <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" @click="saveConfig">Guardar</button>
      </div>

      <div class="d-flex justify-content-between align-items-center border-top pt-3">
        <div>
          <div class="fw-semibold" style="color:var(--sq-heading)">Módulo LifeCycle RH</div>
          <div class="sq-muted" style="font-size:.8rem">Mostrar o módulo de Recursos Humanos no menu (candidaturas, admissão, offboarding)</div>
        </div>
        <div class="form-check form-switch ms-3">
          <input class="form-check-input" type="checkbox" role="switch" id="toggleLifecycle"
                 :checked="settings.lifecycleVisivel" @change="toggleLifecycle" style="width:2.6em;height:1.3em" />
        </div>
      </div>
    </div>

    <!-- Estratégia v1.5 -->
    <div v-if="tab==='strategy'" class="sq-card" style="max-width:460px">
      <div class="d-flex justify-content-between align-items-center border-bottom pb-3 mb-3">
        <div>
          <div class="fw-semibold" style="color:var(--sq-heading)">Plataforma Estratégica v1.5</div>
          <div class="sq-muted" style="font-size:.8rem">Mostrar o módulo de gestão estratégica no menu (SWOT, TOWS, plano, KPIs, reuniões, apresentações)</div>
        </div>
        <div class="form-check form-switch ms-3">
          <input class="form-check-input" type="checkbox" role="switch" id="toggleStrategy"
                 :checked="settings.strategyVisivel" @change="toggleStrategy" style="width:2.6em;height:1.3em" />
        </div>
      </div>
      <div class="sq-muted" style="font-size:.8rem">Novas rotas: /estrategia, /reunioes, /apresentacoes e subpáginas de administração.</div>
    </div>

    <!-- IA e Canais -->
    <div v-if="tab==='ia'" class="row g-3">
      <div class="col-12">
        <div class="sq-card">
          <h6 class="sq-card-title d-flex align-items-center gap-2"><IconRobot :size="17" style="color:#7367f0" /> Estado dos canais IA</h6>
          <div v-if="channels" class="d-flex flex-wrap gap-2">
            <span class="sq-badge" :class="channels.telegram.enabled ? 'badge-soft-success' : 'badge-soft-secondary'">Telegram {{ channels.telegram.enabled ? 'ativado' : 'desativado' }}</span>
            <span class="sq-badge" :class="channels.whatsapp.enabled ? 'badge-soft-success' : 'badge-soft-secondary'">WhatsApp {{ channels.whatsapp.enabled ? 'ativado' : 'desativado' }}</span>
            <span class="sq-badge" :class="channels.teams && channels.teams.enabled ? 'badge-soft-success' : 'badge-soft-secondary'">Teams {{ channels.teams && channels.teams.enabled ? 'ativado' : 'desativado' }}</span>
            <span class="sq-badge" :class="channels.slack && channels.slack.enabled ? 'badge-soft-success' : 'badge-soft-secondary'">Slack {{ channels.slack && channels.slack.enabled ? 'ativado' : 'desativado' }}</span>
            <span class="sq-badge badge-soft-info">MCP ativo · {{ mcpTools.length }} ferramentas de leitura</span>
          </div>
          <p v-else class="sq-muted">Canais indisponíveis (servidor de canais em http://localhost:3005 não está a responder).</p>
        </div>
      </div>

      <div class="col-xl-6">
        <div class="sq-card">
          <h6 class="sq-card-title d-flex align-items-center gap-2"><IconLink :size="16" /> Associar um canal</h6>
          <p class="sq-muted sq-breadcrumb mb-2">Gera um código, depois envia <code>/link &lt;código&gt;</code> ao bot no Telegram (ou WhatsApp). O código expira em poucos minutos.</p>
          <div class="d-flex gap-2 flex-wrap align-items-center">
            <select v-model="linkChannel" class="form-select" style="max-width:150px">
              <option value="telegram">Telegram</option>
              <option value="whatsapp">WhatsApp</option>
              <option value="teams">Microsoft Teams</option>
              <option value="slack">Slack</option>
            </select>
            <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" :disabled="linking" @click="startLink">
              {{ linking ? 'A gerar…' : 'Gerar código' }}
            </button>
          </div>
          <div v-if="linkCode" class="mt-3 p-3 text-center" style="background:var(--sq-primary-soft);border-radius:.6rem">
            <div class="sq-muted" style="font-size:.8rem">Envia no Telegram:</div>
            <code style="font-size:1.5rem;font-weight:800;color:var(--sq-primary);letter-spacing:.15em">/link {{ linkCode }}</code>
            <div class="sq-muted mt-1" style="font-size:.75rem">O código expira em alguns minutos.</div>
          </div>
        </div>
      </div>

      <div class="col-xl-6">
        <div class="sq-card">
          <h6 class="sq-card-title d-flex align-items-center gap-2"><IconUnlink :size="16" /> Canais associados</h6>
          <div v-if="!identities.length" class="sq-muted" style="font-size:.85rem">Nenhuma conta ligada. Associa um canal para poderes usar o assistente por Telegram/WhatsApp.</div>
          <table v-else class="sq-table">
            <thead><tr><th>Canal</th><th>ID externo</th><th>Ligado a</th><th>Estado</th><th></th></tr></thead>
            <tbody>
              <tr v-for="i in identities" :key="i.id">
                <td><span class="sq-badge badge-soft-primary">{{ i.channel }}</span></td>
                <td class="sq-muted" style="font-size:.8rem">{{ i.external_user_id }}</td>
                <td>{{ profiles.find(p=>p.id===i.user_id)?.full_name || i.user_id }}</td>
                <td><span class="sq-badge" :class="i.is_active ? 'badge-soft-success' : 'badge-soft-secondary'">{{ i.is_active ? 'Ativo' : 'Revogado' }}</span></td>
                <td><button v-if="i.is_active" class="btn btn-sm btn-outline-danger" @click="revokeIdentity(i.id)">Revogar</button></td>
              </tr>
            </tbody>
          </table>
          <p class="sq-muted mt-2" style="font-size:.75rem">Nunca é guardado o password nem segredos do bot — apenas o identificador do canal.</p>
        </div>
      </div>
    </div>
  </div>
</template>
