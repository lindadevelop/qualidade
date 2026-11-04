<script setup lang="ts">
// CandidateCvPanel.vue — Ficha de pessoa + processamento de CV (Fase 1/2/3)
// Dois modos:
//  - fila (padrão): enfileira o PDF e fecha — o worker processa em background (nunca bloqueia)
//  - ligado a um caso: processa diretamente (compatibilidade) — usado em casos já existentes
import { ref, computed } from 'vue'
import {
  uploadCv, enqueueCv, extractCvText, analyzeCvText, upsertPessoa, getPessoa, updateCasoPessoa, setCvSession,
  criarFilho, listarFilhos,
  type LifecyclePessoa,
} from '@/services/lifecycle'
import { IconUpload, IconRobot, IconCheck, IconX, IconFileText, IconRefresh, IconAlertTriangle, IconLoader } from '@tabler/icons-vue'

const props = defineProps<{ casoId?: string | null; casoNome?: string; preAnalise?: any | null; preTexto?: string | null; preJobId?: string | null; pessoaIdInicial?: string | null }>() // eslint-disable-line @typescript-eslint/no-explicit-any
const emit = defineEmits<{ (e: 'close'): void; (e: 'saved', pessoa?: unknown): void; (e: 'queued', jobId: string): void }>()
const isNovo = computed(() => !props.casoId)

const fileInput = ref<HTMLInputElement | null>(null)
const step = ref<'idle' | 'uploading' | 'extracting' | 'analyzing' | 'review' | 'saving' | 'error'>('idle')
const msg = ref('')
const dragging = ref(false)
const elapsed = ref(0)
const cvPath = ref('')
const cvHash = ref('')
const extOcr = ref(false)
const extPages = ref(0)
const cvText = ref('')
const analysis = ref<any>(null) // eslint-disable-line @typescript-eslint/no-explicit-any
const fichasExistentes = ref<'nova' | 'reutilizada' | 'duplicado'>('nova')
const duplicados = ref<string[]>([])

// ---- formulário editável (preenchido pela IA, corrigível pelo humano) ----
const form = ref<Record<string, any>>({ // eslint-disable-line @typescript-eslint/no-explicit-any
  id: '', nome_completo: '', nome_preferido: '', email: '', telefone: '', linkedin: '', github: '',
  website: '', data_nascimento: '', nacionalidade: '', pais_residencia: '', localidade: '', distrito: '', morada: '',
  setores: [] as string[], objetivos_profissionais: '',
  resumo_original: '', resumo_gerado_ia: '', competencias_principais: [] as string[],
  areas_experiencia: [] as string[], anos_experiencia: null, titulo_atual: '', empresa_atual: '',
  disponibilidade_inicio: '', regime: '',
})

const confidence = computed(() => analysis.value?.data?.overall_confidence ?? null)
const missing = computed(() => (analysis.value?.data?.missing_information ?? []) as any[]) // eslint-disable-line @typescript-eslint/no-explicit-any
const lowConfFields = computed(() => {
  const out: string[] = []
  const d = analysis.value?.data
  if (!d) return out
  for (const [k, v] of Object.entries(d.candidate ?? {})) {
    const o = v as any // eslint-disable-line @typescript-eslint/no-explicit-any
    if (o && typeof o === 'object' && typeof o.confidence === 'number' && o.confidence < 0.5) out.push(k)
  }
  return out
})

function val(v: any): string { // eslint-disable-line @typescript-eslint/no-explicit-any
  if (v == null) return ''
  if (typeof v === 'string') return v
  if (typeof v === 'object') return v.value ?? v.name ?? v.email ?? v.title ?? JSON.stringify(v)
  return String(v)
}

