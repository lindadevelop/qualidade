<script setup lang="ts">
import {API_BASE} from '@/lib/api-base'

import {computed,onMounted,ref,watch} from 'vue'
import {supabase} from '@/lib/supabase'
import {useAuthStore} from '@/stores/auth'
const auth=useAuthStore()
const organizations=ref<{id:string;name:string}[]>([]),company=ref(''),module=ref('lifecycle'),busy=ref(false),error=ref(''),success=ref(''),confirmation=ref(''),password=ref('')
const preview=ref<{token:string;counts:Record<string,number>;confirmation:string}|null>(null)
const modules=[{id:'quality',name:'Qualidade',description:'Não conformidades, ocorrências, ações, planos, comentários, anexos e registos associados.'},{id:'lifecycle',name:'LifeCycle RH',description:'Pessoas, candidaturas, vagas, avaliações, entrevistas, tarefas e registos de CV.'},{id:'strategy',name:'Estratégia',description:'SWOT/TOWS, riscos, objetivos, ações, indicadores, projetos, decisões, reuniões e apresentações geradas.'}]
const labels:Record<string,string>={quality_occurrences:'Ocorrências e não conformidades',quality_actions:'Ações',quality_attachments:'Referências a anexos',quality_comments:'Comentários',quality_compliance_plans:'Planos de conformidade',quality_compliance_plan_links:'Ligações entre planos',quality_occurrence_categories:'Categorias das ocorrências',quality_occurrence_relations:'Relações entre ocorrências',quality_occurrence_tags:'Etiquetas das ocorrências',quality_plan_approval_events:'Aprovações dos planos',quality_progress_history:'Histórico de progresso',quality_work_logs:'Registos de trabalho',quality_action_dependencies:'Dependências entre ações',ai_interactions:'Interações de IA',lifecycle_avaliacoes:'Avaliações',lifecycle_casos:'Candidaturas',lifecycle_certificacoes:'Certificações',lifecycle_competencias:'Competências',lifecycle_comunicacoes:'Comunicações',lifecycle_cv_jobs:'Registos de processamento de CV',lifecycle_entrevistas:'Entrevistas',lifecycle_experiencias:'Experiências',lifecycle_formacoes:'Formações',lifecycle_idiomas:'Idiomas',lifecycle_pessoas:'Pessoas',lifecycle_projetos:'Projetos dos candidatos',lifecycle_referencias:'Referências',lifecycle_tarefas:'Tarefas',lifecycle_vagas:'Vagas',swot_campaigns:'Campanhas SWOT',swot_items:'Itens SWOT',swot_contributions:'Contributos SWOT',tows_crossings:'Cruzamentos TOWS',risk_opportunities:'Riscos e oportunidades',strategic_objectives:'Objetivos',strategic_actions:'Ações estratégicas',kpis:'Indicadores',kpi_targets:'Metas',kpi_results:'Resultados',effectiveness_evaluations:'Avaliações de eficácia',projects:'Projetos',decisions:'Decisões',evidences:'Referências a evidências',meetings:'Reuniões',meeting_presenters:'Apresentadores',submissions:'Submissões',generated_files:'Referências a apresentações geradas'}
const total=computed(()=>Object.values(preview.value?.counts||{}).reduce((a,b)=>a+b,0))
watch([company,module],()=>{preview.value=null;confirmation.value='';password.value='';error.value='';success.value=''})
onMounted(async()=>{const {data,error:e}=await supabase.from('organizations').select('id,name').order('name');if(e){error.value=e.message;return}organizations.value=data||[];company.value=auth.isGlobalAdmin?'':auth.profile?.organization_id||''})
async function request(action:string,body:object){const {data:{session}}=await supabase.auth.getSession();if(!session)throw new Error('Inicia sessão novamente.');const r=await fetch(`${API_BASE}/auth/v1/admin/data-reset/${action}`,{method:'POST',headers:{Authorization:`Bearer ${session.access_token}`,'Content-Type':'application/json'},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw new Error(d.msg||'Não foi possível concluir a operação.');return d}
async function inspect(){busy.value=true;error.value='';success.value='';preview.value=null;confirmation.value='';password.value='';try{preview.value=await request('preview',{organization_id:company.value,module:module.value})}catch(e){error.value=(e as Error).message}finally{busy.value=false}}
async function erase(){if(!preview.value||confirmation.value!==preview.value.confirmation||!password.value)return;busy.value=true;error.value='';try{const result=await request('execute',{organization_id:company.value,module:module.value,token:preview.value.token,confirmation:confirmation.value,password:password.value});success.value=result.msg;preview.value=null;confirmation.value=''}catch(e){error.value=(e as Error).message}finally{password.value='';busy.value=false}}
</script>
<template>
 <section aria-label="Limpeza de dados">
  <p>Apaga os dados operacionais de <strong>um programa numa empresa</strong>. Os outros programas mantêm os seus dados.</p>
  <div class="alert alert-warning">Esta operação é irreversível na aplicação. Utilizadores, empresas, áreas, categorias, etiquetas, configurações, frameworks e modelos são preservados. Os registos de auditoria e os ficheiros no armazenamento também são preservados; são apagadas as referências operacionais aos ficheiros.</div>
  <div v-if="error" class="alert alert-danger" role="alert">{{error}}</div><div v-if="success" class="alert alert-success" role="status">{{success}}</div>
  <div class="row g-3"><div class="col-md-6"><label for="reset-company" class="form-label">Empresa</label><select id="reset-company" v-model="company" class="form-select" :disabled="busy||!auth.isGlobalAdmin"><option value="">Seleciona a empresa</option><option v-for="o in organizations" :key="o.id" :value="o.id">{{o.name}}</option></select></div><div class="col-md-6"><label for="reset-module" class="form-label">Programa</label><select id="reset-module" v-model="module" class="form-select" :disabled="busy"><option v-for="m in modules" :key="m.id" :value="m.id" :disabled="m.id==='quality'">{{m.name}}{{m.id==='quality'?' — usar anulação (v2.5)':''}}</option></select></div></div>
  <p class="sq-muted mt-3">{{modules.find(m=>m.id===module)?.description}}</p>
  <button class="btn btn-outline-primary" :disabled="busy||!company" @click="inspect">{{busy?'A verificar…':'Pré-visualizar dados a apagar'}}</button>
  <div v-if="preview" class="mt-4">
   <p><strong>{{total}} registos abrangidos</strong> · Confirmação válida durante 5 minutos. Se os dados mudarem, é necessário verificar novamente.</p>
   <div class="table-responsive"><table class="sq-table"><thead><tr><th>Tipo de registo</th><th>Quantidade</th></tr></thead><tbody><tr v-for="(count,key) in preview.counts" :key="key"><td>{{labels[key]||key}}</td><td>{{count}}</td></tr></tbody></table></div>
   <form v-if="total>0" class="mt-3" @submit.prevent="erase">
    <label for="reset-confirmation" class="form-label">Para confirmar, escreve: <strong>{{preview.confirmation}}</strong></label><input id="reset-confirmation" v-model="confirmation" class="form-control mb-3" autocomplete="off" :disabled="busy"/>
    <label for="reset-password" class="form-label">A tua senha de administrador</label><input id="reset-password" v-model="password" type="password" class="form-control mb-3" autocomplete="current-password" :disabled="busy"/>
    <button class="btn btn-danger" type="submit" :disabled="busy||confirmation!==preview.confirmation||!password">{{busy?'A processar…':'Apagar definitivamente os dados deste programa'}}</button>
   </form><p v-else class="sq-muted">Não há dados para apagar neste programa e empresa.</p>
  </div>
 </section>
</template>
