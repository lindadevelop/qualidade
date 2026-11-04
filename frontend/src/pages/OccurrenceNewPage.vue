<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { createOccurrence, listAreas, listOrigins, listProfiles } from '@/services/occurrences'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()
const areas = ref<any[]>([])
const origins = ref<any[]>([])
const profiles = ref<any[]>([])
const error = ref('')
const saving = ref(false)

const form = ref({
  type: 'NC',
  origin_id: '',
  area_id: '',
  occurrence_date: new Date().toISOString().slice(0, 10),
  description: '',
  responsible_user_id: '' as any,
  cause_analysis: '',
})

onMounted(async () => {
  ;[areas.value, origins.value, profiles.value] = await Promise.all([listAreas(), listOrigins(), listProfiles()])
})

async function submit() {
  error.value = ''
  if (!form.value.area_id || !form.value.origin_id || !form.value.description.trim()) {
    error.value = 'Preenche área, origem e descrição.'
    return
  }
  saving.value = true
  try {
    const created = await createOccurrence({
      type: form.value.type as any,
      origin_id: form.value.origin_id,
      area_id: form.value.area_id,
      occurrence_date: form.value.occurrence_date,
      description: form.value.description,
      responsible_user_id: form.value.responsible_user_id || null,
      cause_analysis: form.value.cause_analysis || null,
    })
    router.push('/ocorrencias/' + created.id)
  } catch (e) {
    error.value = (e as Error).message
  } finally { saving.value = false }
}
</script>

<template>
  <div class="row justify-content-center">
    <div class="col-xl-8">
      <PageHeader><template #title>Nova Ocorrência</template><template #breadcrumb>Qualidade › Nova Ocorrência</template></PageHeader>

      <div class="sq-card">
        <div class="mb-3">
          <label class="form-label">Tipo</label>
          <div class="d-flex gap-2">
            <button class="btn" :class="form.type==='NC' ? 'btn-danger' : 'btn-outline-danger'" @click="form.type='NC'">Não Conformidade (NC)</button>
            <button class="btn" :class="form.type==='OM' ? 'btn-primary' : 'btn-outline-primary'" @click="form.type='OM'">Oportunidade de Melhoria (OM)</button>
          </div>
        </div>

        <div class="row g-3">
          <div class="col-md-6">
            <label class="form-label">Origem</label>
            <select v-model="form.origin_id" class="form-select" required>
              <option value="" disabled>Seleciona…</option>
              <option v-for="o in origins" :value="o.id" :key="o.id">{{ o.name }}</option>
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label">Área / Processo</label>
            <select v-model="form.area_id" class="form-select" required>
              <option value="" disabled>Seleciona…</option>
              <option v-for="a in areas" :value="a.id" :key="a.id">{{ a.name }}</option>
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label">Data</label>
            <PtDateInput v-model="form.occurrence_date" type="date" class="form-control" />
          </div>
          <div class="col-md-6">
            <label class="form-label">Responsável</label>
            <select v-model="form.responsible_user_id" class="form-select">
              <option :value="''">Sem responsável</option>
              <option v-for="p in profiles" :value="p.id" :key="p.id">{{ p.full_name }}</option>
            </select>
          </div>
          <div class="col-12">
            <label class="form-label">Descrição</label>
            <textarea v-model="form.description" class="form-control" rows="4" placeholder="Descreve a ocorrência…"></textarea>
          </div>
          <div class="col-12">
            <label class="form-label">Análise / Causa</label>
            <textarea v-model="form.cause_analysis" class="form-control" rows="2" placeholder="Análise de causa (opcional)"></textarea>
          </div>
        </div>

        <div v-if="error" class="alert alert-danger mt-3">{{ error }}</div>
        <div class="d-flex justify-content-end gap-2 mt-3">
          <router-link to="/ocorrencias" class="btn btn-outline-secondary">Cancelar</router-link>
          <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" :disabled="saving" @click="submit">
            {{ saving ? 'A guardar…' : 'Criar ocorrência' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