function applyAnalysis() {
  const d = analysis.value?.data ?? {}
  const c = d.candidate ?? {}
  const ct = d.contacts ?? {}
  const ps = d.professional_summary ?? {}
  form.value.nome_completo = val(c.name) || val(c.full_name) || val(c.nome) || ''
  form.value.email = val(ct.email) || val(c.email) || ''
  form.value.telefone = val(ct.telephone) || val(ct.phone) || val(c.telephone) || ''
  form.value.linkedin = val(ct.linkedin) || ''
  form.value.github = val(ct.github) || ''
  form.value.website = val(ct.website) || ''
  form.value.resumo_original = val(ps.summary) || val(ps.resumo) || ''
  form.value.resumo_gerado_ia = (d.professional_summary && d.professional_summary.generated_summary) ? val(d.professional_summary.generated_summary) : ''
  form.value.anos_experiencia = d.candidate?.years_experience?.value ?? d.candidate?.years_experience ?? null
  form.value.titulo_atual = val(d.candidate?.current_title) || ''
  form.value.empresa_atual = val(d.candidate?.current_company) || ''
  form.value.disponibilidade_inicio = val(d.preferences?.availability) || ''
  form.value.regime = val(d.preferences?.work_mode) || ''
  form.value.data_nascimento = val(d.candidate?.date_of_birth || d.candidate?.birth_date)?.slice(0, 10) || ''
  form.value.nacionalidade = val(d.candidate?.nationality) || ''
  form.value.pais_residencia = val(ct.country || d.candidate?.country_of_residence) || ''
  form.value.localidade = val(ct.city || d.candidate?.city) || ''
  form.value.distrito = val(ct.region || d.candidate?.region) || ''
  form.value.morada = val(ct.address) || ''
  form.value.setores = Array.isArray(d.candidate?.sectors) ? (d.candidate.sectors.map((x: any) => typeof x === 'string' ? x : val(x.value ?? x.name)).filter(Boolean)) : []
  form.value.objetivos_profissionais = val(d.candidate?.objective) || val(d.preferences?.objective) || ''
  const rawSkills = d.skills ?? []
  // skills pode vir como array OU objeto {value:[...]}
  const skillArray = Array.isArray(rawSkills) ? rawSkills : (rawSkills.value && Array.isArray(rawSkills.value) ? rawSkills.value : [])
  const skills = skillArray.map((s: any) => (typeof s === 'string' ? s : val(s.value ?? s))).filter(Boolean) // eslint-disable-line @typescript-eslint/no-explicit-any
  form.value.competencias_principais = skills.slice(0, 12)
  const areas = (d.work_experience ?? []).map((w: any) => { // eslint-disable-line @typescript-eslint/no-explicit-any
    if (typeof w === 'string') return w
    return val(w.field) || val(w.area) || val(w.position) || ''
  }).filter(Boolean).slice(0, 8)
  form.value.areas_experiencia = areas
}

// ---- deteção de possíveis duplicados (email/telefone/nome) ----
async function checkDuplicates() {
  duplicados.value = []
  const email = (form.value.email || '').trim().toLowerCase()
  const nome = (form.value.nome_completo || '').trim().toLowerCase()
  if (!email && !nome) return
  const { data } = await useSupabaseList()
  if (!data) return
  for (const p of data) {
    const pe = (p.email || '').toLowerCase()
    const pn = (p.nome_completo || '').toLowerCase()
    if ((email && pe === email) || (nome && pn === nome)) {
      duplicados.value.push(`${p.nome_completo}${p.email ? ' · ' + p.email : ''}`)
    }
  }
}
async function useSupabaseList() {
  const { supabase } = await import('@/lib/supabase')
  return supabase.from('lifecycle_pessoas').select('id,nome_completo,email').limit(500)
}

