import { moduleForPath } from '@/domain/module-access'
import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { isSupabaseConfigured } from '@/lib/supabase'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/pages/LoginPage.vue'),
      meta: { public: true, layout: 'auth', title: 'Entrar' },
    },
    {
      path: '/recuperar-password',
      name: 'recover',
      component: () => import('@/pages/RecoverPasswordPage.vue'),
      meta: { public: true, layout: 'auth', title: 'Recuperar password' },
    },
    {path:'/reset-password',name:'reset-password',component:()=>import('@/pages/ResetPasswordPage.vue'),meta:{public:true,layout:'auth',title:'Definir nova senha'}},
    {
      path: '/',
      component: () => import('@/layouts/AppLayout.vue'),
      children: [
        { path: '', redirect: '/dashboard' },
        { path: 'dashboard', name: 'dashboard', component: () => import('@/pages/QualityWorkspacePage.vue'), meta: { title: 'Dashboard', qualityView:'dashboard' } },
        {path:'auditorias',component:()=>import('@/pages/QualityWorkspacePage.vue'),meta:{title:'Auditorias',qualityView:'audits'}},
{path:'auditorias/:id',component:()=>import('@/pages/QualityWorkspacePage.vue'),meta:{title:'Auditoria',qualityView:'audit'}},
{path:'meu-trabalho',component:()=>import('@/pages/QualityWorkspacePage.vue'),meta:{title:'O meu trabalho',qualityView:'work'}},
{path:'pesquisa',component:()=>import('@/pages/QualityWorkspacePage.vue'),meta:{title:'Pesquisa global',qualityView:'search'}},
{path:'notificacoes',component:()=>import('@/pages/QualityWorkspacePage.vue'),meta:{title:'Notificações',qualityView:'notifications'}},
{path:'qualidade/configuracao',component:()=>import('@/pages/QualityWorkspacePage.vue'),meta:{title:'Configuração',qualityView:'settings'}},
{path:'qualidade/acoes',component:()=>import('@/pages/QualityWorkspacePage.vue'),meta:{title:'Ações',qualityView:'actions'}},
        { path: 'ocorrencias', name: 'occurrences', component: () => import('@/pages/OccurrencesPage.vue'), meta: { title: 'NC / OM' } },
        { path: 'ocorrencias/nova', name: 'occurrence-new', component: () => import('@/pages/QualityWorkspacePage.vue'), meta: { title: 'Nova ocorrência', qualityView:'new', requiresManage: true } },
        { path: 'ocorrencias/:id', name: 'occurrence-detail', component: () => import('@/pages/QualityWorkspacePage.vue'), meta: { title: 'Ocorrência', qualityView:'record' } },
        { path: 'acoes', name: 'actions', component: () => import('@/pages/QualityWorkspacePage.vue'), meta: { title: 'Ações', qualityView:'actions' } },
        { path: 'lifecycle-rh', name: 'lifecycle-rh', component: () => import('@/pages/LifecycleRhsPage.vue'), meta: { title: 'LifeCycle RH', requiresManage: true } },
        { path: 'eficacia', name: 'effectiveness', redirect: '/pesquisa?filter=AWAITING_EFFECTIVENESS', meta: { title: 'Eficácia', requiresManage: true } },
        { path: 'relatorios', name: 'reports', component: () => import('@/pages/ReportsPage.vue'), meta: { title: 'Relatórios' } },
        { path: 'assistente-ia', name: 'ai-assistant', component: () => import('@/pages/AiAssistantPage.vue'), meta: { title: 'Assistente IA', requiresManage: true } },
        { path: 'revisao-gestao', name: 'management-review', component: () => import('@/pages/ManagementReviewPage.vue'), meta: { title: 'Revisão pela Gestão' } },
        // Plataforma Estratégica v1.5
        {
          path: 'estrategia',
          name: 'strategy',
          component: () => import('@/pages/strategy/StrategySwotPage.vue'),
          meta: { title: 'Estratégia', requiresManage: true },
        },
        { path: 'estrategia/swot', name: 'strategy-swot', component: () => import('@/pages/strategy/StrategySwotPage.vue'), meta: { title: 'SWOT', requiresManage: true } },
        { path: 'estrategia/campanhas', name: 'strategy-campaigns', component: () => import('@/pages/strategy/StrategyCampaignsPage.vue'), meta: { title: 'Campanhas SWOT' } },
        { path: 'estrategia/tows', name: 'strategy-tows', component: () => import('@/pages/strategy/StrategyTowsPage.vue'), meta: { title: 'TOWS', requiresManage: true } },
        { path: 'estrategia/riscos', name: 'strategy-risks', component: () => import('@/pages/strategy/StrategyRisksPage.vue'), meta: { title: 'Riscos e Oportunidades', requiresManage: true } },
        { path: 'estrategia/plano', name: 'strategy-plan', component: () => import('@/pages/strategy/StrategyPlanPage.vue'), meta: { title: 'Plano Estratégico', requiresManage: true } },
        { path: 'estrategia/kpis', name: 'strategy-kpis', component: () => import('@/pages/strategy/StrategyKpiPage.vue'), meta: { title: 'KPIs', requiresManage: true } },
        { path: 'estrategia/decisoes', name: 'strategy-decisions', component: () => import('@/pages/strategy/StrategyDecisionsPage.vue'), meta: { title: 'Decisões', requiresManage: true } },
        { path: 'reunioes', name: 'meetings', component: () => import('@/pages/strategy/MeetingsPage.vue'), meta: { title: 'Reuniões', requiresManage: true } },
        { path: 'apresentacoes', name: 'presentations', component: () => import('@/pages/strategy/PresentationsPage.vue'), meta: { title: 'Apresentações', requiresManage: true } },
        // Admin v1.5
        { path: 'administracao/organizacoes', name: 'admin-organizations', component: () => import('@/pages/admin/AdminOrganizationsPage.vue'), meta: { title: 'Organizações', requiresAdmin: true } },
        { path: 'administracao/brand-kits', name: 'admin-brand-kits', component: () => import('@/pages/admin/AdminBrandKitsPage.vue'), meta: { title: 'Brand Kits', requiresAdmin: true } },
        { path: 'administracao/frameworks', name: 'admin-frameworks', component: () => import('@/pages/admin/AdminFrameworksPage.vue'), meta: { title: 'Frameworks', requiresAdmin: true } },
        { path: 'administracao/templates-ppt', name: 'admin-ppt-templates', component: () => import('@/pages/admin/AdminPptTemplatesPage.vue'), meta: { title: 'Templates PPT', requiresAdmin: true } },
        { path: 'administracao/conectores', name: 'admin-connectors', component: () => import('@/pages/admin/AdminConnectorsPage.vue'), meta: { title: 'Conectores', requiresAdmin: true } },
        { path: 'administracao', name: 'admin', component: () => import('@/pages/AdminPage.vue'), meta: { title: 'Administração', requiresAdmin: true } },
        { path: 'perfil', name: 'profile', component: () => import('@/pages/ProfilePage.vue'), meta: { title: 'Perfil' } },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/dashboard' },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (!auth.initialized) await auth.init()

  // Sem Supabase configurado: permitir ver a app em modo demonstração (só login/erro)
  if (!isSupabaseConfigured && to.name !== 'login') {
    return { name: 'login' }
  }

  if (to.meta.public) {
    if (auth.isAuthenticated && to.name === 'login') return { name: 'dashboard' }
    return true
  }

  if (!auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  const home = auth.hasModule('quality') ? '/dashboard' : auth.hasModule('strategy') ? '/estrategia/campanhas' : auth.hasModule('lifecycle') && auth.canManageLifecycle ? '/lifecycle-rh' : '/perfil'
  const module = moduleForPath(to.path)
  if (module && !auth.hasModule(module)) return {path:home}

  if (to.meta.requiresAdmin && !auth.canAdminister) return { path: home }
  if (to.meta.requiresManage && !(module==='strategy'?auth.canManageStrategy:module==='lifecycle'?auth.canManageLifecycle:auth.canManage)) return { path: home }

  // LifeCycle RH oculto quando desativado nas configurações
  if (!auth.isGlobalAdmin && to.name === 'lifecycle-rh' && localStorage.getItem('samsys-qualidade:lifecycle-visivel') === 'desativado') {
    return { path: auth.hasModule('quality') ? '/dashboard' : '/perfil' }
  }

  // Plataforma Estratégica v1.5 oculta quando desativada
  const strategyNames = ['strategy','strategy-swot','strategy-tows','strategy-risks','strategy-plan','strategy-kpis','strategy-decisions','meetings','presentations']
  if (!auth.isGlobalAdmin && strategyNames.includes(String(to.name)) && localStorage.getItem('samsys-qualidade:strategy-visivel') === 'desativado') {
    return { path: auth.hasModule('quality') ? '/dashboard' : '/perfil' }
  }

  return true
})

router.afterEach((to) => {
  const title = (to.meta.title as string) || ''
  document.title = title ? `${title} · SAMSYS|Qualidade` : 'SAMSYS|Qualidade'
})

export default router
