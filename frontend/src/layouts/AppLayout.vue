<script setup lang="ts">
import { moduleForPath } from '@/domain/module-access'
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  IconLayoutDashboard, IconClipboardList, IconAlertTriangle, IconTarget, IconArrowUpCircle,
  IconReportAnalytics, IconChartPie, IconSettings, IconUserCircle, IconSearch, IconBell, IconSparkles,
  IconMenu2, IconLogout, IconSun, IconMoon, IconMoonStars, IconChevronDown, IconCheck, IconUsers,
  IconChess, IconPresentation, IconBuilding, IconPalette, IconFrame, IconTemplate, IconPlug,
} from '@tabler/icons-vue'
import { useAuthStore } from '@/stores/auth'
import { useUiStore } from '@/stores/ui'
import { useSettingsStore } from '@/stores/settings'
import { useOrganization } from '@/composables/useOrganization'
import { useBrandKit } from '@/composables/useBrandKit'
import { APP_VERSION } from '@/version'
import { formatDateTime } from '@/utils/format'
import { supabase } from '@/lib/supabase'
import type { Notification } from '@/types/database'

const globalSearch=ref('')
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const ui = useUiStore()
const settings = useSettingsStore()
const { organizations, activeOrganization, orgId, setOrganization, loadOrganizations } = useOrganization()
const {logo,icon,brandError}=useBrandKit()

onMounted(() => { void loadOrganizations() })

const contextLabel=computed(()=>route.path.startsWith('/administracao')?'Administração geral':route.path.startsWith('/estrategia')||['/reunioes','/apresentacoes'].includes(route.path)?'Plataforma Estratégica':route.path.startsWith('/lifecycle')?'LifeCycle RH':'Qualidade')
const contextDescription=computed(()=>route.path.startsWith('/administracao')?'Configuração transversal · organizações, pessoas e recursos partilhados':contextLabel.value==='Plataforma Estratégica'?'Planeamento, participação e acompanhamento':contextLabel.value==='LifeCycle RH'?'Pessoas e percurso profissional':'Auditorias, ocorrências e melhoria contínua')
const sidebarCollapsed = computed(() => ui.sidebarCollapsed)
const mobileOpen = computed(() => ui.mobileSidebarOpen)
const isDark = computed(() => ui.isDark)

// Menu — itens visíveis consoante permissões
const canManage = computed(() => auth.canManage)
const menu = computed(() => [
  {to:'/meu-trabalho',label:'O meu trabalho',icon:IconClipboardList,section:'Qualidade'},
  {to:'/auditorias',label:'Auditorias',icon:IconReportAnalytics,section:'Qualidade'},
  {to:'/notificacoes',label:'Notificações',icon:IconBell,section:'Qualidade'},
  { to: '/dashboard', label: 'Visão Geral', icon: IconLayoutDashboard, section: 'Dashboard' },
  {
    to: '/ocorrencias', label: 'Todas as Ocorrências', icon: IconClipboardList, section: 'Qualidade',
    show: true,
  },
  { to: '/ocorrencias/nova', label: 'Nova Ocorrência', icon: IconTarget, section: 'Qualidade', show: canManage.value },
  { to: '/acoes', label: 'Todas as Ações', icon: IconAlertTriangle, section: 'Plano de Ações' },
  { to: '/lifecycle-rh', label: 'LifeCycle RH', icon: IconUsers, section: 'Recursos Humanos', show: auth.canManageLifecycle && (auth.isGlobalAdmin || settings.lifecycleVisivel) },
  { to: '/eficacia', label: 'A aguardar validação', icon: IconArrowUpCircle, section: 'Eficácia', show: canManage.value },
  { to: '/relatorios', label: 'Relatórios', icon: IconReportAnalytics, section: 'Análise' },
  { to: '/revisao-gestao', label: 'Revisão pela Gestão', icon: IconChartPie, section: 'Análise' },
  { to: '/assistente-ia', label: 'Assistente IA', icon: IconSparkles, section: 'Análise', show: canManage.value },
  {to:'/estrategia/campanhas',label:'Campanhas SWOT',icon:IconClipboardList,section:'Estratégia',show:auth.isGlobalAdmin||settings.strategyVisivel},
  { to: '/estrategia', label: 'Plataforma Estratégica', icon: IconChess, section: 'Estratégia', show: auth.canManageStrategy && (auth.isGlobalAdmin || settings.strategyVisivel) },
  { to: '/estrategia/decisoes', label: 'Decisões', icon: IconChess, section: 'Estratégia', show: auth.canManageStrategy && (auth.isGlobalAdmin || settings.strategyVisivel) },
  { to: '/reunioes', label: 'Reuniões', icon: IconPresentation, section: 'Estratégia', show: auth.canManageStrategy && (auth.isGlobalAdmin || settings.strategyVisivel) },
  { to: '/apresentacoes', label: 'Apresentações', icon: IconPresentation, section: 'Estratégia', show: auth.canManageStrategy && (auth.isGlobalAdmin || settings.strategyVisivel) },
  { to: '/administracao', label: 'Administração geral', icon: IconSettings, section: 'Administração', show: auth.canAdminister },
  { to: '/administracao/organizacoes', label: 'Organizações', icon: IconBuilding, section: 'Administração', show: auth.canAdminister },
  { to: '/administracao/brand-kits', label: 'Identidade visual (partilhada)', icon: IconPalette, section: 'Administração', show: auth.canAdminister },
  { to: '/administracao/frameworks', label: 'Frameworks', icon: IconFrame, section: 'Administração da Estratégia', show: auth.canAdminister },
  { to: '/administracao/templates-ppt', label: 'Templates PPT', icon: IconTemplate, section: 'Administração da Estratégia', show: auth.canAdminister },
  { to: '/administracao/conectores', label: 'Conectores', icon: IconPlug, section: 'Administração da Estratégia', show: auth.canAdminister },
].filter(item => { const module = moduleForPath(item.to); return !module || auth.hasModule(module) }))

