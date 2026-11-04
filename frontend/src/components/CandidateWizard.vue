<script setup lang="ts">
import {datePT} from '@/domain/dates'
// CandidateWizard.vue — Ficha 360º do candidato em wizard (ecrã completo).
// Etapas: 1 Dados pessoais · 2 Contactos · 3 Perfil · 4 Experiência e formação ·
// 5 Competências, idiomas, certificações e projetos · 6 Pré-visualização.
// Gravação automática por etapa (upsert pessoa + CRUD dos registos repetíveis).
import { ref, computed, onMounted } from 'vue'
import {
  upsertPessoa, carregarCandidatoCompleto, criarFilho, atualizarFilho, removerFilho, updateCasoPessoa,
  type LifecyclePessoa, type LifecycleCandidato, type TabelaFilha,
} from '@/services/lifecycle'
import { IconCheck, IconUser, IconPhone, IconBriefcase, IconSchool, IconList, IconFileText, IconArrowLeft, IconArrowRight, IconDeviceFloppy, IconPlus, IconEye } from '@tabler/icons-vue'

const props = defineProps<{ casoId?: string | null; pessoaId?: string | null }>()
const emit = defineEmits<{ (e: 'close'): void; (e: 'saved', pessoa: LifecyclePessoa): void }>()

const passo = ref(1)
const PESSOAS = ref<LifecyclePessoa | null | undefined>(null)
const FILHOS = ref<LifecycleCandidato>({ experiencias: [], formacoes: [], competencias: [], idiomas: [], certificacoes: [], projetos: [], referencias: [] })
const carregando = ref(true)
const guardando = ref(false)
const msg = ref('')
const erro = ref('')
const preenchimento = computed(() => {
  let total = 0, preench = 0
  const f = PESSOAS.value
  const campos: (string | number | undefined | null)[] = [f?.nome_completo, f?.nome_preferido, f?.email, f?.telefone, f?.linkedin, f?.github, f?.titulo_atual, f?.empresa_atual, f?.resumo_gerado_ia, f?.anos_experiencia]
  total = campos.length
  preench = campos.filter((x) => x && String(x).trim()).length
  const totaisFilhos = (FILHOS.value.experiencias?.length || 0) + (FILHOS.value.formacoes?.length || 0) + (FILHOS.value.competencias?.length || 0) + (FILHOS.value.idiomas?.length || 0) + (FILHOS.value.certificacoes?.length || 0) + (FILHOS.value.projetos?.length || 0)
  return Math.min(100, Math.round((preench / total + totaisFilhos / (totaisFilhos + 15)) * 50))
})
const ETAPAS = [
  { n: 1, icon: IconUser, nome: 'Dados pessoais' },
  { n: 2, icon: IconPhone, nome: 'Contactos' },
  { n: 3, icon: IconBriefcase, nome: 'Perfil profissional' },
  { n: 4, icon: IconSchool, nome: 'Experiência e formação' },
  { n: 5, icon: IconList, nome: 'Competências e mais' },
  { n: 6, icon: IconEye, nome: 'Pré-visualização' },
]

// ---- formulário (dados da pessoa) ----
const f = ref<Record<string, any>>({ // eslint-disable-line @typescript-eslint/no-explicit-any
  id: '', nome_completo: '', nome_preferido: '', email: '', email_alternativo: '', telefone: '', telefone_alternativo: '',
  linkedin: '', github: '', portfolio: '', website: '', resumo_original: '', resumo_gerado_ia: '',
  anos_experiencia: null, titulo_atual: '', empresa_atual: '', area: '', senioridade: '', disponibilidade_inicio: '',
  regime: '', competencias_principais: [] as string[], areas_experiencia: [] as string[],
  // campos 360º adicionais
  data_nascimento: '', nacionalidade: '', pais_residencia: '', distrito: '', concelho: '', localidade: '', codigo_postal: '', morada: '',
  area_profissional: '', situacao_atual: '', prazo_pre_aviso: '', tipo_vinculo_pretendido: '', disponibilidade_geo: '', disponibilidade_desloc: '',
  disponibilidade_viagem: '', disponibilidade_mudar: '', carta_conducao: '', viatura_propria: '', autorizado_trabalhar_pt: '',
  objetivos_profissionais: '', setores: [] as string[], pontos_fortes: [] as string[], funcoes_pretendidas: [] as string[],
  areas_pretendidas: [] as string[], expectativa_salarial: null, moeda: '', periodicidade_salarial: '', beneficios: '', horario: '',
  regime_pretendido: '', localizacao_pretendida: '', contrato_pretendido: '', notas_internas: '', info_em_falta: '',
})
// vista anonimizada (RGPD: esconde identificadores na pré-visualização)
const anonimo = ref(false)

