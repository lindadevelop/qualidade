import {datePT,validDate} from '../domain/dates'
// Formatação de datas, prazos e etiquetas (PT-PT)

export function formatDate(iso?: string | null): string {
  if (iso && validDate(iso)) return datePT(iso)
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('pt-PT', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

export function formatDateTime(iso?: string | null): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return '—'
  return d.toLocaleString('pt-PT', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

/** Dias até ao prazo (negativo = atrasado). Calculado dinamicamente, nunca guardado. */
export function daysUntil(deadline?: string | null): number | null {
  if (!deadline) return null
  const d = new Date(deadline)
  if (isNaN(d.getTime())) return null
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  d.setHours(0, 0, 0, 0)
  return Math.round((d.getTime() - today.getTime()) / 86400000)
}

/** Texto de prazo: "Atrasada há 5 dias" | "Termina hoje" | "1 dia" | "3 dias" */
export function deadlineLabel(deadline?: string | null, completed = false): string {
  if (completed) return 'Concluída'
  const n = daysUntil(deadline)
  if (n === null) return 'Sem prazo'
  if (n < 0) {
    const a = Math.abs(n)
    return `Atrasada há ${a} ${a === 1 ? 'dia' : 'dias'}`
  }
  if (n === 0) return 'Termina hoje'
  if (n === 1) return '1 dia'
  return `${n} dias`
}

export type DeadlineTone = 'overdue' | 'today' | 'soon' | 'ok'

export function deadlineTone(deadline?: string | null, completed = false): DeadlineTone {
  if (completed) return 'ok'
  const n = daysUntil(deadline)
  if (n === null) return 'ok'
  if (n < 0) return 'overdue'
  if (n === 0) return 'today'
  if (n <= 3) return 'soon'
  return 'ok'
}

// ---------- Rótulos PT ----------
export const OCCURRENCE_STATUS_LABEL: Record<string, string> = {
  OPEN: 'Aberta',
  IN_PROGRESS: 'Em curso',
  AWAITING_EFFECTIVENESS: 'A aguardar eficácia',
  CLOSED: 'Encerrada',
}

export const ACTION_STATUS_LABEL: Record<string, string> = {
  TODO: 'Por iniciar',
  IN_PROGRESS: 'Em curso',
  COMPLETED: 'Concluída',
}

export function occurrenceStatusLabel(s: string): string {
  return OCCURRENCE_STATUS_LABEL[s] ?? s
}

export function actionStatusLabel(s: string): string {
  return ACTION_STATUS_LABEL[s] ?? s
}

// ---------- Cores de badges (Vuexy discreto) ----------
export function occurrenceTypeBadge(type: string): string {
  return type === 'NC' ? 'badge-soft-danger' : 'badge-soft-primary'
}

export function occurrenceStatusBadge(status: string): string {
  switch (status) {
    case 'OPEN': return 'badge-soft-secondary'
    case 'IN_PROGRESS': return 'badge-soft-warning'
    case 'AWAITING_EFFECTIVENESS': return 'badge-soft-info'
    case 'CLOSED': return 'badge-soft-success'
    default: return 'badge-soft-secondary'
  }
}

export function actionStatusBadge(status: string): string {
  switch (status) {
    case 'TODO': return 'badge-soft-secondary'
    case 'IN_PROGRESS': return 'badge-soft-warning'
    case 'COMPLETED': return 'badge-soft-success'
    default: return 'badge-soft-secondary'
  }
}

/** Progresso de ações: "3 de 5 ações concluídas · 60%" */
export function actionsProgress(actions: { status: string }[]): { total: number; done: number; pct: number; label: string } {
  const total = actions.length
  const done = actions.filter((a) => a.status === 'COMPLETED').length
  const pct = total === 0 ? 0 : Math.round((done / total) * 100)
  const label = total === 0 ? 'Sem ações' : `${done} de ${total} ações concluídas`
  return { total, done, pct, label }
}

export function initials(name?: string | null): string {
  if (!name) return '?'
  return name.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]?.toUpperCase()).join('')
}

// ---------- Histórico / Auditoria legível (nunca JSON bruto) ----------
const FIELD_LABELS: Record<string, string> = {
  status: 'Estado',
  type: 'Tipo',
  description: 'Descrição',
  cause_analysis: 'Análise/Causa',
  responsible_user_id: 'Responsável',
  origin_id: 'Origem',
  area_id: 'Área/Processo',
  occurrence_date: 'Data',
  deadline: 'Prazo',
  reference: 'Referência',
  effectiveness_status: 'Resultado da eficácia',
  effectiveness_notes: 'Observações de eficácia',
  effectiveness_validated_by: 'Validador da eficácia',
  effectiveness_validated_at: 'Data de validação',
  closed_at: 'Data de encerramento',
  reopened_at: 'Data de reabertura',
  reopened_by: 'Reaberto por',
  created_by: 'Criado por',
  updated_at: 'Atualizado em',
  created_at: 'Criado em',
  completed_at: 'Data de conclusão',
  comment: 'Comentário',
  file_name: 'Ficheiro',
}

const STATUS_LABELS: Record<string, string> = {
  OPEN: 'Aberta',
  IN_PROGRESS: 'Em curso',
  AWAITING_EFFECTIVENESS: 'A aguardar eficácia',
  CLOSED: 'Encerrada',
  TODO: 'Por iniciar',
  COMPLETED: 'Concluída',
  NC: 'Não Conformidade',
  OM: 'Oportunidade de Melhoria',
  EFFECTIVE: 'Eficaz',
  NOT_EFFECTIVE: 'Não eficaz',
}

/** Converte { campo: {old, new} } em linhas legíveis: "Estado: Aberta → Em curso" */
export function auditLines(changed: Record<string, { old: string; new: string }> | null): { field: string; from: string; to: string }[] {
  if (!changed) return []
  // ignorar ruído: created_at/updated_at apenas (timestamps automáticos)
  const meaningful = Object.entries(changed).filter(([key]) => !['created_at', 'updated_at'].includes(key))
  return meaningful.map(([key, v]) => ({
    field: FIELD_LABELS[key] ?? key,
    from: STATUS_LABELS[v.old] ?? v.old ?? '',
    to: STATUS_LABELS[v.new] ?? v.new ?? '',
  }))
}

/** Ação de auditoria em PT */
export function auditActionLabel(action: string): string {
  switch (action) {
    case 'create': return 'Criação'
    case 'update': return 'Alteração'
    case 'delete': return 'Eliminação'
    case 'validate_effectiveness': return 'Validação de eficácia'
    case 'close': return 'Encerramento'
    case 'reopen': return 'Reabertura'
    case 'complete': return 'Conclusão de ação'
    default: return action
  }
}

/** Entidade em PT */
export function auditEntityLabel(entity: string): string {
  switch (entity) {
    case 'quality_occurrences': return 'Ocorrência'
    case 'quality_actions': return 'Ação'
    case 'quality_comments': return 'Comentário'
    case 'quality_attachments': return 'Evidência'
    default: return entity
  }
}