// Prefer the most specific visible entry, retaining the parent for detail pages.
const activeMenuPath = computed(() => menu.value
  .filter(item => item.show !== false &&
    (route.path === item.to || route.path.startsWith(`${item.to}/`)))
  .sort((a, b) => b.to.length - a.to.length)[0]?.to)
const isActive = (path: string) => activeMenuPath.value === path

// -------- Notificações --------
const notifications = ref<Notification[]>([])
const unread = computed(() => notifications.value.filter((n) => !n.read).length)

async function loadNotifications() {
  const { data } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', auth.profile?.id ?? '')
    .order('created_at', { ascending: false })
    .limit(20)
  notifications.value = (data ?? []) as Notification[]
}

async function markAllRead() {
  await supabase
    .from('notifications')
    .update({ read: true })
    .eq('user_id', auth.profile?.id ?? '')
    .eq('read', false)
  await loadNotifications()
}

async function markRead(id: string) {
  await supabase.from('notifications').update({ read: true }).eq('id', id)
  await loadNotifications()
}

// badge unread ao vivo (Realtime)
onMounted(() => {
  if (auth.profile?.id) void loadNotifications()
  void settings.initFromDb()
})

const initials = computed(() => {
  const name = auth.fullName
  if (!name) return '?'
  return name.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]?.toUpperCase()).join('')
})

async function logout() {
  try {
    await auth.signOut()
  } catch {
    // mesmo que a API falhe, limpa o estado local e sai
    auth.profile = null
  }
  router.push('/login')
}

function cycleTheme() {
  if (ui.theme === 'light') ui.setTheme('dark')
  else if (ui.theme === 'dark') ui.setTheme('system')
  else ui.setTheme('light')
}
</script>

