<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { IconCheck } from '@tabler/icons-vue'

const auth = useAuthStore()
const newPassword = ref('')
const confirmPassword = ref('')
const msg = ref('')
const error = ref('')

async function changePassword() {
  error.value = ''; msg.value = ''
  if (newPassword.value.length < 8) { error.value = 'A password deve ter pelo menos 8 caracteres.'; return }
  if (newPassword.value !== confirmPassword.value) { error.value = 'As passwords não coincidem.'; return }
  try {
    await auth.updatePassword(newPassword.value)
    msg.value = 'Password alterada com sucesso.'
    newPassword.value = ''; confirmPassword.value = ''
  } catch (e) { error.value = (e as Error).message }
}
</script>

<template>
  <div class="row justify-content-center">
    <div class="col-xl-7">
      <PageHeader><template #title>Perfil</template><template #breadcrumb>Utilizador › Perfil</template></PageHeader>

      <div class="sq-card mb-3">
        <div class="d-flex align-items-center gap-3">
          <span class="sq-avatar" style="width:56px;height:56px;font-size:1.2rem">
            {{ auth.fullName.split(' ').filter(Boolean).slice(0,2).map(p=>p[0]?.toUpperCase()).join('') || '?' }}
          </span>
          <div>
            <h5 class="mb-0">{{ auth.fullName }}</h5>
            <span class="sq-muted">{{ auth.role }}</span>
          </div>
        </div>
      </div>

      <div class="sq-card">
        <h6 class="sq-card-title">Alterar password</h6>
        <div class="mb-3">
          <input v-model="newPassword" type="password" class="form-control" placeholder="Nova password (mín. 8)" />
        </div>
        <div class="mb-3">
          <input v-model="confirmPassword" type="password" class="form-control" placeholder="Confirmar nova password" />
        </div>
        <div v-if="error" class="alert alert-danger py-2">{{ error }}</div>
        <div v-if="msg" class="alert alert-success py-2 d-flex align-items-center gap-2"><IconCheck :size="16" /> {{ msg }}</div>
        <button class="btn btn-primary" style="background:#7367f0;border-color:#7367f0" @click="changePassword">Alterar password</button>
      </div>
    </div>
  </div>
</template>
