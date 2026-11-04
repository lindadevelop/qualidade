<script setup lang="ts">
import {ref,watch} from 'vue'
import {qualityCommand} from '@/services/quality'
const props=defineProps<{settings:any;catalogs:any[];people:{value:string;label:string}[]}>()
const emit=defineEmits(['saved'])
const draft=ref<any>({}),classifications=ref<any[]>([]),busy=ref(false),error=ref(''),saved=ref(false)
function reset(){const s=props.settings||{};draft.value={expected_version:s.version||0,deadline_approval:!!s.deadline_approval,reminder_days:(s.reminder_days||[7,3,1]).join(', '),retry_minutes:(s.retry_minutes||[5,30,120]).join(', '),overdue_reminder_days:(s.overdue_reminder_days||[1,3]).join(', '),quality_escalation_days:s.quality_escalation_days??5,leader_escalation_days:s.leader_escalation_days??10,escalation_leader_id:s.escalation_leader_id||''};classifications.value=props.catalogs.filter(c=>c.kind==='nc_classification').map(c=>({...c}));error.value=''}
watch(()=>[props.settings,props.catalogs],reset,{immediate:true})
function add(){saved.value=false;classifications.value.push({name:'',active:true,is_system:false,used_count:0})}
function parse(text:string){return text.split(',').map(v=>Number(v.trim()))}
async function remove(c:any){if(!c.id){classifications.value=classifications.value.filter(x=>x!==c);return}if(!confirm('Eliminar a classificação se nunca foi utilizada?'))return;try{await qualityCommand('config_delete',c.id,{kind:'catalog',confirm_delete:true});emit('saved')}catch(e){error.value=(e as Error).message}}
async function save(){busy.value=true;error.value='';saved.value=false;try{await qualityCommand('settings_save',null,{...draft.value,reminder_days:parse(draft.value.reminder_days),retry_minutes:parse(draft.value.retry_minutes),overdue_reminder_days:parse(draft.value.overdue_reminder_days),quality_escalation_days:Number(draft.value.quality_escalation_days),leader_escalation_days:Number(draft.value.leader_escalation_days),nc_classifications:classifications.value.filter(c=>c.id||c.name.trim()).map(c=>({id:c.id,name:c.name,active:c.active}))});saved.value=true;emit('saved')}catch(e){error.value=(e as Error).message}finally{busy.value=false}}
</script>
<template>
 <form @submit.prevent="save" class="sq-card" aria-label="Configuração operacional">
  <p class="sq-muted">Configuração da empresa selecionada. As alterações ficam registadas no histórico.</p>
  <p v-if="saved" class="alert alert-success" role="status">Configuração guardada.</p>
  <p v-if="error" class="alert alert-danger" role="alert">{{error}}</p>
  <fieldset :disabled="busy">
   <div class="form-check mb-4"><input id="op-approval" v-model="draft.deadline_approval" type="checkbox" class="form-check-input"/><label for="op-approval" class="form-check-label">Alterações de prazo exigem aprovação</label></div>
   <div class="row g-3 mb-4">
    <div class="col-md-6"><label for="op-reminders" class="form-label">Lembretes antes do prazo (dias)</label><input id="op-reminders" v-model="draft.reminder_days" class="form-control" required/><small class="sq-muted">Dias separados por vírgula. Apenas são enviados os lembretes ainda possíveis.</small></div>
    <div class="col-md-6"><label for="op-retries" class="form-label">Tentativas de reenvio de email (minutos)</label><input id="op-retries" v-model="draft.retry_minutes" class="form-control" required/></div>
   </div>
   <h2 class="fs-5">Avisos após o prazo</h2>
   <div class="row g-3 mb-4">
    <div class="col-md-6"><label for="op-overdue" class="form-label">Informar responsável (dias de atraso)</label><input id="op-overdue" v-model="draft.overdue_reminder_days" class="form-control" required/></div>
    <div class="col-md-6"><label for="op-quality" class="form-label">Informar Qualidade (dias úteis)</label><input id="op-quality" v-model="draft.quality_escalation_days" type="number" min="1" max="3650" class="form-control" required/></div>
    <div class="col-md-6"><label for="op-leader-days" class="form-label">Informar líder (dias úteis)</label><input id="op-leader-days" v-model="draft.leader_escalation_days" type="number" min="1" max="3650" class="form-control" required/></div>
    <div class="col-md-6"><label for="op-leader" class="form-label">Líder a informar</label><select id="op-leader" v-model="draft.escalation_leader_id" class="form-select"><option value="">Não configurado — sem aviso ao líder</option><option v-for="p in people" :key="p.value" :value="p.value">{{p.label}}</option></select></div>
   </div>
   <h2 class="fs-5">Classificações de NC</h2>
   <h3 class="fs-6 mt-3">Base do produto</h3>
   <ul class="list-unstyled"><li v-for="c in classifications.filter(c=>c.is_system)" :key="c.id" class="mb-2">{{c.name}} <span class="badge bg-light text-dark ms-2">Protegida · Ativa</span></li></ul>
   <h3 class="fs-6 mt-3">Adicionais da organização</h3>
   <p v-if="!classifications.some(c=>!c.is_system)" class="sq-muted">Não existem classificações adicionais.</p>
   <div v-for="(c,index) in classifications.filter(c=>!c.is_system)" :key="c.id||'new-'+index" class="row g-2 align-items-center border-bottom py-2">
    <div class="col-md-7"><label :for="'nc-name-'+index" class="form-label">Nome</label><input :id="'nc-name-'+index" v-model="c.name" :readonly="c.used_count>0" :required="!!c.id||!!c.name.trim()" maxlength="120" class="form-control"/><small v-if="c.used_count" class="sq-muted">Já utilizada. O nome é preservado para manter o histórico.</small></div>
    <div class="col-md-5 d-flex gap-2 align-items-center pt-3"><span>{{c.active?'Ativa':'Inativa'}}</span><button type="button" class="btn btn-sm btn-outline-primary" @click="c.active=!c.active">{{c.active?'Desativar':'Ativar'}}</button><button type="button" class="btn btn-sm btn-outline-danger" @click="remove(c)">{{c.id?'Eliminar':'Descartar'}}</button></div>
   </div>
   <button type="button" class="btn btn-outline-primary mt-3" @click="add">+ Adicionar classificação</button>
   <div class="d-flex justify-content-end gap-2 mt-4"><button type="button" class="btn btn-outline-secondary" @click="reset();saved=false">Cancelar</button><button type="submit" class="btn btn-primary">{{busy?'A guardar…':'Guardar'}}</button></div>
  </fieldset>
 </form>
</template>