// ---- pipeline ---- 
async function onFile(file: File) {
  if (!file) return
  if (file.type !== 'application/pdf' && !/\.pdf$/i.test(file.name)) { msg.value = 'Só são aceites ficheiros PDF.'; step.value = 'error'; return }
  if (file.size > 15 * 1024 * 1024) { msg.value = `"${file.name}" é demasiado grande (máx. 15 MB).`; step.value = 'error'; return }
  // Modo fila (sem caso): apenas enfileira e fecha — o worker processa em background.
  if (!props.casoId) {
    step.value = 'uploading'; msg.value = ''
    try {
      const up = await uploadCv(file)
      const res = await enqueueCv({ file_name: file.name, file_path: up.path, file_hash: up.hash, file_size: file.size })
      emit('queued', res.job_id)
      return  // o estado da página/panel fecha
    } catch (e) {
      msg.value = (e as Error).message || 'Erro ao adicionar o CV à fila.'
      step.value = 'error'
    }
    return
  }
  step.value = 'uploading'; msg.value = ''
  try {
    const up = await uploadCv(file)
    cvPath.value = up.path; cvHash.value = up.hash
    step.value = 'extracting'
    const ext = await extractCvText(up.path)
    cvText.value = ext.text
    extOcr.value = !!ext.ocr_used
    extPages.value = ext.pages || 0
    if (!ext.has_text) {
      msg.value = 'O PDF não contém texto extraível. Se for uma digitalização, o OCR não está configurado no servidor (TESSERACT_BIN).'
      step.value = 'error'; return
    }
    step.value = 'analyzing'
    const an = await analyzeCvText(ext.text, up.path, (ms) => { elapsed.value = ms })
    analysis.value = an
    setCvSession({ text: ext.text, analysis: an.data })   // disponível para a avaliação vs vaga
    applyAnalysis()
    await checkDuplicates()
    step.value = 'review'
  } catch (e) {
    msg.value = (e as Error).message || 'Erro ao processar o CV.'
    step.value = 'error'
  }
}
function onDrop(e: DragEvent) {
  dragging.value = false
  const ff = e.dataTransfer?.files
  if (ff && ff.length) onFiles(ff)
}
function onPick(e: Event) {
  const t = e.target as HTMLInputElement
  if (t.files && t.files.length) onFiles(t.files)
}
// Modo fila: envia VÁRIOS PDFs de uma vez (cada um enfileirado como job independente).
async function onFiles(files: FileList) {
  if (!files.length) return
  const pdfs = Array.from(files).filter((f) => f.type === 'application/pdf' || /\.pdf$/i.test(f.name))
  if (pdfs.length !== files.length) {
    msg.value = 'Alguns ficheiros não são PDF e foram ignorados.'
    step.value = 'error'
  }
  if (!pdfs.length) return
  const grandes = pdfs.filter((f) => f.size > 15 * 1024 * 1024)
  if (grandes.length) {
    msg.value = `Ignorados (máx. 15 MB): ${grandes.map((f) => f.name).join(', ')}.`
    step.value = 'error'
    const dentro = pdfs.filter((f) => f.size <= 15 * 1024 * 1024)
    pdfs.length = 0
    pdfs.push(...dentro)
  }
  if (!props.casoId) {
    const aviso = msg.value
    step.value = 'uploading'
    msg.value = aviso
    try {
      let enviados = 0
      for (const f of pdfs) {
        const up = await uploadCv(f)
        await enqueueCv({ file_name: f.name, file_path: up.path, file_hash: up.hash, file_size: f.size })
        enviados++
      }
      emit('queued', 'batch:' + enviados.toString())
      return
    } catch (e) {
      msg.value = (e as Error).message || 'Erro ao adicionar os CVs à fila.'
      step.value = 'error'
    }
    return
  }
  // com caso: processa o primeiro diretamente (compatibilidade)
  await onFile(pdfs[0])
}