<template>
  <div class="sq-app" :data-bs-theme="isDark ? 'dark' : 'light'">
    <!-- Overlay mobile -->
    <div
      v-if="mobileOpen"
      class="sq-sidebar-backdrop"
      style="position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:1040"
      @click="ui.closeMobileSidebar()"
    />

    <aside class="sq-sidebar" :class="{ collapsed: sidebarCollapsed && !mobileOpen, 'mobile-open': mobileOpen }">
      <router-link to="/dashboard" class="sq-brand">
        <img v-if="sidebarCollapsed?(icon||logo):logo" :src="sidebarCollapsed?(icon||logo):logo" :alt="activeOrganization?.name||'Organização'" style="max-width:100%;max-height:42px;object-fit:contain">
        <template v-else><span class="sq-brand-badge">SQ</span><span class="sq-brand-text">Plataforma Samsys</span></template>
      </router-link>

      <nav v-if="menu.length">
        <template v-for="sec in [...new Set(menu.map((m) => m.section))]" :key="sec">
          <template v-if="menu.some((m) => m.section === sec && (m.show ?? true))">
          <div class="sq-nav-title">{{ sec }}</div>
          <ul class="sq-nav">
            <template v-for="item in menu.filter((m) => m.section === sec && (m.show ?? true))" :key="item.to">
              <li>
                <router-link :to="item.to" class="sq-nav-item" :class="{ active: isActive(item.to) }" @click="ui.closeMobileSidebar()">
                  <component :is="item.icon" :size="18" />
                  <span class="sq-nav-label">{{ item.label }}</span>
                </router-link>
              </li>
            </template>
          </ul>
          </template>
        </template>
      </nav>
      <div class="sq-sidebar-version sq-muted" style="margin-top:auto;padding:.9rem 1.15rem;font-size:.72rem;border-top:1px solid var(--sq-border)">
        v{{ APP_VERSION }}
      </div>
    </aside>

    <div class="sq-main">
      <header class="sq-navbar">
        <button class="sq-icon-btn d-none d-lg-grid" @click="ui.toggleSidebar()" title="Recolher menu">
          <IconMenu2 :size="20" />
        </button>
        <button class="sq-icon-btn d-lg-none" @click="ui.toggleMobileSidebar()" title="Abrir menu">
          <IconMenu2 :size="20" />
        </button>

        <!-- Organização ativa -->
        <select v-if="organizations.length" v-model="orgId" class="form-select" style="max-width:220px;background:var(--sq-bg);border-color:var(--sq-border);color:var(--sq-text);font-size:.875rem" @change="setOrganization(orgId)">
          <option v-for="o in organizations" :key="o.id" :value="o.id">{{ o.name }}</option>
        </select>

        <!-- Pesquisa global -->
        <div v-if="contextLabel==='Qualidade'" class="sq-search">
          <IconSearch :size="16" />
          <input v-model="globalSearch" placeholder="Pesquisar auditorias, NC/OM e ações…" aria-label="Pesquisa global" @keyup.enter="router.push({path:'/pesquisa',query:{q:globalSearch}})" />
        </div>

        <div class="ms-auto d-flex align-items-center gap-1">
          <!-- Dark mode -->
          <button class="sq-icon-btn" @click="cycleTheme" :title="'Tema: ' + ui.theme">
            <IconSun v-if="ui.theme === 'light'" :size="19" />
            <IconMoon v-else-if="ui.theme === 'dark'" :size="19" />
            <IconMoonStars v-else :size="19" />
          </button>

          <!-- Notificações -->
          <div class="dropdown">
            <button class="sq-icon-btn" data-bs-toggle="dropdown" data-bs-auto-close="outside" aria-expanded="false">
              <IconBell :size="19" />
              <span v-if="unread" class="sq-dot">{{ unread }}</span>
            </button>
            <div class="dropdown-menu dropdown-menu-end shadow" style="width:340px">
              <div class="d-flex justify-content-between align-items-center px-3 py-2 border-bottom">
                <strong class="sq-heading">{{ unread }} não lidas</strong>
                <button class="btn btn-sm btn-link" @click="markAllRead">Marcar todas como lidas</button>
              </div>
              <div style="max-height:320px;overflow:auto">
                <div v-for="n in notifications" :key="n.id" class="px-3 py-2 border-bottom d-flex gap-2 align-items-start"
                     :class="{ 'bg-primary-subtle': !n.read }" style="cursor:pointer" @click="markRead(n.id); n.link &amp;&amp; router.push(n.link)">
                  <span class="sq-avatar" :style="{ background: 'rgba(115,103,240,.12)' }">
                    <IconBell :size="14" />
                  </span>
                  <div class="flex-grow-1">
                    <div class="fw-semibold" :style="{ color: 'var(--sq-heading)' }">{{ n.title }}</div>
                    <div class="sq-muted" style="font-size:.8rem">{{ n.message }}</div>
                    <div class="sq-muted" style="font-size:.72rem">{{ formatDateTime(n.created_at) }}</div>
                  </div>
                  <IconCheck v-if="n.read" :size="16" class="sq-muted" />
                </div>
                <div v-if="!notifications.length" class="px-3 py-4 text-center sq-muted">Sem notificações</div>
              </div>
            </div>
          </div>

          <!-- Utilizador -->
          <div class="dropdown">
            <button class="btn d-flex align-items-center gap-2 border-0" data-bs-toggle="dropdown"
                    style="background:transparent;padding:.35rem .5rem" data-bs-auto-close="outside">
              <span class="sq-avatar">{{ initials }}</span>
              <span class="d-none d-md-block text-start">
                <span class="d-block fw-semibold" style="color:var(--sq-heading);font-size:.85rem;line-height:1.1">{{ auth.fullName }}</span>
                <span class="d-block sq-muted" style="font-size:.72rem">{{ auth.role }}</span>
              </span>
              <IconChevronDown :size="14" class="sq-muted" />
            </button>
            <div class="dropdown-menu dropdown-menu-end shadow">
              <router-link to="/perfil" class="dropdown-item d-flex align-items-center gap-2">
                <IconUserCircle :size="16" /> Perfil
              </router-link>
              <div class="dropdown-divider"></div>
              <button class="dropdown-item text-danger d-flex align-items-center gap-2" @click="logout">
                <IconLogout :size="16" /> Terminar sessão
              </button>
            </div>
          </div>
        </div>
      </header>

      <main class="sq-content" :data-context="contextLabel"><section class="sq-context-banner mb-4" aria-label="Contexto atual"><span class="sq-context-mark" aria-hidden="true"></span><div><strong>{{contextLabel}}</strong><p class="mb-0">{{contextDescription}}</p></div></section><div v-if="brandError" class="alert alert-warning" role="alert">{{brandError}}</div>
        <router-view :key="activeOrganization?.id" />
      </main>
    </div>
  </div>
</template>