async function carregar() {
  carregando.value = true
  try {
    if (props.pessoaId) {
      const c = await carregarCandidatoCompleto(props.pessoaId)
      PESSOAS.value = c.pessoa
      FILHOS.value = c
      if (c.pessoa) {
        const p = c.pessoa
        f.value = {
          id: p.id, nome_completo: p.nome_completo || '', nome_preferido: p.nome_preferido || '',
          email: p.email || '', email_alternativo: (p as any).email_alternativo || '', telefone: p.telefone || '',
          telefone_alternativo: (p as any).telefone_alternativo || '', linkedin: p.linkedin || '', github: p.github || '',
          portfolio: p.portfolio || '', website: (p as any).website || '', resumo_original: p.resumo_original || '',
          resumo_gerado_ia: p.resumo_gerado_ia || '', anos_experiencia: p.anos_experiencia ?? null,
          titulo_atual: p.titulo_atual || '', empresa_atual: p.empresa_atual || '', area: (p as any).area_profissional || '',
          senioridade: (p as any).senioridade || '', disponibilidade_inicio: p.disponibilidade_inicio || '',
          regime: p.regime || '',
          competencias_principais: Array.isArray(p.competencias_principais) ? p.competencias_principais : [],
          areas_experiencia: Array.isArray(p.areas_experiencia) ? p.areas_experiencia : [],
          data_nascimento: (p as any).data_nascimento || '', nacionalidade: (p as any).nacionalidade || '',
          pais_residencia: (p as any).pais_residencia || '', distrito: (p as any).distrito || '', concelho: (p as any).concelho || '',
          localidade: (p as any).localidade || '', codigo_postal: (p as any).codigo_postal || '', morada: (p as any).morada || '',
          area_profissional: (p as any).area_profissional || '', situacao_atual: (p as any).situacao_atual || '',
          prazo_pre_aviso: (p as any).prazo_pre_aviso || '', tipo_vinculo_pretendido: (p as any).tipo_vinculo_pretendido || '',
          disponibilidade_geo: (p as any).disponibilidade_geo || '', disponibilidade_desloc: (p as any).disponibilidade_desloc || '',
          disponibilidade_viagem: (p as any).disponibilidade_viagem || '', disponibilidade_mudar: (p as any).disponibilidade_mudar || '',
          carta_conducao: (p as any).carta_conducao || '', viatura_propria: (p as any).viatura_propria || '',
          autorizado_trabalhar_pt: (p as any).autorizado_trabalhar_pt || '',
          objetivos_profissionais: (p as any).objetivos_profissionais || '', setores: Array.isArray((p as any).setores) ? (p as any).setores : [],
          pontos_fortes: Array.isArray((p as any).pontos_fortes) ? (p as any).pontos_fortes : [],
          funcoes_pretendidas: Array.isArray((p as any).funcoes_pretendidas) ? (p as any).funcoes_pretendidas : [],
          areas_pretendidas: Array.isArray((p as any).areas_pretendidas) ? (p as any).areas_pretendidas : [],
          expectativa_salarial: (p as any).expectativa_salarial ?? null, moeda: (p as any).moeda || '',
          periodicidade_salarial: (p as any).periodicidade_salarial || '', beneficios: (p as any).beneficios || '',
          horario: (p as any).horario || '', regime_pretendido: (p as any).regime_pretendido || '',
          localizacao_pretendida: (p as any).localizacao_pretendida || '', contrato_pretendido: (p as any).contrato_pretendido || '',
          notas_internas: (p as any).notas_internas || '', info_em_falta: (p as any).info_em_falta || '',
        }
      }
    }
  } catch (e) { erro.value = (e as Error).message }
  carregando.value = false
}

// ---- gravação automática ----
async function guardarPessoa(): Promise<LifecyclePessoa | null> {
  try {
    const payload: Partial<LifecyclePessoa> & Record<string, unknown> = {
      id: f.value.id || undefined,
      nome_completo: f.value.nome_completo.trim(),
      nome_preferido: f.value.nome_preferido || null,
      email: f.value.email || null, telefone: f.value.telefone || null,
      email_alternativo: f.value.email_alternativo || null, telefone_alternativo: f.value.telefone_alternativo || null,
      linkedin: f.value.linkedin || null, github: f.value.github || null, portfolio: f.value.portfolio || null, website: f.value.website || null,
      resumo_original: f.value.resumo_original || null, resumo_gerado_ia: f.value.resumo_gerado_ia || null,
      competencias_principais: f.value.competencias_principais?.length ? f.value.competencias_principais : [],
      areas_experiencia: f.value.areas_experiencia?.length ? f.value.areas_experiencia : [],
      anos_experiencia: f.value.anos_experiencia ?? null,
      titulo_atual: f.value.titulo_atual || null, empresa_atual: f.value.empresa_atual || null,
      disponibilidade_inicio: f.value.disponibilidade_inicio || null, regime: f.value.regime || null,
      data_nascimento: f.value.data_nascimento || null, nacionalidade: f.value.nacionalidade || null,
      pais_residencia: f.value.pais_residencia || null, distrito: f.value.distrito || null, concelho: f.value.concelho || null,
      localidade: f.value.localidade || null, codigo_postal: f.value.codigo_postal || null, morada: f.value.morada || null,
      area_profissional: f.value.area_profissional || null, senioridade: f.value.senioridade || null,
      situacao_atual: f.value.situacao_atual || null, prazo_pre_aviso: f.value.prazo_pre_aviso || null,
      tipo_vinculo_pretendido: f.value.tipo_vinculo_pretendido || null,
      disponibilidade_geo: f.value.disponibilidade_geo || null, disponibilidade_desloc: f.value.disponibilidade_desloc || null,
      disponibilidade_viagem: f.value.disponibilidade_viagem || null, disponibilidade_mudar: f.value.disponibilidade_mudar || null,
      carta_conducao: f.value.carta_conducao || null, viatura_propria: f.value.viatura_propria || null,
      autorizado_trabalhar_pt: f.value.autorizado_trabalhar_pt || null,
      objetivos_profissionais: f.value.objetivos_profissionais || null,
      setores: f.value.setores?.length ? f.value.setores : [], pontos_fortes: f.value.pontos_fortes?.length ? f.value.pontos_fortes : [],
      funcoes_pretendidas: f.value.funcoes_pretendidas?.length ? f.value.funcoes_pretendidas : [],
      areas_pretendidas: f.value.areas_pretendidas?.length ? f.value.areas_pretendidas : [],
      expectativa_salarial: f.value.expectativa_salarial ?? null, moeda: f.value.moeda || null,
      periodicidade_salarial: f.value.periodicidade_salarial || null, beneficios: f.value.beneficios || null,
      horario: f.value.horario || null, regime_pretendido: f.value.regime_pretendido || null,
      localizacao_pretendida: f.value.localizacao_pretendida || null, contrato_pretendido: f.value.contrato_pretendido || null,
      notas_internas: f.value.notas_internas || null, info_em_falta: f.value.info_em_falta || null,
    }
    const pessoa = await upsertPessoa(payload)
    if (props.casoId) await updateCasoPessoa(props.casoId, pessoa.id)
    f.value.id = pessoa.id
    PESSOAS.value = pessoa
    return pessoa
  } catch (e) { erro.value = (e as Error).message; return null }
}
// CRUD genérico para registos repetíveis
const editando = ref<Record<string, { tabela: TabelaFilha; id: string | null; campos: Record<string, any> } | null>>({}) // eslint-disable-line @typescript-eslint/no-explicit-any
function novoRegisto(tabela: TabelaFilha) { editando.value = { ...editando.value, [tabela]: { tabela, id: null, campos: {} } } }
function editarRegisto(tabela: TabelaFilha, reg: Record<string, any>) { // eslint-disable-line @typescript-eslint/no-explicit-any
  const { id, pessoa_id, created_at, updated_at, ...campos } = reg
  editando.value = { ...editando.value, [tabela]: { tabela, id, campos: { ...campos } } }
}
async function guardarRegisto(tabela: TabelaFilha) {
  if (!f.value.id) { const p = await guardarPessoa(); if (!p) return }
  const ed = editando.value[tabela]
  if (!ed) return
  try {
    if (ed.id) await atualizarFilho(tabela, ed.id, ed.campos)
    else await criarFilho(tabela, f.value.id, ed.campos)
    editando.value = { ...editando.value, [tabela]: null }
    FILHOS.value = { ...FILHOS.value, [tabela]: await listarFilhosLocal(tabela) }
  } catch (e) { erro.value = (e as Error).message }
}
async function removerRegisto(tabela: TabelaFilha, id: string) {
  await removerFilho(tabela, id)
  FILHOS.value = { ...FILHOS.value, [tabela]: await listarFilhosLocal(tabela) }
}
async function listarFilhosLocal(tabela: TabelaFilha) {
  const { listarFilhos } = await import('@/services/lifecycle')
  return listarFilhos(tabela, f.value.id)
}
function setCampoFilho(tabela: TabelaFilha, chave: string, valor: unknown) {
  const ed = editando.value[tabela]
  if (!ed) return
  ed.campos = { ...ed.campos, [chave]: valor }
  editando.value = { ...editando.value, [tabela]: ed }
}
// competências como etiquetas
function addTag(lista: string[], v: string) { if (v.trim()) lista.push(v.trim().replace(/,/g, '')) }
function rmTag(lista: string[], i: number) { if (i >= 0 && i < lista.length) lista.splice(i, 1) }