// ---- espelhar a análise do CV nas tabelas filhas (ficha 360º) ----
async function guardarFilhosDoCv(pessoaId: string, analysisData: any) { // eslint-disable-line @typescript-eslint/no-explicit-any
  if (!analysisData) return
  const val = (o: any) => { // eslint-disable-line @typescript-eslint/no-explicit-any
    if (o == null) return null
    if (typeof o === 'string') return o
    if (typeof o === 'object') return o.value ?? o.name ?? o.title ?? String(o.value ?? '')
    return String(o)
  }
  // já importado antes? evita duplicar na mesma pessoa
  const jaTem = (await listarFilhos('lifecycle_experiencias', pessoaId)).some((x) => (x as any).origem_dado === 'ia_import') // eslint-disable-line @typescript-eslint/no-explicit-any
  if (jaTem) return
  const hoje = new Date().toISOString().slice(0, 10)
  // experiências
  for (const w of Array.isArray(analysisData.work_experience) ? analysisData.work_experience : []) {
    if (typeof w === 'string') continue
    await criarFilho('lifecycle_experiencias', pessoaId, {
      cargo: val(w.position || w.title) || null, empresa: val(w.company) || null,
      setor: val(w.industry) || null, local: val(w.location) || null,
      data_inicio: val(w.start_date)?.slice(0, 10) || null, data_fim: val(w.end_date)?.slice(0, 10) || null,
      emprego_atual: !!(w.current || w.is_current), descricao: val(w.description) || null,
      tecnologias: Array.isArray(w.technologies) ? w.technologies.join(', ') : val(w.technologies) || null,
      origem_dado: 'ia_import',
    }).catch(() => null)
  }
  // formação
  for (const e of Array.isArray(analysisData.education) ? analysisData.education : []) {
    if (typeof e === 'string') continue
    await criarFilho('lifecycle_formacoes', pessoaId, {
      curso: val(e.degree || e.field) || null, instituicao: val(e.institution || e.school) || null,
      grau: val(e.degree) || null, area_estudo: val(e.field) || null,
      data_inicio: val(e.start_date)?.slice(0, 10) || null, data_conclusao: val(e.end_date || e.graduation_date)?.slice(0, 10) || null,
      estado: e.current ? 'em_curso' : null, classificacao: val(e.grade) || null,
      origem_dado: 'ia_import',
    }).catch(() => null)
  }
  // competências
  const skillsRaw = Array.isArray(analysisData.skills) ? analysisData.skills : []
  for (const s of skillsRaw) {
    const nome = typeof s === 'string' ? s : val(s.value ?? s.name)
    if (!nome) continue
    await criarFilho('lifecycle_competencias', pessoaId, {
      nome, categoria: (typeof s === 'object' && (s as any).category) ? (s as any).category : 'Técnica', // eslint-disable-line @typescript-eslint/no-explicit-any
      nivel_indicado: (typeof s === 'object' && (s as any).level) ? String((s as any).level) : null, // eslint-disable-line @typescript-eslint/no-explicit-any
      origem_dado: 'ia_import',
    }).catch(() => null)
  }
  // idiomas
  for (const l of Array.isArray(analysisData.languages) ? analysisData.languages : []) {
    if (typeof l === 'string') continue
    await criarFilho('lifecycle_idiomas', pessoaId, {
      idioma: val(l.name || l.language) || null,
      nivel_global: val(l.level) || null, nivel_cefr: val(l.cefr) || null,
      lingua_materna: !!(l.native || l.is_mother), origem_dado: 'ia_import',
    }).catch(() => null)
  }
  // certificações
  for (const c of Array.isArray(analysisData.certifications) ? analysisData.certifications : []) {
    if (typeof c === 'string') continue
    await criarFilho('lifecycle_certificacoes', pessoaId, {
      nome: val(c.name || c.title) || null, entidade: val(c.issuer || c.institution) || null,
      data_emissao: val(c.date || c.issue_date)?.slice(0, 10) || null, validade: val(c.valid_until)?.slice(0, 10) || null,
      identificador: val(c.credential_id) || null, link_validacao: val(c.url) || null,
      origem_dado: 'ia_import',
    }).catch(() => null)
  }
  // projetos
  for (const pj of Array.isArray(analysisData.projects) ? analysisData.projects : []) {
    if (typeof pj === 'string') continue
    const o = pj as any // eslint-disable-line @typescript-eslint/no-explicit-any
    await criarFilho('lifecycle_projetos', pessoaId, {
      nome: val(o.name || o.title) || null, descricao: val(o.description) || null,
      papel: val(o.role) || null, tecnologias: Array.isArray(o.technologies) ? o.technologies.join(', ') : val(o.technologies) || null,
      link: val(o.url) || null, data: val(o.date)?.slice(0, 10) || null,
      tipo: 'cv',
    }).catch(() => null)
  }
  void hoje
}
// anotação de processamento do PDF (ex.: OCR usado) — registada para auditoria
function anotarProcessamento(ext: any, analysisData: any): string[] { // eslint-disable-line @typescript-eslint/no-explicit-any
  const notas: string[] = []
  if (ext?.ocr_used) notas.push('Texto obtido por OCR do PDF (digitalização).')
  if (ext?.pages && ext.pages > 1) notas.push(`Documento com ${ext.pages} páginas.`)
  if (analysisData?.overall_confidence != null) notas.push(`Confiança global da extração IA: ${Math.round((analysisData.overall_confidence || 0) * 100)}%.`)
  const missing = Array.isArray(analysisData?.missing_information) ? analysisData.missing_information.map((x: any) => String(x?.field ?? x ?? '').trim()).filter(Boolean) : [] // eslint-disable-line @typescript-eslint/no-explicit-any
  if (missing.length) notas.push(`Informação não identificada: ${missing.slice(0, 6).join(', ')}${missing.length > 6 ? '…' : ''}.`)
  return notas
}

