<script setup lang="ts">
import {datePT} from '@/domain/dates'
// CandidateCvView.vue — pré-visualização profissional da ficha (estilo CV interno) + exportação PDF.
// Modos: completa (ICV) / anonimizada (RGPD) / sem notas internas. Escolha de secções.
// Exportação via window.print() com CSS @media print dedicado (o utilizador escolhe "Guardar como PDF").
import { ref, computed, onMounted } from 'vue'
import { IconPrinter, IconEye, IconEyeOff, IconFileText, IconDownload } from '@tabler/icons-vue'
import { carregarCandidatoCompleto, type LifecycleCandidato } from '@/services/lifecycle'

const props = defineProps<{ pessoaId: string }>()
const emit = defineEmits<{ (e: 'close'): void }>()

const dados = ref<LifecycleCandidato>({})
const carregando = ref(true)
const modo = ref<'completa' | 'anonimizada' | 'sem_notas'>('completa') // "sem notas" = completa sem notas internas
const secs = ref<Record<string, boolean>>({
  resumo: true, contactos: true, experiencia: true, formacao: true, competencias: true,
  idiomas: true, certificacoes: true, projetos: true, preferencias: true, notas: true,
})
const aviso = ref('')

const p = computed(() => dados.value.pessoa)

const nomeMostrado = computed(() => {
  if (modo.value === 'anonimizada') return 'Candidato anonimizado'
  return p.value?.nome_completo || '—'
})
const inicial = computed(() => (modo.value === 'anonimizada' ? 'AN' : (p.value?.nome_completo || '?').slice(0, 2).toUpperCase()))
const verContactos = computed(() => modo.value !== 'anonimizada' && secs.value.contactos)
const verSalario = computed(() => modo.value !== 'anonimizada')
const verNotas = computed(() => secs.value.notas && modo.value !== 'sem_notas' && modo.value !== 'anonimizada')
const v = (x: unknown): string => (x == null ? '' : Array.isArray(x) ? x.join(', ') : String(x))
const H = (o: unknown): Record<string, any> => (o && typeof o === 'object' ? (o as Record<string, any>) : {}) // eslint-disable-line @typescript-eslint/no-explicit-any

async function carregar() {
  carregando.value = true
  try { dados.value = await carregarCandidatoCompleto(props.pessoaId) }
  catch (e) { aviso.value = (e as Error).message }
  carregando.value = false
}
function imprimir() { window.print() }
onMounted(carregar)
</script>

