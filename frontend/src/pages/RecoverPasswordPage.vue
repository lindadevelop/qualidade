<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { IconMail, IconCheck } from '@tabler/icons-vue'

const auth = useAuthStore()
const email = ref('')
const sent = ref(false)
const error = ref('')

async function submit() {
  error.value = ''
  try {
    await auth.requestPasswordReset(email.value.trim())
    sent.value = true
  } catch (e) { error.value = (e as Error).message }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card">
      <div class="text-center mb-4">
        <div class="sq-brand-badge mx-auto mb-2" style="width:46px;height:46px;font-size:1.1rem">SQ</div>
        <h4 class="mb-0">Recuperar password</h4>
        <p class="sq-muted" style="font-size:.85rem">Enviaremos um link para redefinir a tua password.</p>
      </div>
      <div v-if="sent" class="alert alert-success d-flex align-items-center gap-2">
        <IconCheck :size="18" /> Se existir uma conta ativa para este email, receberás uma ligação de recuperação.
      </div>
      <form v-else @submit.prevent="submit">
        <div class="mb-3">
          <div class="input-group">
            <span class="input-group-text"><IconMail :size="16" /></span>
            <input v-model="email" type="email" class="form-control" placeholder="nome@samsys.pt" required />
          </div>
        </div>
        <div v-if="error" class="alert alert-danger py-2" style="font-size:.85rem">{{ error }}</div>
        <button class="btn btn-primary w-100" >Enviar link</button>
      </form>
      <div class="text-center mt-3">
        <router-link to="/login" class="sq-muted" style="font-size:.85rem;text-decoration:none">Voltar ao login</router-link>
      </div>
    </div>
  </div>
</template>

<style scoped>
.auth-wrap { min-height:100vh; display:grid; place-items:center; padding:1.5rem; background:linear-gradient(135deg,#7367f0,#9f8ffb 45%,#ce9ffc) }
.auth-card { width:100%; max-width:400px; background:#fff; border-radius:.75rem; box-shadow:0 8px 30px rgba(0,0,0,.18); padding:2.25rem }
.sq-brand-badge { width:32px; height:32px; border-radius:8px; display:grid; place-items:center; color:#fff; font-weight:700; background:linear-gradient(135deg,#7367f0,#ce9ffc) }
</style>