// ---- gravar (validação humana) ----
async function gravar() {
  const nome = form.value.nome_completo.trim()
  if (!nome) { msg.value = 'O nome é obrigatório.'; step.value = 'error'; return }
  step.value = 'saving'; msg.value = ''
  try {
    const payload: Partial<LifecyclePessoa> = {
      id: form.value.id || undefined,
      nome_completo: nome,
      nome_preferido: form.value.nome_preferido || null,
      email: form.value.email || null,
      telefone: form.value.telefone || null,
      linkedin: form.value.linkedin || null,
      github: form.value.github || null,
      website: form.value.website || null,
      data_nascimento: form.value.data_nascimento || null,
      nacionalidade: form.value.nacionalidade || null,
      pais_residencia: form.value.pais_residencia || null,
      localidade: form.value.localidade || null,
      distrito: form.value.distrito || null,
      morada: form.value.morada || null,
      setores: form.value.setores?.length ? form.value.setores : [],
      objetivos_profissionais: form.value.objetivos_profissionais || null,
      resumo_original: form.value.resumo_original || null,
      resumo_gerado_ia: form.value.resumo_gerado_ia || null,
      competencias_principais: form.value.competencias_principais?.length ? form.value.competencias_principais : [],
      areas_experiencia: form.value.areas_experiencia?.length ? form.value.areas_experiencia : [],
      anos_experiencia: form.value.anos_experiencia ?? null,
      titulo_atual: form.value.titulo_atual || null,
      empresa_atual: form.value.empresa_atual || null,
      disponibilidade_inicio: form.value.disponibilidade_inicio || null,
      regime: form.value.regime || null,
      cv_hash: cvHash.value || null,
      cv_ultima_url: cvPath.value || null,
    }
    // reutilizar pessoa já existente se indicado
    const pessoa = await upsertPessoa(payload)
    // espelhar o CV nas tabelas filhas (experiências, formações, competências, idiomas…) e anotar o processamento
    try {
      await guardarFilhosDoCv(pessoa.id, analysis.value?.data)
      const notas = anotarProcessamento({ ocr_used: (extOcr.value), pages: (extPages.value) }, analysis.value?.data)
      if (notas.length) {
        const { supabase } = await import('@/lib/supabase')
        const anteriores = (pessoa as any).notas_internas ? String((pessoa as any).notas_internas) + '\n' : '' // eslint-disable-line @typescript-eslint/no-explicit-any
        await supabase.from('lifecycle_pessoas').update({ notas_internas: anteriores + notas.join('\n') }).eq('id', pessoa.id)
      }
    } catch { /* falha nos filhos não bloqueia a ficha */ }
    if (props.casoId) {
      await updateCasoPessoa(props.casoId, pessoa.id)
      emit('saved', pessoa)
    } else {
      // sem caso: entrega a pessoa à página para esta criar a candidatura
      emit('saved', pessoa)
    }
  } catch (e) {
    msg.value = (e as Error).message || 'Erro ao gravar a ficha.'
    step.value = 'error'
  }
}

function reset() {
  step.value = 'idle'; msg.value = ''; analysis.value = null; cvText.value = ''; cvPath.value = ''; cvHash.value = ''
  duplicados.value = []
}

