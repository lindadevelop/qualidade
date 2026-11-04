<script setup lang="ts">
import {datePT} from '@/domain/dates'
import {useAuthStore} from '@/stores/auth'
import {computed,onMounted,ref,watch} from 'vue'
import {platformModules,localDateTime,modulePayload,type Option} from '@/domain/platform-modules'
import {listModule,moduleOptions,saveModule,type PlatformRow} from '@/services/platform'
import {useOrganization} from '@/composables/useOrganization'
import {useBrandKit} from '@/composables/useBrandKit'
import {fontStack} from '@/domain/google-fonts'
import {strategyAdminCommand} from '@/services/strategy-admin'
import FontPicker from './FontPicker.vue'
import BrandAssetEditor from './BrandAssetEditor.vue'
import StrategyReview from './StrategyReview.vue'
import StrategyHistory from './StrategyHistory.vue'
const auth=useAuthStore()
const props=defineProps<{table:string}>()
const def=computed(()=>platformModules[props.table]!)
const {activeOrganization,loadOrganizations}=useOrganization()
const {loadBrandKit}=useBrandKit()
const rows=ref<PlatformRow[]>([]),loading=ref(false),saving=ref(false),error=ref(''),success=ref(''),search=ref('')
const choices=ref<Record<string,Option[]>>({}),show=ref(false),editing=ref<PlatformRow>(),form=ref<Record<string,any>>({}),reviewed=ref(false)
const showInactive=ref(false),dependencies=ref<any>(null)
function fieldOptions(field:any){const options=field.options||choices.value[field.relation||'']||[];return field.relation==='profiles'?options.filter((o:any)=>o.active!==false||showInactive.value||form.value[field.key]===o.value):options}
async function inspectDependencies(row:PlatformRow){try{dependencies.value={row,...await strategyAdminCommand('structure_dependencies',row.id,{table:props.table})}}catch(e){error.value=(e as Error).message}}
async function removeStructure(){if(!confirm('Eliminar este registo nunca utilizado?'))return;try{await strategyAdminCommand('structure_delete',dependencies.value.row.id,{table:props.table,confirm_delete:true});dependencies.value=null;await load();success.value='Registo eliminado.'}catch(e){error.value=(e as Error).message}}
const dependencyLabels:Record<string,string>={swot_campaigns:'Campanhas SWOT',swot_contributions:'Contributos SWOT',user_assignments:'Atribuições de utilizadores',strategy_area_teams:'Áreas temáticas',swot_campaign_audience:'Participantes de campanhas',swot_campaign_validators:'Validadores de campanhas',strategic_objectives:'Objetivos',strategic_actions:'Ações',kpis:'Indicadores',generated_files:'Apresentações geradas',meetings:'Reuniões',decisions:'Decisões',risk_opportunities:'Riscos e oportunidades'}
const filtered=computed(()=>rows.value.filter(row=>def.value.columns.some(key=>display(row,key).toLocaleLowerCase().includes(search.value.toLocaleLowerCase()))))
function display(row:PlatformRow,key:string):string {
 const value=row[key];if(value==null)return '—'
 const f=def.value.fields.find(f=>f.key===key)
 if(f?.type==='checkbox')return value?'Sim':'Não'
 if(f?.relation)return choices.value[f.relation]?.find(o=>o.value===value)?.label||value
 if(f?.options)return f.options.find(o=>o.value===value)?.label||String(value)
 if(f?.type==='date')return datePT(value)
 if(key.endsWith('_at'))return new Date(value).toLocaleString('pt-PT')
 return String(value)
}
async function load(){
 loading.value=true;error.value=''
 try{await loadOrganizations();const org=activeOrganization.value?.id??'';if(!org&&!def.value.global){rows.value=[];return}
  const result=await Promise.all([listModule(def.value,org),moduleOptions(org)])
  rows.value=result[0];choices.value=result[1]
 }catch(e){error.value=(e as Error).message}finally{loading.value=false}
}
onMounted(load)
watch(()=>activeOrganization.value?.id,()=>{show.value=false;dependencies.value=null;void load()})
function open(row?:PlatformRow){
 showInactive.value=false;editing.value=row;const values:Record<string,any>={}
 for(const f of def.value.fields){values[f.key]=row?.[f.key]??structuredClone(f.initial??(f.type==='checkbox'?false:f.type==='multi'?[]:''));if(f.type==='datetime-local'&&values[f.key])values[f.key]=localDateTime(values[f.key])}
 form.value=values;reviewed.value=false;error.value='';success.value='';show.value=true
}
async function save(){
 if(saving.value)return;saving.value=true;error.value=''
 try{
  const payload=modulePayload(def.value,form.value)
  if(!def.value.global && props.table!=='meeting_presenters')payload.organization_id=activeOrganization.value?.id
  await saveModule(props.table,payload,reviewed.value,editing.value)
  show.value=false;success.value=props.table==='brand_kits'?(form.value.is_default?'Identidade predefinida guardada e aplicada à aplicação.':'Identidade guardada. Ativa Predefinido para aplicar estas fontes e cores à aplicação.'):'Alteração guardada e registada no histórico.'
  if(props.table==='organizations')await loadOrganizations(true)
  if(props.table==='brand_kits')await loadBrandKit()
  await load()
 }catch(e){error.value=(e as Error).message}finally{saving.value=false}
}
</script>
<template>
 <section :aria-label="def.title">
  <div class="d-flex flex-column flex-sm-row align-items-start align-items-sm-center justify-content-between gap-3 mb-3"><p class="sq-muted mb-0">{{ def.description }}</p><button v-if="auth.isGlobalAdmin || !['organizations','organization_memberships'].includes(table)" class="btn btn-primary flex-shrink-0" :disabled="loading||(!def.global&&!activeOrganization)" @click="open()">{{table==='organization_memberships'?'Associar membro':'Novo registo'}}</button></div>
  <div v-if="error&&!show" class="alert alert-danger" role="alert">{{ error }}</div><div v-if="success" class="alert alert-success" role="status">{{ success }}</div>
  <div v-if="!activeOrganization&&!def.global" class="alert alert-info">Cria ou seleciona uma organização para começar.</div>
  <label class="form-label" :for="`search-${table}`">Pesquisar</label><input :id="`search-${table}`" v-model="search" class="form-control mb-3"/>
  <div class="table-responsive"><table class="sq-table"><thead><tr><th v-for="key in def.columns" :key="key">{{ def.fields.find(f=>f.key===key)?.label || (key==='decided_at'?'Data da decisão':key) }}</th><th>Ações</th></tr></thead><tbody>
   <tr v-if="loading"><td :colspan="def.columns.length+1">A carregar…</td></tr><tr v-else-if="!filtered.length"><td :colspan="def.columns.length+1">Nenhum registo encontrado.</td></tr>
   <tr v-for="row in filtered" v-else :key="row.id"><td v-for="key in def.columns" :key="key">{{ display(row,key) }}</td><td><button v-if="auth.isGlobalAdmin||table!=='organization_memberships'" class="btn btn-sm btn-outline-primary" @click="open(row)">Editar</button><button v-if="['teams','cycles','ppt_templates','frameworks'].includes(table)" class="btn btn-sm btn-outline-secondary ms-2" @click="inspectDependencies(row)">Utilização / eliminar</button></td></tr>
  </tbody></table></div>
  <section v-if="dependencies" class="border rounded p-3 mt-3"><h3 class="h6">Utilização de {{dependencies.row.name}}</h3><ul><li v-for="d in dependencies.dependencies" :key="d.table">{{dependencyLabels[d.table]||'Outros registos relacionados'}}: {{d.count}}</li></ul><p>{{dependencies.used?'Registo utilizado. Podes editar o nome ou desativar, preservando o histórico.':'Sem dependências atuais. A eliminação também verifica o histórico.'}}</p><p v-if="table==='cycles'">Num ciclo utilizado, mantém o framework e alarga o período se necessário. Para outro ano, cria um novo ciclo.</p><button v-if="!dependencies.used" class="btn btn-outline-danger" @click="removeStructure">Eliminar registo não utilizado</button><button class="btn btn-secondary ms-2" @click="dependencies=null">Fechar</button></section>
  <div v-if="show" class="modal d-block" role="dialog" aria-modal="true" :aria-label="def.title" tabindex="-1" style="background:rgba(0,0,0,.45)">
   <div class="modal-dialog modal-lg modal-dialog-scrollable"><form class="modal-content" @submit.prevent="save" @input="reviewed=false" @change="reviewed=false">
    <div class="modal-header"><h3 class="h5 mb-0">{{table==='organization_memberships'?(editing?'Editar associação à organização':'Associar membro à organização'):(editing?'Editar':'Criar')+' · '+def.title}}</h3><button type="button" class="btn-close" :disabled="saving" aria-label="Fechar" @click="show=false"></button></div>
    <div class="modal-body"><div v-if="error" class="alert alert-danger" role="alert">{{ error }}</div>
     <div v-if="table==='brand_kits'" class="p-3 mb-3 border rounded" :style="{backgroundColor:form.background_color,color:form.text_color,fontFamily:fontStack(form.font_body)}"><h4 :style="{color:form.primary_color,fontFamily:fontStack(form.font_heading)}">Pré-visualização da identidade</h4><p class="mb-0">{{ form.name || 'Nome da organização' }} · Qualidade e estratégia</p></div>
     <p v-if="table==='organization_memberships'" class="alert alert-info">Organização: {{activeOrganization?.name}}. As equipas, funções e acessos à aplicação são geridos em Administração › Utilizadores.</p><label v-if="def.fields.some(f=>f.relation==='profiles')" class="d-block mb-3"><input v-model="showInactive" type="checkbox"> Mostrar inativos (apenas consulta de associações anteriores)</label><div class="row g-3"><div v-for="field in def.fields" :key="field.key" :class="['textarea','multi'].includes(field.type||'')?'col-12':'col-12 col-md-6'">
      <label class="form-label" :for="`field-${field.key}`">{{ field.label }} {{ field.required?'*':'' }}</label>
      <FontPicker v-if="field.type==='font'" :id="`field-${field.key}`" v-model="form[field.key]" :disabled="saving" @update:model-value="reviewed=false"/>
      <textarea v-else-if="field.type==='textarea'" :id="`field-${field.key}`" v-model="form[field.key]" rows="4" class="form-control" :required="field.required" :disabled="saving"></textarea>
      <select v-else-if="field.type==='select'" :id="`field-${field.key}`" v-model="form[field.key]" class="form-select" :required="field.required" :disabled="saving"><option value="">Selecionar…</option><option v-for="option in fieldOptions(field)" :key="option.value" :value="option.value" :disabled="option.active===false&&editing?.[field.key]!==option.value">{{ option.label }}</option></select>
      <div v-else-if="field.type==='multi'" :id="`field-${field.key}`" class="d-flex flex-wrap gap-3"><label v-for="option in field.options" :key="option.value" class="form-check"><input v-model="form[field.key]" type="checkbox" :value="option.value" class="form-check-input" :disabled="saving"/>{{ option.label }}</label></div>
      <input v-else-if="field.type==='checkbox'" :id="`field-${field.key}`" v-model="form[field.key]" type="checkbox" class="form-check-input d-block" :disabled="saving"/>
      <PtDateInput v-else-if="['date','datetime-local'].includes(field.type||'')" :id="`field-${field.key}`" v-model="form[field.key]" :type="field.type" class="form-control" :required="field.required" :disabled="saving"/><input v-else :id="`field-${field.key}`" v-model="form[field.key]" :type="field.type||'text'" class="form-control" :required="field.required" :min="field.min" :max="field.max" :disabled="saving"/>
      <small v-if="field.help" class="sq-muted">{{ field.help }}</small>
     </div></div>
     <BrandAssetEditor v-if="table==='brand_kits'&&editing?.id" :kit-id="editing.id" @saved="(s:any)=>{if(editing&&new Date(editing.updated_at).getTime()===new Date(s.before).getTime())editing.updated_at=s.after}"/>
     <p v-else-if="table==='brand_kits'" class="alert alert-info mt-3">Guarda a identidade visual e volta a editar para carregar o logótipo, ícone e favicon.</p>
     <StrategyHistory :key="editing?.id" :table="table" :record-id="editing?.id"/>
    </div>
    <div class="modal-footer d-block"><div @input.stop @change.stop><StrategyReview v-model="reviewed"/></div><div class="d-flex justify-content-end gap-2 mt-3"><button type="button" class="btn btn-secondary" :disabled="saving" @click="show=false">Cancelar</button><button type="submit" class="btn btn-primary" :disabled="saving||!reviewed">{{ saving?'A guardar…':'Guardar' }}</button></div></div>
   </form></div>
  </div>
 </section>
</template>