<template>
  <div class="cv-overlay" @click.self="emit('close')">
    <div class="cv-card">
      <!-- barra de ações (não entra no print) -->
      <div class="cv-toolbar d-flex justify-content-between align-items-center flex-wrap gap-2">
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <span class="fw-semibold">Pré-visualização da ficha (CV interno)</span>
          <span class="sq-muted" style="font-size:.72rem">{{ v(H(p).numero_interno) || p?.id?.slice(0, 8) || '' }}</span>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <select class="form-select form-select-sm" style="width:auto" v-model="modo" title="Versão da ficha">
            <option value="completa">Versão completa</option>
            <option value="anonimizada">Anonimizada (RGPD)</option>
            <option value="sem_notas">Sem notas internas</option>
          </select>
          <button class="btn btn-sm btn-outline-primary d-inline-flex align-items-center gap-1" @click="imprimir"><IconPrinter :size="14" /> Imprimir / PDF</button>
          <button class="btn btn-sm btn-outline-secondary d-inline-flex align-items-center gap-1" @click="emit('close')">✕ Fechar</button>
        </div>
      </div>

      <!-- escolha de secções -->
      <div class="cv-secs d-flex gap-1 flex-wrap px-3 pb-2">
        <label v-for="(on, k) in secs" :key="k" class="form-check form-check-inline" style="font-size:.72rem">
          <input type="checkbox" class="form-check-input" v-model="secs[k]" /> <span class="form-check-label">{{ { resumo: 'Resumo', contactos: 'Contactos', experiencia: 'Experiência', formacao: 'Formação', competencias: 'Competências', idiomas: 'Idiomas', certificacoes: 'Certificações', projetos: 'Projetos', preferencias: 'Preferências', notas: 'Notas' }[k] }}</span>
        </label>
      </div>

      <div class="cv-area">
        <div v-if="carregando" class="p-5 text-center"><span class="spinner-border" style="color:#7367f0"></span></div>
        <div v-else-if="aviso" class="alert alert-danger m-3" style="font-size:.8rem">{{ aviso }}</div>

        <!-- CV renderizado (é o que entra no print) -->
        <div v-else class="cv-doc">
          <div class="cv-head">
            <div class="cv-foto">{{ inicial }}</div>
            <div style="flex:1">
              <div class="cv-nome">{{ nomeMostrado }}</div>
              <div class="cv-titulo">{{ [p?.titulo_atual, p?.empresa_atual].filter(Boolean).join(' · ') || v(p?.area_profissional) }}</div>
              <div v-if="verContactos" class="cv-contactos">
                {{ [p?.email, p?.telefone, p?.linkedin, p?.github, p?.website].filter(Boolean).join('  ·  ') }}
              </div>
              <div v-if="modo==='anonimizada'" class="cv-rgpd">🔒 Versão anonimizada — nome, contactos e dados sensíveis ocultos (RGPD)</div>
            </div>
          </div>

          <div v-if="secs.resumo && p?.resumo_gerado_ia" class="cv-sec">
            <div class="cv-sec-titulo">Resumo profissional</div>
            <p class="cv-texto">{{ p.resumo_gerado_ia }}</p>
            <p v-if="secs.resumo && p?.resumo_original && p.resumo_original !== p.resumo_gerado_ia" class="cv-texto sq-muted" style="font-size:.72rem">Original: {{ p.resumo_original }}</p>
          </div>

          <div v-if="secs.preferencias" class="cv-sec">
            <div class="cv-sec-titulo">Dados e preferências</div>
            <div class="cv-grid">
              <span v-if="modo!=='anonimizada' || true" class="cv-linha"><b>Localização:</b> {{ [v(p?.distrito), v(p?.concelho), v(p?.localidade)].filter(Boolean).join(' · ') || '—' }}</span>
              <span v-if="verSalario && p?.expectativa_salarial" class="cv-linha"><b>Expectativa salarial:</b> {{ v(p.expectativa_salarial) }} {{ v(p?.moeda) }} ({{ v(p?.periodicidade_salarial) }})</span>
              <span class="cv-linha"><b>Disponibilidade:</b> {{ p?.disponibilidade_inicio || '—' }} · <b>Regime:</b> {{ p?.regime || '—' }}</span>
              <span v-if="p?.objetivos_profissionais" class="cv-linha"><b>Objetivo:</b> {{ p.objetivos_profissionais }}</span>
              <span v-if="modo!=='anonimizada' && p?.nacionalidade" class="cv-linha"><b>Nacionalidade:</b> {{ p.nacionalidade }}</span>
            </div>
          </div>

          <div v-if="secs.experiencia && (dados.experiencias||[]).length" class="cv-sec">
            <div class="cv-sec-titulo">Experiência profissional</div>
            <div v-for="(x,i) in dados.experiencias" :key="i" class="cv-item">
              <div class="cv-item-titulo">{{ v(H(x).cargo) }} <span class="cv-empresa">— {{ v(H(x).empresa) }}</span></div>
              <div class="cv-meta">{{ datePT(H(x).data_inicio) }} — {{ H(x).emprego_atual ? 'atual' : datePT(H(x).data_fim) }}<span v-if="H(x).setor"> · {{ v(H(x).setor) }}</span></div>
              <p v-if="H(x).descricao" class="cv-texto">{{ H(x).descricao }}</p>
              <div v-if="H(x).tecnologias" class="cv-tags"><span v-for="(t,i2) in String(H(x).tecnologias).split(',').map(s=>s.trim()).filter(Boolean)" :key="i2" class="tag">{{ t }}</span></div>
            </div>
          </div>

          <div v-if="secs.formacao && (dados.formacoes||[]).length" class="cv-sec">
            <div class="cv-sec-titulo">Formação académica</div>
            <div v-for="(x,i) in dados.formacoes" :key="i" class="cv-item">
              <div class="cv-item-titulo">{{ v(H(x).curso) }} <span class="cv-empresa">— {{ v(H(x).instituicao) }}</span></div>
              <div class="cv-meta">{{ [v(H(x).grau), v(H(x).area_estudo), datePT(H(x).data_inicio)+' — '+datePT(H(x).data_conclusao)].filter(Boolean).join(' · ') }}</div>
            </div>
          </div>

          <div v-if="secs.competencias && (dados.competencias||[]).length" class="cv-sec">
            <div class="cv-sec-titulo">Competências</div>
            <div class="cv-tags"><span v-for="(x,i) in dados.competencias" :key="i" class="tag">{{ v(H(x).nome) }}<span v-if="H(x).nivel_indicado"> ({{ H(x).nivel_indicado }})</span></span></div>
          </div>

          <div v-if="secs.idiomas && (dados.idiomas||[]).length" class="cv-sec">
            <div class="cv-sec-titulo">Idiomas</div>
            <div class="cv-tags"><span v-for="(x,i) in dados.idiomas" :key="i" class="tag">{{ v(H(x).idioma) }} <span class="sq-muted">({{ H(x).nivel_cefr || H(x).nivel_global }})</span></span></div>
          </div>

          <div v-if="secs.certificacoes && (dados.certificacoes||[]).length" class="cv-sec">
            <div class="cv-sec-titulo">Certificações e cursos</div>
            <div v-for="(x,i) in dados.certificacoes" :key="i" class="cv-item">
              <div class="cv-item-titulo">{{ v(H(x).nome) }} <span class="cv-empresa">— {{ v(H(x).entidade) }}</span></div>
              <div class="cv-meta">{{ [datePT(H(x).data_emissao), v(H(x).identificador)].filter(Boolean).join(' · ') }}</div>
            </div>
          </div>

          <div v-if="secs.projetos && (dados.projetos||[]).length" class="cv-sec">
            <div class="cv-sec-titulo">Projetos</div>
            <div v-for="(x,i) in dados.projetos" :key="i" class="cv-item">
              <div class="cv-item-titulo">{{ v(H(x).nome) }}<span v-if="H(x).papel" class="cv-empresa"> — {{ H(x).papel }}</span></div>
              <div class="cv-meta">{{ v(H(x).data) }}</div>
              <p v-if="H(x).descricao" class="cv-texto">{{ H(x).descricao }}</p>
              <div v-if="H(x).tecnologias" class="cv-tags"><span v-for="(t,i2) in String(H(x).tecnologias).split(',').map(s=>s.trim()).filter(Boolean)" :key="i2" class="tag">{{ t }}</span></div>
            </div>
          </div>

          <div v-if="verNotas && p?.notas_internas" class="cv-sec">
            <div class="cv-sec-titulo">Notas internas <span class="badge-soft-warning px-1 rounded" style="font-size:.6rem">não visível externamente</span></div>
            <p class="cv-texto" style="white-space:pre-wrap">{{ p.notas_internas }}</p>
          </div>

          <div class="cv-rodape sq-muted">SAMSYS|Qualidade · LifeCycle RH · <span v-if="p?.updated_at">última atualização {{ new Date(p.updated_at).toLocaleString('pt-PT') }}</span><span v-else>ficha</span> · {{ modo==='anonimizada' ? 'versão anonimizada' : 'versão completa' }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cv-overlay { position: fixed; inset: 0; background: rgba(15,15,40,.55); display: grid; place-items: center; z-index: 1300; padding: .5rem; }
.cv-card { width: min(860px, 98vw); height: min(94vh, 950px); background: #fff; border-radius: .8rem; display: flex; flex-direction: column; overflow: hidden; }
.cv-toolbar { padding: .8rem 1rem; border-bottom: 1px solid #eee; }
.cv-secs { border-bottom: 1px solid #f0f0f3; }
.cv-area { flex: 1; overflow-y: auto; padding: 1rem; background: #f6f6f9; }
.cv-doc { max-width: 794px; margin: 0 auto; background: #fff; padding: 2rem 2.2rem; box-shadow: 0 2px 12px rgba(76,69,157,.08); border-radius: .25rem; }
.cv-head { display: flex; gap: 1.1rem; align-items: center; padding-bottom: 1rem; border-bottom: 2px solid #7367f0; }
.cv-foto { width: 76px; height: 76px; border-radius: 50%; background: #7367f0; color: #fff; display: grid; place-items: center; font-size: 1.5rem; font-weight: 700; }
.cv-nome { font-size: 1.45rem; font-weight: 700; color: #2a2a3c; line-height: 1.2; }
.cv-titulo { color: #7367f0; font-weight: 600; font-size: .95rem; }
.cv-contactos { color: #5d596c; font-size: .78rem; margin-top: .2rem; }
.cv-rgpd { color: #ea5455; font-size: .72rem; margin-top: .2rem; }
.cv-sec { margin-top: 1rem; }
.cv-sec-titulo { font-size: .8rem; font-weight: 700; color: #7367f0; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1px solid #eee; padding-bottom: .25rem; margin-bottom: .4rem; }
.cv-item { margin-bottom: .55rem; }
.cv-item-titulo { font-weight: 600; font-size: .85rem; color: #2a2a3c; }
.cv-empresa { font-weight: 500; color: #7367f0; }
.cv-meta { color: #8b8aa8; font-size: .72rem; }
.cv-texto { font-size: .8rem; color: #44435a; margin: .2rem 0; }
.cv-grid { display: flex; flex-direction: column; gap: .15rem; font-size: .8rem; }
.cv-linha { color: #44435a; }
.cv-tags { display: flex; flex-wrap: wrap; gap: .3rem; margin-top: .2rem; }
.tag { font-size: .72rem; background: #f0eeff; color: #4a4587; border-radius: .4rem; padding: .1rem .45rem; }
.cv-rodape { margin-top: 1.4rem; padding-top: .5rem; border-top: 1px solid #eee; font-size: .65rem; text-align: center; }

/* impressão / exportação PDF: só o CV, sem barras, sem fundo cinzento */
@media print {
  .cv-overlay { position: static; background: #fff; padding: 0; z-index: 1; }
  .cv-card { width: 100%; height: auto; box-shadow: none; overflow: visible; border-radius: 0; }
  .cv-toolbar, .cv-secs { display: none !important; }
  .cv-area { padding: 0; background: #fff; overflow: visible; }
  .cv-doc { box-shadow: none; border-radius: 0; padding: 0; max-width: 100%; }
  .cv-head { border-bottom-color: #000; }
  .cv-nome { color: #000; }
  .cv-sec-titulo { color: #333; border-bottom-color: #ccc; }
  .cv-empresa, .cv-titulo { color: #333; }
  .cv-texto, .cv-linha, .cv-item-titulo { color: #000; }
}
</style>