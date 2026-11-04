<script setup lang="ts">
import {ref,onMounted} from 'vue'
import {supabase} from '@/lib/supabase'
import {useOrganization} from '@/composables/useOrganization'
import {parseKpiCsv,type CsvResult} from '@/domain/kpi-csv'
import {validatePeriod} from '@/domain/strategy-workflows'
import StrategyReview from './StrategyReview.vue'
const {activeOrganization}=useOrganization()
const connectors=ref<{id:string;name:string}[]>([]),connector=ref(''),error=ref(''),success=ref(''),busy=ref(false),reviewed=ref(false)
const preview=ref<(CsvResult&{id:string|null;updated_at:string|null})[]>([])
async function loadConnectors(){const {data,error:e}=await supabase.from('connectors').select('id,name').eq('organization_id',activeOrganization.value?.id??'').eq('provider','csv_kpi').eq('active',true);if(e)throw e;connectors.value=data??[]}
onMounted(()=>loadConnectors().catch(e=>error.value=e.message))
async function read(event:Event){
 preview.value=[];reviewed.value=false;error.value='';success.value='';busy.value=true
 try{
  const file=(event.target as HTMLInputElement).files?.[0];if(!file)return;if(file.size>1000000)throw new Error('O ficheiro excede 1 MB.')
  const rows=parseKpiCsv(await file.text());await loadConnectors()
  const {data:kpis,error:e}=await supabase.from('kpis').select('id,code,frequency').eq('organization_id',activeOrganization.value?.id??'').eq('active',true);if(e)throw e
  const result=[]
  for(const row of rows){const k=kpis?.find(k=>k.code===row.codigo);if(!k)throw new Error(`KPI desconhecido: ${row.codigo}`);validatePeriod(row.periodo,k.frequency)
   const {data,error:e}=await supabase.from('kpi_results').select('id,updated_at').eq('kpi_id',k.id).eq('period',row.periodo).maybeSingle();if(e)throw e
   result.push({...row,id:data?.id??null,updated_at:data?.updated_at??null})
  }
  preview.value=result
 }catch(e){error.value=(e as Error).message}finally{busy.value=false}
}
async function save(){busy.value=true;error.value='';try{const {data,error:e}=await supabase.rpc('import_kpi_csv',{p_connector_id:connector.value,p_rows:preview.value,p_human_confirmed:reviewed.value});if(e)throw e;success.value=`${data} resultados importados com histórico.`;preview.value=[];reviewed.value=false}catch(e){error.value=(e as Error).message;reviewed.value=false}finally{busy.value=false}}
</script>
<template><section class="sq-card mt-3"><h2 class="h5">Importar resultados KPI</h2><p>CSV UTF-8, até 500 linhas. Cabeçalho: <code>codigo;periodo;valor;notas</code>. Exemplo: <code>KPI-01;2026-10;95,5;Validado</code>. Os resultados existentes serão atualizados após revisão.</p><div v-if="error" class="alert alert-danger" role="alert">{{error}}</div><div v-if="success" class="alert alert-success" role="status">{{success}}</div>
<label for="csv-connector" class="form-label">Conector CSV ativo</label><select id="csv-connector" v-model="connector" class="form-select mb-3" :disabled="busy" @change="reviewed=false" @focus="loadConnectors().catch(e=>error=e.message)"><option value="">Selecionar…</option><option v-for="c in connectors" :key="c.id" :value="c.id">{{c.name}}</option></select>
<label for="csv-file" class="form-label">Ficheiro CSV</label><input id="csv-file" type="file" accept=".csv,text/csv" class="form-control" :disabled="busy" @change="read"/><p v-if="busy" role="status">A processar…</p>
<div v-if="preview.length" class="mt-3"><div class="table-responsive" style="max-height:360px"><table class="sq-table"><thead><tr><th>Código</th><th>Período</th><th>Valor</th><th>Notas</th><th>Operação</th></tr></thead><tbody><tr v-for="r in preview" :key="r.codigo+r.periodo"><td>{{r.codigo}}</td><td>{{r.periodo}}</td><td>{{r.valor}}</td><td>{{r.notas}}</td><td>{{r.id?'Atualizar':'Criar'}}</td></tr></tbody></table></div><StrategyReview v-model="reviewed"/><button class="btn btn-primary mt-3" :disabled="busy||!reviewed||!connector" @click="save">Importar {{preview.length}} resultados</button></div></section></template>
