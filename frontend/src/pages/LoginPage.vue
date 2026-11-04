<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { isSupabaseConfigured } from '@/lib/supabase'
import { APP_VERSION } from '@/version'
import { IconLock, IconMail, IconAlertTriangle } from '@tabler/icons-vue'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const email = ref('')
const password = ref('')
const error = ref('')
const submitting = ref(false)

async function submit() {
  error.value = ''
  submitting.value = true
  try {
    await auth.signIn(email.value.trim(), password.value)
    const redirect = (route.query.redirect as string) || '/dashboard'
    router.push(redirect)
  } catch (e) {
    error.value = (e as Error).message || 'Não foi possível entrar. Verifica os dados.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card">
      <!-- Imagem corporativa -->
      <div class="auth-hero">
        <img src="/login-banner.jpg" alt="SAMSYS — Qualidade que impulsiona melhores resultados" />
      </div>

      <div class="auth-body">
        <div v-if="!isSupabaseConfigured" class="caution-card mb-3">
          <div class="d-flex gap-3">
            <IconAlertTriangle :size="40" style="color:#ea5455" />
            <div>
              <h5 class="mb-1">Supabase não configurado</h5>
              <p class="mb-2" style="color:var(--sq-text)">
                Copia <code>frontend/.env.example</code> para <code>frontend/.env</code> e
                preenche <code>VITE_SUPABASE_URL</code> e <code>VITE_SUPABASE_ANON_KEY</code>.
              </p>
              <p class="mb-0 sq-muted" style="font-size:.8rem">
                Aplica também as migrations em <code>supabase/migrations/</code> e o <code>seed.sql</code>.
              </p>
            </div>
          </div>
        </div>

        <div class="text-center mb-4">
          <h4 class="mb-0">SAMSYS|Qualidade</h4>
          <p class="sq-muted" style="font-size:.85rem">Qualidade que se vê. Melhoria que se acompanha.</p>
        </div>

        <form @submit.prevent="submit">
          <div class="mb-3">
            <label class="form-label">Email</label>
            <div class="input-group">
              <span class="input-group-text"><IconMail :size="16" /></span>
              <input v-model="email" type="email" class="form-control" placeholder="nome@samsys.pt" required />
            </div>
          </div>

          <div class="mb-3">
            <label class="form-label">Password</label>
            <div class="input-group">
              <span class="input-group-text"><IconLock :size="16" /></span>
              <input v-model="password" type="password" class="form-control" placeholder="••••••••" required />
            </div>
          </div>

          <div v-if="error" class="alert alert-danger py-2" style="font-size:.85rem">{{ error }}</div>

          <button class="btn btn-primary w-100" :disabled="submitting" style="background:var(--sq-primary);border-color:var(--sq-primary)">
            {{ submitting ? 'A entrar…' : 'Entrar' }}
          </button>
        </form>

        <div class="text-center mt-3">
          <router-link to="/recuperar-password" class="sq-muted" style="font-size:.85rem;text-decoration:none">
            Esqueci-me da password
          </router-link>
        </div>
      </div>

      <!-- Versão -->
      <div class="auth-version">v{{ APP_VERSION }}</div>
    </div>
  </div>
</template>

<style scoped>
.auth-wrap {
  min-height: 100vh; display: grid; place-items: center; padding: 1.5rem;
  background: linear-gradient(135deg, var(--sq-primary) 0%, var(--sq-secondary) 100%);
}
.auth-card {
  width: 100%; max-width: 440px; background: #fff; border-radius: 0.75rem;
  box-shadow: 0 8px 30px rgba(0,0,0,.18); overflow: hidden; position: relative;
}
.auth-hero { width: 100%; }
.auth-hero img { width: 100%; height: 130px; object-fit: cover; display: block; }
.auth-body { padding: 1.6rem 2rem 0.8rem; }
.auth-version {
  text-align: center; padding: .5rem 0 .85rem;
  color: #a5a3ae; font-size: .72rem; letter-spacing: .03em;
  border-top: 1px solid #f1f1f5;
}
.caution-card { font-size: .85rem; }
</style>