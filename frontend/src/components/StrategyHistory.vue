<script setup lang="ts">
import { ref } from 'vue'
import {historyAction,readableChanges} from '@/domain/history-labels'
import { listStrategyHistory } from '@/services/strategy'
const props=defineProps<{table: string; recordId?: string}>()
const rows=ref<Record<string, any>[]>([]), error=ref(''), loaded=ref(false)
async function load() {
  if(!props.recordId) return
  try { rows.value=await listStrategyHistory(props.table,props.recordId);loaded.value=true }
  catch(e) { error.value=(e as Error).message }
}
</script>
<template>
  <details v-if="recordId" class="mt-3" @toggle="!loaded && load()">
    <summary>Histórico de alterações validadas</summary>
    <p v-if="error" class="text-danger">{{ error }}</p>
    <p v-if="loaded && !rows.length" class="sq-muted">Sem alterações registadas desde a ativação do histórico.</p>
    <div v-for="row in rows" :key="row.id" class="border-bottom py-2 small">
      <strong>{{ new Date(row.reviewed_at).toLocaleString('pt-PT') }} · {{ historyAction(row) }}</strong>
      <div>Validado por: {{ row.actor_name }}</div>
      <ul><li v-for="change in readableChanges(table,row)" :key="change" style="overflow-wrap:anywhere">{{ change }}</li></ul>
      <details><summary>Detalhes técnicos</summary><pre style="white-space:pre-wrap;overflow-wrap:anywhere">{{ JSON.stringify({id:row.id,autor:row.reviewed_by,antes:row.before_data,depois:row.after_data},null,2) }}</pre></details>
    </div>
  </details>
</template>