// ---- modo "validar a partir da fila": aplica a análise do job DONE (sem re-processar) ----
import { onMounted } from 'vue'
onMounted(async () => {
  if (props.preAnalise) {
    step.value = 'review'
    // preJobId carrega o file_path do job (ex.: <hash>.pdf) → cv_ultima_url do storage
    cvPath.value = props.preJobId ? `/storage/v1/object/${String(props.preJobId).split('/').pop() || ''}` : ''
    cvHash.value = props.preJobId || ''
    analysis.value = { ok: true, data: props.preAnalise }
    setCvSession({ text: props.preTexto || '', analysis: props.preAnalise })
    applyAnalysis()
    await checkDuplicates()
  } else if (props.pessoaIdInicial) {
    // edição de uma ficha de pessoa já existente (sem re-processar): carrega e permite corrigir
    const p = await getPessoa(props.pessoaIdInicial)
    if (p) {
      form.value.id = p.id
      form.value.nome_completo = p.nome_completo || ''
      form.value.nome_preferido = p.nome_preferido || ''
      form.value.email = p.email || ''
      form.value.telefone = p.telefone || ''
      form.value.linkedin = p.linkedin || ''
      form.value.github = p.github || ''
      form.value.resumo_original = p.resumo_original || ''
      form.value.resumo_gerado_ia = p.resumo_gerado_ia || ''
      form.value.competencias_principais = Array.isArray(p.competencias_principais) ? p.competencias_principais.slice(0, 12) : []
      form.value.areas_experiencia = Array.isArray(p.areas_experiencia) ? p.areas_experiencia.slice(0, 8) : []
      form.value.anos_experiencia = p.anos_experiencia ?? null
      form.value.titulo_atual = p.titulo_atual || ''
      form.value.empresa_atual = p.empresa_atual || ''
      form.value.disponibilidade_inicio = p.disponibilidade_inicio || ''
      form.value.regime = p.regime || ''
      cvPath.value = p.cv_ultima_url || ''
      cvHash.value = p.cv_hash || ''
      step.value = 'review'
    }
  }
})
</script>