async function avancar() {
  if (guardando.value) return
  guardando.value = true; msg.value = ''
  if (passo.value < 6) {
    await guardarPessoa()
    msg.value = 'Gravado automaticamente.'
  }
  passo.value++
  guardando.value = false
}
async function voltar() { if (passo.value > 1) passo.value-- }
async function concluir() {
  guardando.value = true; msg.value = ''
  await guardarPessoa()
  const pessoa = PESSOAS.value
  if (pessoa) { msg.value = 'Ficha 360º concluída e gravada.'; emit('saved', pessoa) }
  guardando.value = false
}
onMounted(carregar)
</script>

<template>
  <div class="wiz-overlay">
    <div class="wiz-card">
      <!-- cabeçalho: foto, nome, estado, progresso -->
      <div class="wiz-head">
        <div class="d-flex align-items-center gap-3 flex-wrap">
          <div class="wiz-avatar">{{ (f.nome_completo || '?').slice(0, 2).toUpperCase() }}</div>
          <div>
            <div class="fw-semibold" style="font-size:1.05rem">{{ f.nome_completo || 'Novo candidato' }}</div>
            <div class="sq-muted" style="font-size:.78rem">
              {{ f.titulo_atual || '—' }} · {{ PESSOAS?.estados_ficha || 'Por validar' }}
              <span v-if="PESSOAS?.id" class="sq-badge badge-soft-secondary ms-1" style="font-size:.7rem">Importado por IA / editável</span>
            </div>
          </div>
          <div class="ms-auto d-flex align-items-center gap-2">
            <span class="sq-muted" style="font-size:.75rem">Preenchimento</span>
            <div class="progress" style="width:110px;height:8px"><div class="progress-bar" :style="{ width: preenchimento + '%', background: '#7367f0' }"></div></div>
            <span class="fw-semibold" style="font-size:.8rem;color:#7367f0">{{ preenchimento }}%</span>
          </div>
          <button class="btn btn-sm btn-close" @click="emit('close')"></button>
        </div>
        <div class="d-flex gap-2 mt-2 flex-wrap">
          <button class="btn btn-sm btn-outline-primary d-inline-flex align-items-center gap-1" @click="guardarPessoa()" :disabled="guardando"><IconDeviceFloppy :size="14" /> Guardar rascunho</button>
          <button class="btn btn-sm btn-success d-inline-flex align-items-center gap-1" @click="concluir" :disabled="guardando"><IconCheck :size="14" /> Concluir</button>
        </div>
      </div>

      <!-- etapas -->
      <div class="d-flex gap-1 flex-wrap px-3 pt-2">
        <button v-for="e in ETAPAS" :key="e.n" class="btn btn-sm wiz-etapa" :class="passo===e.n ? 'wiz-etapa-ativa' : 'wiz-etapa-inativa'" @click="passo=e.n">
          <component :is="e.icon" :size="13" class="me-1" /> {{ e.n }}. {{ e.nome }}
        </button>
      </div>

      <div v-if="erro" class="alert alert-danger py-2 mx-3 mt-2" style="font-size:.8rem">{{ erro }}</div>
      <div v-if="msg" class="alert alert-success py-2 mx-3 mt-2" style="font-size:.78rem;background:#d7f5e3;border:0">{{ msg }}</div>

      <div class="wiz-body" v-if="!carregando">
        <!-- 1 dados pessoais -->
        <div v-if="passo===1" class="row g-2 p-3">
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Nome completo *</label><input v-model="f.nome_completo" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Nome preferido</label><input v-model="f.nome_preferido" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Data de nascimento</label><PtDateInput v-model="f.data_nascimento" type="date" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Nacionalidade</label><input v-model="f.nacionalidade" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-4"><label class="form-label small sq-muted mb-0">País de residência</label><input v-model="f.pais_residencia" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Distrito</label><input v-model="f.distrito" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Concelho</label><input v-model="f.concelho" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Localidade</label><input v-model="f.localidade" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-3"><label class="form-label small sq-muted mb-0">Código postal</label><input v-model="f.codigo_postal" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-9"><label class="form-label small sq-muted mb-0">Morada</label><input v-model="f.morada" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Área / especialidade</label><input v-model="f.area_profissional" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Senioridade</label><select v-model="f.senioridade" class="form-select form-select-sm"><option value="">—</option><option>Estágio</option><option>Junior</option><option>Pleno</option><option>Sénior</option><option>Lead</option><option>Direção</option></select></div>
          <div class="col-12 col-md-4"><label class="form-label small sq-muted mb-0">Situação atual</label><input v-model="f.situacao_atual" class="form-control form-control-sm" placeholder="ex.: empregado, em transição…" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Empresa atual</label><input v-model="f.empresa_atual" class="form-control form-control-sm" /></div>
          <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Título atual</label><input v-model="f.titulo_atual" class="form-control form-control-sm" /></div>
          <div class="col-4 col-md-2"><label class="form-label small sq-muted mb-0">Anos experiência</label><input v-model.number="f.anos_experiencia" type="number" class="form-control form-control-sm" /></div>
          <div class="col-4 col-md-2"><label class="form-label small sq-muted mb-0">Disponibilidade</label><input v-model="f.disponibilidade_inicio" class="form-control form-control-sm" /></div>
          <div class="col-4 col-md-2"><label class="form-label small sq-muted mb-0">Pré-aviso</label><input v-model="f.prazo_pre_aviso" class="form-control form-control-sm" placeholder="ex.: 30 dias" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Regime</label><select v-model="f.regime" class="form-select form-select-sm"><option value="">—</option><option>Presencial</option><option>Híbrido</option><option>Remoto</option></select></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Tipo de vínculo pretendido</label><select v-model="f.tipo_vinculo_pretendido" class="form-select form-select-sm"><option value="">—</option><option>Full-time</option><option>Part-time</option><option>Estágio</option><option>Freelancer</option><option>Comissão de serviço</option></select></div>
          <div class="col-12">
            <div class="d-flex gap-3 flex-wrap" style="font-size:.8rem">
              <label class="form-check"><input type="checkbox" class="form-check-input" v-model="f.autorizado_trabalhar_pt" /> <span class="form-check-label">Autorizado a trabalhar em PT</span></label>
              <label class="form-check"><input type="checkbox" class="form-check-input" v-model="f.carta_conducao" /> <span class="form-check-label">Carta de condução</span></label>
              <label class="form-check"><input type="checkbox" class="form-check-input" v-model="f.viatura_propria" /> <span class="form-check-label">Viatura própria</span></label>
              <label class="form-check"><input type="checkbox" class="form-check-input" v-model="f.disponibilidade_geo" /> <span class="form-check-label">Dispon. geográfica</span></label>
              <label class="form-check"><input type="checkbox" class="form-check-input" v-model="f.disponibilidade_desloc" /> <span class="form-check-label">Dispon. deslocações</span></label>
              <label class="form-check"><input type="checkbox" class="form-check-input" v-model="f.disponibilidade_viagem" /> <span class="form-check-label">Dispon. viagens</span></label>
              <label class="form-check"><input type="checkbox" class="form-check-input" v-model="f.disponibilidade_mudar" /> <span class="form-check-label">Dispon. mudar de cidade</span></label>
            </div>
          </div>
        </div>

        <!-- 2 contactos -->
        <div v-if="passo===2" class="row g-2 p-3">
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Email</label><input v-model="f.email" type="email" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Email alternativo</label><input v-model="f.email_alternativo" type="email" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Telemóvel</label><input v-model="f.telefone" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Telefone alternativo</label><input v-model="f.telefone_alternativo" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">LinkedIn</label><input v-model="f.linkedin" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">GitHub</label><input v-model="f.github" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Portefólio</label><input v-model="f.portfolio" class="form-control form-control-sm" /></div>
          <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Website</label><input v-model="f.website" class="form-control form-control-sm" /></div>
        </div>

        <!-- 3 perfil profissional -->
        <div v-if="passo===3" class="row g-2 p-3">
          <div class="col-12"><label class="form-label small sq-muted mb-0">Resumo (gerado por IA, editável)</label>
            <textarea v-model="f.resumo_gerado_ia" rows="3" class="form-control form-control-sm"></textarea></div>
          <div class="col-12"><label class="form-label small sq-muted mb-0">Resumo original (do CV)</label>
            <textarea v-model="f.resumo_original" rows="2" class="form-control form-control-sm"></textarea></div>
          <div class="col-12"><label class="form-label small sq-muted mb-0">Competências principais</label>
            <div class="d-flex gap-1 flex-wrap align-items-center">
              <span v-for="(s,i) in (f.competencias_principais as string[])" :key="i" class="sq-badge badge-soft-primary d-inline-flex align-items-center gap-1" style="font-size:.78rem">{{ s }} <button type="button" class="btn-close" style="font-size:.45rem" @click="rmTag((f.competencias_principais as string[]), Number(i))"></button></span>
              <input class="form-control form-control-sm" style="max-width:180px" placeholder="Adicionar…" @keyup.enter="addTag((f.competencias_principais as string[]), ($event.target as HTMLInputElement).value); ($event.target as HTMLInputElement).value=''" />
            </div></div>
          <div class="col-12"><label class="form-label small sq-muted mb-0">Áreas de experiência</label>
            <div class="d-flex gap-1 flex-wrap align-items-center">
              <span v-for="(s,i) in (f.areas_experiencia as string[])" :key="i" class="sq-badge badge-soft-secondary d-inline-flex align-items-center gap-1" style="font-size:.78rem">{{ s }} <button type="button" class="btn-close" style="font-size:.45rem" @click="rmTag((f.areas_experiencia as string[]), Number(i))"></button></span>
              <input class="form-control form-control-sm" style="max-width:180px" placeholder="Adicionar…" @keyup.enter="addTag((f.areas_experiencia as string[]), ($event.target as HTMLInputElement).value); ($event.target as HTMLInputElement).value=''" />
            </div></div>
        </div>

        <!-- 4 experiência e formação -->
        <div v-if="passo===4" class="p-3">
          <span class="fw-semibold" style="font-size:.85rem">Experiência profissional</span>
          <div v-for="(ed, i) in (FILHOS.experiencias||[])" :key="i" class="border rounded p-2 mb-1 d-flex justify-content-between align-items-center" style="font-size:.8rem">
            <div><strong>{{ ed.cargo }}</strong> · {{ ed.empresa }}<div class="sq-muted" style="font-size:.72rem">{{ datePT(ed.data_inicio) }} — {{ ed.emprego_atual ? 'atual' : datePT(ed.data_fim) }}</div></div>
            <div class="d-flex gap-1"><button class="btn btn-sm btn-outline-secondary" @click="editarRegisto('lifecycle_experiencias', ed)">✎</button><button class="btn btn-sm btn-outline-danger" @click="removerRegisto('lifecycle_experiencias', ed.id as string)">🗑</button></div>
          </div>
          <button class="btn btn-sm btn-outline-primary mb-2" @click="novoRegisto('lifecycle_experiencias')"><IconPlus :size="13" /> Experiência</button>
          <div v-if="editando['lifecycle_experiencias']" class="border rounded p-2 mb-3" style="background:#fafafe">
            <div class="row g-2">
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Cargo" v-model="editando['lifecycle_experiencias']!.campos.cargo" /></div>
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Empresa" v-model="editando['lifecycle_experiencias']!.campos.empresa" /></div>
              <div class="col-6 col-md-2"><PtDateInput class="form-control form-control-sm"  v-model="editando['lifecycle_experiencias']!.campos.data_inicio" /></div>
              <div class="col-6 col-md-2"><PtDateInput class="form-control form-control-sm"  v-model="editando['lifecycle_experiencias']!.campos.data_fim" /></div>
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Tecnologias/ferramentas" v-model="editando['lifecycle_experiencias']!.campos.tecnologias" /></div>
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Setor" v-model="editando['lifecycle_experiencias']!.campos.setor" /></div>
              <div class="col-12"><textarea class="form-control form-control-sm" rows="2" placeholder="Descrição/responsabilidades" v-model="editando['lifecycle_experiencias']!.campos.descricao"></textarea></div>
              <div class="col-12 d-flex justify-content-end"><button class="btn btn-sm btn-success" @click="guardarRegisto('lifecycle_experiencias')">Guardar</button></div>
            </div>
          </div>
          <span class="fw-semibold" style="font-size:.85rem">Formação académica</span>
          <div v-for="(ed, i) in (FILHOS.formacoes||[])" :key="i" class="border rounded p-2 mb-1 d-flex justify-content-between align-items-center" style="font-size:.8rem">
            <div><strong>{{ ed.curso }}</strong> · {{ ed.instituicao }}<div class="sq-muted" style="font-size:.72rem">{{ ed.grau }} · {{ datePT(ed.data_inicio) }} — {{ ed.estado==='em_curso' ? 'em curso' : datePT(ed.data_conclusao) }}</div></div>
            <div class="d-flex gap-1"><button class="btn btn-sm btn-outline-secondary" @click="editarRegisto('lifecycle_formacoes', ed)">✎</button><button class="btn btn-sm btn-outline-danger" @click="removerRegisto('lifecycle_formacoes', ed.id as string)">🗑</button></div>
          </div>
          <button class="btn btn-sm btn-outline-primary" @click="novoRegisto('lifecycle_formacoes')"><IconPlus :size="13" /> Formação</button>
          <div v-if="editando['lifecycle_formacoes']" class="border rounded p-2 mt-2" style="background:#fafafe">
            <div class="row g-2">
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Curso" v-model="editando['lifecycle_formacoes']!.campos.curso" /></div>
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Instituição" v-model="editando['lifecycle_formacoes']!.campos.instituicao" /></div>
              <div class="col-6 col-md-2"><input class="form-control form-control-sm" placeholder="Grau" v-model="editando['lifecycle_formacoes']!.campos.grau" /></div>
              <div class="col-6 col-md-2"><input class="form-control form-control-sm" placeholder="Área" v-model="editando['lifecycle_formacoes']!.campos.area_estudo" /></div>
              <div class="col-6 col-md-4"><PtDateInput class="form-control form-control-sm"  v-model="editando['lifecycle_formacoes']!.campos.data_inicio" /></div>
              <div class="col-6 col-md-4"><PtDateInput class="form-control form-control-sm"  v-model="editando['lifecycle_formacoes']!.campos.data_conclusao" /></div>
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Classificação" v-model="editando['lifecycle_formacoes']!.campos.classificacao" /></div>
              <div class="col-12 d-flex justify-content-end"><button class="btn btn-sm btn-success" @click="guardarRegisto('lifecycle_formacoes')">Guardar</button></div>
            </div>
          </div>
        </div>

        <!-- 5 competências, idiomas, certificações, projetos -->
        <div v-if="passo===5" class="p-3">
          <span class="fw-semibold" style="font-size:.85rem">Competências</span>
          <div v-for="(ed, i) in (FILHOS.competencias||[])" :key="i" class="border rounded p-2 mb-1 d-flex justify-content-between align-items-center" style="font-size:.8rem">
            <div><strong>{{ ed.nome }}</strong> <span class="sq-badge badge-soft-primary" style="font-size:.7rem">{{ ed.categoria }}</span><div class="sq-muted" style="font-size:.72rem">Nível: {{ ed.nivel_indicado || '—' }} · {{ ed.anos_experiencia || 0 }} anos</div></div>
            <div class="d-flex gap-1"><button class="btn btn-sm btn-outline-secondary" @click="editarRegisto('lifecycle_competencias', ed)">✎</button><button class="btn btn-sm btn-outline-danger" @click="removerRegisto('lifecycle_competencias', ed.id as string)">🗑</button></div>
          </div>
          <button class="btn btn-sm btn-outline-primary mb-2" @click="novoRegisto('lifecycle_competencias')"><IconPlus :size="13" /> Competência</button>
          <div v-if="editando['lifecycle_competencias']" class="border rounded p-2 mb-3" style="background:#fafafe">
            <div class="row g-2">
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Nome" v-model="editando['lifecycle_competencias']!.campos.nome" /></div>
              <div class="col-6 col-md-4"><select class="form-select form-select-sm" v-model="editando['lifecycle_competencias']!.campos.categoria"><option value="">Categoria…</option><option>Técnica</option><option>Ferramenta</option><option>Linguagem</option><option>Gestão</option><option>Comportamental</option><option>Comercial</option><option>Outra</option></select></div>
              <div class="col-4 col-md-2"><input class="form-control form-control-sm" placeholder="Nível" v-model="editando['lifecycle_competencias']!.campos.nivel_indicado" /></div>
              <div class="col-4 col-md-2"><input class="form-control form-control-sm" placeholder="Anos" type="number" v-model.number="editando['lifecycle_competencias']!.campos.anos_experiencia" /></div>
              <div class="col-12 d-flex justify-content-end"><button class="btn btn-sm btn-success" @click="guardarRegisto('lifecycle_competencias')">Guardar</button></div>
            </div>
          </div>
          <span class="fw-semibold" style="font-size:.85rem">Idiomas</span>
          <div v-for="(ed, i) in (FILHOS.idiomas||[])" :key="i" class="border rounded p-2 mb-1 d-flex justify-content-between align-items-center" style="font-size:.8rem">
            <div><strong>{{ ed.idioma }}</strong> <span class="sq-badge badge-soft-secondary" style="font-size:.7rem">{{ ed.nivel_cefr || ed.nivel_global || '—' }}</span><span v-if="ed.lingua_materna" class="sq-badge badge-soft-primary ms-1" style="font-size:.7rem">materna</span></div>
            <div class="d-flex gap-1"><button class="btn btn-sm btn-outline-secondary" @click="editarRegisto('lifecycle_idiomas', ed)">✎</button><button class="btn btn-sm btn-outline-danger" @click="removerRegisto('lifecycle_idiomas', ed.id as string)">🗑</button></div>
          </div>
          <button class="btn btn-sm btn-outline-primary mb-2" @click="novoRegisto('lifecycle_idiomas')"><IconPlus :size="13" /> Idioma</button>
          <div v-if="editando['lifecycle_idiomas']" class="border rounded p-2 mb-3" style="background:#fafafe">
            <div class="row g-2">
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Idioma" v-model="editando['lifecycle_idiomas']!.campos.idioma" /></div>
              <div class="col-6 col-md-3"><select class="form-select form-select-sm" v-model="editando['lifecycle_idiomas']!.campos.nivel_cefr"><option value="">Nível CEFR…</option><option>A1</option><option>A2</option><option>B1</option><option>B2</option><option>C1</option><option>C2</option></select></div>
              <div class="col-6 col-md-3"><select class="form-select form-select-sm" v-model="editando['lifecycle_idiomas']!.campos.nivel_global"><option value="">Nível global…</option><option>Básico</option><option>Intermediário</option><option>Avançado</option><option>Fluente</option><option>Nativo</option></select></div>
              <div class="col-6 col-md-2 d-flex align-items-end"><label class="form-check"><input type="checkbox" class="form-check-input" v-model="editando['lifecycle_idiomas']!.campos.lingua_materna" /> <span class="form-check-label small">Materna</span></label></div>
              <div class="col-12 d-flex justify-content-end"><button class="btn btn-sm btn-success" @click="guardarRegisto('lifecycle_idiomas')">Guardar</button></div>
            </div>
          </div>
          <span class="fw-semibold" style="font-size:.85rem">Certificações e cursos</span>
          <div v-for="(ed, i) in (FILHOS.certificacoes||[])" :key="i" class="border rounded p-2 mb-1 d-flex justify-content-between align-items-center" style="font-size:.8rem">
            <div><strong>{{ ed.nome }}</strong> · {{ ed.entidade }}<div class="sq-muted" style="font-size:.72rem">{{ datePT(ed.data_emissao) }} · {{ ed.identificador || '' }}</div></div>
            <div class="d-flex gap-1"><button class="btn btn-sm btn-outline-secondary" @click="editarRegisto('lifecycle_certificacoes', ed)">✎</button><button class="btn btn-sm btn-outline-danger" @click="removerRegisto('lifecycle_certificacoes', ed.id as string)">🗑</button></div>
          </div>
          <button class="btn btn-sm btn-outline-primary mb-2" @click="novoRegisto('lifecycle_certificacoes')"><IconPlus :size="13" /> Certificação</button>
          <div v-if="editando['lifecycle_certificacoes']" class="border rounded p-2 mb-3" style="background:#fafafe">
            <div class="row g-2">
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Nome" v-model="editando['lifecycle_certificacoes']!.campos.nome" /></div>
              <div class="col-6 col-md-4"><input class="form-control form-control-sm" placeholder="Entidade" v-model="editando['lifecycle_certificacoes']!.campos.entidade" /></div>
              <div class="col-6 col-md-2"><PtDateInput class="form-control form-control-sm"  v-model="editando['lifecycle_certificacoes']!.campos.data_emissao" /></div>
              <div class="col-6 col-md-2"><input class="form-control form-control-sm" placeholder="ID credencial" v-model="editando['lifecycle_certificacoes']!.campos.identificador" /></div>
              <div class="col-12 d-flex justify-content-end"><button class="btn btn-sm btn-success" @click="guardarRegisto('lifecycle_certificacoes')">Guardar</button></div>
            </div>
          </div>
          <span class="fw-semibold" style="font-size:.85rem">Projetos</span>
          <div v-for="(ed, i) in (FILHOS.projetos||[])" :key="i" class="border rounded p-2 mb-1 d-flex justify-content-between align-items-center" style="font-size:.8rem">
            <div><strong>{{ ed.nome }}</strong> · {{ ed.papel }}<div class="sq-muted" style="font-size:.72rem">{{ ed.tecnologias || '' }} · {{ ed.data || '' }}</div></div>
            <div class="d-flex gap-1"><button class="btn btn-sm btn-outline-secondary" @click="editarRegisto('lifecycle_projetos', ed)">✎</button><button class="btn btn-sm btn-outline-danger" @click="removerRegisto('lifecycle_projetos', ed.id as string)">🗑</button></div>
          </div>
          <button class="btn btn-sm btn-outline-primary" @click="novoRegisto('lifecycle_projetos')"><IconPlus :size="13" /> Projeto</button>
          <span class="fw-semibold d-block mt-3" style="font-size:.85rem">Preferências e objetivo profissional</span>
          <div class="row g-2 mt-0">
            <div class="col-12"><label class="form-label small sq-muted mb-0">Objetivo profissional</label><textarea v-model="f.objetivos_profissionais" rows="2" class="form-control form-control-sm"></textarea></div>
            <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Funções pretendidas</label><input v-model="f.funcoes_pretendidas" class="form-control form-control-sm" placeholder="ex.: Developer, Tech Lead" @change="f.funcoes_pretendidas = f.funcoes_pretendidas.split(',').map((s:string)=>s.trim())" /></div>
            <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Áreas pretendidas</label><input v-model="f.areas_pretendidas" class="form-control form-control-sm" placeholder="ex.: Desenvolvimento" @change="f.areas_pretendidas = f.areas_pretendidas.split(',').map((s:string)=>s.trim())" /></div>
            <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Localizações pretendidas</label><input v-model="f.localizacao_pretendida" class="form-control form-control-sm" placeholder="ex.: Porto, Lisboa, remoto" /></div>
            <div class="col-4 col-md-3"><label class="form-label small sq-muted mb-0">Expectativa salarial 💰</label><input v-model.number="f.expectativa_salarial" type="number" class="form-control form-control-sm" /></div>
            <div class="col-4 col-md-2"><label class="form-label small sq-muted mb-0">Moeda</label><select v-model="f.moeda" class="form-select form-select-sm"><option value="">—</option><option>EUR</option><option>USD</option><option>GBP</option></select></div>
            <div class="col-4 col-md-3"><label class="form-label small sq-muted mb-0">Periodicidade</label><select v-model="f.periodicidade_salarial" class="form-select form-select-sm"><option value="">—</option><option>mensal</option><option>anual</option><option>hora</option></select></div>
            <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Benefícios valorizados</label><input v-model="f.beneficios" class="form-control form-control-sm" placeholder="ex.: seg. saúde, formação" /></div>
            <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Horário</label><input v-model="f.horario" class="form-control form-control-sm" placeholder="ex.: flexível" /></div>
            <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Regime pretendido</label><select v-model="f.regime_pretendido" class="form-select form-select-sm"><option value="">—</option><option>Presencial</option><option>Híbrido</option><option>Remoto</option></select></div>
            <div class="col-6 col-md-4"><label class="form-label small sq-muted mb-0">Contrato pretendido</label><select v-model="f.contrato_pretendido" class="form-select form-select-sm"><option value="">—</option><option>Efetivo</option><option>Contrato a termo</option><option>Freelance</option><option>Estágio</option></select></div>
            <div class="col-12"><label class="form-label small sq-muted mb-0">Notas internas (só com permissão)</label><textarea v-model="f.notas_internas" rows="2" class="form-control form-control-sm"></textarea></div>
            <div class="col-12"><label class="form-label small sq-muted mb-0">Informação em falta (da análise do CV)</label><textarea v-model="f.info_em_falta" rows="2" class="form-control form-control-sm"></textarea></div>
          </div>
        </div>

        <!-- 6 pré-visualização -->
        <div v-if="passo===6" class="p-3">
          <div class="d-flex justify-content-end mb-2">
            <label class="form-check form-switch">
              <input type="checkbox" class="form-check-input" v-model="anonimo" />
              <span class="form-check-label small sq-muted">Vista anonimizada (RGPD — oculta nome, contactos e salário)</span>
            </label>
          </div>
          <div class="border rounded p-3" style="background:#fff">
            <div class="d-flex align-items-center gap-3">
              <div class="wiz-avatar" style="width:64px;height:64px;font-size:1.3rem">{{ anonimo ? 'AN' : (f.nome_completo||'?').slice(0,2).toUpperCase() }}</div>
              <div>
                <div class="fw-semibold" style="font-size:1.1rem">{{ anonimo ? 'Candidato anonimizado' : f.nome_completo }}</div>
                <div class="sq-muted">{{ [f.titulo_atual, f.empresa_atual].filter(Boolean).join(' · ') }}</div>
                <div v-if="!anonimo" class="sq-muted" style="font-size:.78rem">{{ [f.email, f.telefone, f.linkedin, f.github].filter(Boolean).join(' · ') }}</div>
                <div v-if="anonimo" class="sq-muted" style="font-size:.78rem">sexo/idade/nacionalidade e contacto ocultos por RGPD · {{ f.area_profissional || '—' }}</div>
              </div>
            </div>
            <div v-if="f.resumo_gerado_ia" class="mt-2"><strong style="font-size:.8rem">Resumo</strong><p class="mb-1 sq-muted" style="font-size:.82rem">{{ f.resumo_gerado_ia }}</p></div>
            <div v-if="(FILHOS.experiencias||[]).length" class="mt-2"><strong style="font-size:.8rem">Experiência</strong>
              <p v-for="(x,i) in FILHOS.experiencias" :key="i" class="mb-1" style="font-size:.8rem">• <strong>{{ x.cargo }}</strong> — {{ x.empresa }} <span class="sq-muted">({{ datePT(x.data_inicio) }} — {{ x.emprego_atual?'atual':datePT(x.data_fim) }})</span></p></div>
            <div v-if="(FILHOS.formacoes||[]).length" class="mt-2"><strong style="font-size:.8rem">Formação</strong>
              <p v-for="(x,i) in FILHOS.formacoes" :key="i" class="mb-1" style="font-size:.8rem">• {{ x.curso }} — {{ x.instituicao }} <span class="sq-muted">({{ x.grau }})</span></p></div>
            <div v-if="(FILHOS.competencias||[]).length" class="mt-2"><strong style="font-size:.8rem">Competências</strong>
              <span v-for="(x,i) in FILHOS.competencias" :key="i" class="sq-badge badge-soft-primary me-1" style="font-size:.75rem">{{ x.nome }}</span></div>
            <div v-if="(FILHOS.idiomas||[]).length" class="mt-2"><strong style="font-size:.8rem">Idiomas</strong>
              <p class="mb-1" style="font-size:.8rem">{{ (FILHOS.idiomas||[]).map((x:any)=>`${x.idioma} (${x.nivel_cefr||x.nivel_global})`).join(' · ') }}</p></div>
            <div v-if="!anonimo && f.expectativa_salarial" class="mt-2"><strong style="font-size:.8rem">Expectativa salarial</strong>
              <p class="mb-1" style="font-size:.8rem">💰 {{ f.expectativa_salarial }} {{ f.moeda }} ({{ f.periodicidade_salarial }})</p></div>
            <div v-if="f.notas_internas" class="mt-2"><strong style="font-size:.8rem">Notas internas <span class="badge-soft-warning px-1 rounded" style="font-size:.65rem">não visível externamente</span></strong>
              <p class="mb-1 sq-muted" style="font-size:.8rem">{{ f.notas_internas }}</p></div>
          </div>
          <button class="btn btn-success mt-3 d-inline-flex align-items-center gap-1" @click="concluir" :disabled="guardando"><IconCheck :size="15" /> Concluir e fechar</button>
        </div>
      </div>
      <div v-else class="p-5 text-center"><span class="spinner-border" style="color:#7367f0"></span></div>

      <!-- rodapé: navegação -->
      <div class="wiz-foot d-flex justify-content-between align-items-center">
        <button class="btn btn-sm btn-outline-secondary d-inline-flex align-items-center gap-1" @click="voltar" :disabled="passo<=1"><IconArrowLeft :size="14" /> Anterior</button>
        <span class="sq-muted" style="font-size:.75rem">Etapa {{ passo }} de 6 · gravação automática</span>
        <button v-if="passo<6" class="btn btn-sm btn-primary d-inline-flex align-items-center gap-1" style="background:#7367f0;border-color:#7367f0" @click="avancar" :disabled="guardando">Seguinte <IconArrowRight :size="14" /></button>
        <button v-else class="btn btn-sm btn-success d-inline-flex align-items-center gap-1" @click="concluir" :disabled="guardando"><IconCheck :size="14" /> Concluir</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.wiz-overlay { position: fixed; inset: 0; background: rgba(15,15,40,.55); display: grid; place-items: center; z-index: 1200; padding: .5rem; }
.wiz-card { width: min(960px, 98vw); height: min(92vh, 900px); background: #fff; border-radius: .8rem; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 10px 40px rgba(15,15,40,.3); }
.wiz-head { padding: .9rem 1rem; border-bottom: 1px solid #eee; }
.wiz-avatar { width: 44px; height: 44px; border-radius: 50%; background: #7367f0; color: #fff; display: grid; place-items: center; font-weight: 600; }
.wiz-etapa { font-size: .75rem; border: 0; border-radius: .5rem; color: #3a3a52; box-shadow: inset 0 0 0 1px rgba(58,58,82,.15); }
.wiz-etapa-ativa { background: #7367f0; color: #fff; box-shadow: none; }
.wiz-etapa-inativa { background: #eef0f6; color: #3a3a52; }
.wiz-etapa-inativa:hover { background: #e2e5ef; color: #2a2a3c; }
.wiz-body { flex: 1; overflow-y: auto; }
.wiz-foot { padding: .7rem 1rem; border-top: 1px solid #eee; }
</style>