<template>
  <div class="modal-overlay" @click.self="emit('close')">
    <div class="card" style="max-width:760px;max-height:92vh;overflow:auto">
      <div class="card-header d-flex justify-content-between align-items-center">
        <span class="fw-semibold">{{ props.casoNome ? 'Ficha de pessoa · ' + props.casoNome : 'Importar CV — criar nova ficha' }}</span>
        <button class="btn btn-sm btn-close" @click="emit('close')"></button>
      </div>
      <div class="card-body">
        <div v-if="msg" class="alert alert-danger py-2 d-flex gap-2 align-items-start" style="font-size:.85rem">
          <IconAlertTriangle :size="16" class="mt-1" style="color:#ea5455" /> <span class="flex-grow-1">{{ msg }}</span>
        </div>

        <!-- drag & drop / picker -->
        <div v-if="step==='idle' || step==='error'"
          class="border rounded d-flex flex-column align-items-center justify-content-center p-4 mb-3"
          :class="dragging ? 'border-primary bg-primary-subtle' : 'border-dashed'" style="border-style:dashed;cursor:pointer;min-height:120px"
          @dragover.prevent="dragging=true" @dragleave="dragging=false" @drop.prevent="onDrop" @click="fileInput?.click()">
          <IconUpload :size="26" class="mb-2" style="color:#7367f0" />
          <span class="sq-muted" style="font-size:.85rem">Arrasta um ou vários CVs aqui ou clica para escolher (PDF, máx. 15 MB cada)</span>
          <input ref="fileInput" type="file" accept=".pdf,application/pdf" multiple hidden @change="onPick" />
        </div>

        <!-- progresso -->
        <div v-if="['uploading','extracting','analyzing','saving'].includes(step)" class="d-flex align-items-center gap-3 py-4">
          <span class="spinner-border" style="color:#7367f0"></span>
          <div>
            <div class="fw-semibold" style="font-size:.9rem">
              {{ step==='uploading' ? 'A enviar o CV…' : step==='extracting' ? 'A extrair o texto…' : step==='analyzing' ? 'A analisar com o Ollama (pode demorar 3-5 min)…' : 'A gravar…' }}
            </div>
            <div class="sq-muted" style="font-size:.78rem">Podes sair desta janela; o processamento continua.</div>
            <div v-if="step==='analyzing' && elapsed>0" class="sq-muted" style="font-size:.75rem">Já decorreram {{ Math.round(elapsed/1000) }}s…</div>
          </div>
        </div>

        <!-- revisão humana -->
        <div v-if="step==='review'">
          <div class="d-flex flex-wrap align-items-center gap-2 mb-3">
            <span class="sq-badge badge-soft-success"><IconCheck :size="13" /> CV processado</span>
            <span v-if="fichasExistentes==='duplicado'" class="sq-badge badge-soft-warning"><IconAlertTriangle :size="13" /> Possível duplicado</span>
            <span v-if="confidence!=null" class="sq-badge" :class="confidence>=0.7 ? 'badge-soft-success' : 'badge-soft-warning'">
              <IconRobot :size="13" /> Confiança: {{ Math.round(confidence*100) }}%
            </span>
            <button class="btn btn-sm btn-outline-secondary ms-auto" @click="reset"><IconRefresh :size="14" /> Enviar outro</button>
          </div>

          <div v-if="duplicados.length" class="alert alert-warning py-2 mb-3" style="font-size:.82rem">
            ⚠️ Possíveis correspondências já registadas: {{ duplicados.join('; ') }} — revê antes de gravar (não é feita fusão automática).
          </div>
          <div v-if="lowConfFields.length" class="alert alert-info py-2 mb-3" style="font-size:.82rem">
            <IconAlertTriangle :size="14" /> Campos de baixa confiança a rever: {{ lowConfFields.join(', ') }}
          </div>

          <div class="row g-2">
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Nome completo *</label>
              <input v-model="form.nome_completo" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Nome preferido</label>
              <input v-model="form.nome_preferido" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Email</label>
              <input v-model="form.email" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Telefone</label>
              <input v-model="form.telefone" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">LinkedIn</label>
              <input v-model="form.linkedin" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">GitHub</label>
              <input v-model="form.github" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-4"><label class="form-label small sq-muted mb-0">Anos de experiência</label>
              <input v-model.number="form.anos_experiencia" type="number" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-4"><label class="form-label small sq-muted mb-0">Título atual</label>
              <input v-model="form.titulo_atual" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-4"><label class="form-label small sq-muted mb-0">Empresa atual</label>
              <input v-model="form.empresa_atual" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Disponibilidade</label>
              <input v-model="form.disponibilidade_inicio" class="form-control form-control-sm" /></div>
            <div class="col-12 col-md-6"><label class="form-label small sq-muted mb-0">Regime</label>
              <input v-model="form.regime" class="form-control form-control-sm" placeholder="presencial / híbrido / remoto" /></div>
            <div class="col-12"><label class="form-label small sq-muted mb-0">Resumo → <span class="badge-soft-warning px-1 rounded" style="font-size:.65rem">gerado por IA</span></label>
              <textarea v-model="form.resumo_gerado_ia" rows="2" class="form-control form-control-sm"></textarea></div>
            <div class="col-12"><label class="form-label small sq-muted mb-0">Competências principais</label>
              <input v-model="form.competencias_principais" style="display:none" />
              <div class="d-flex flex-wrap gap-1">
                <span v-for="(s, i) in form.competencias_principais" :key="i" class="sq-badge badge-soft-primary d-inline-flex align-items-center gap-1">
                  {{ s }} <button type="button" class="btn-close" style="font-size:.5rem" @click="form.competencias_principais.splice(i,1)"></button>
                </span>
              </div></div>
          </div>

          <div class="d-flex justify-content-end gap-2 mt-3">
            <button class="btn btn-outline-secondary btn-sm" @click="emit('close')">Cancelar</button>
            <button class="btn btn-primary btn-sm d-flex align-items-center gap-1" style="background:#7367f0;border-color:#7367f0"
              @click="gravar" :disabled="!form.nome_completo.trim()">
              <IconCheck :size="15" /> Confirmar e gravar ficha
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>