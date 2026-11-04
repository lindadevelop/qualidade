import type { KpiDirection, KpiFrequency, SwotItem, TowsCrossing } from '../types/strategy'

export function required(value: unknown, label: string): string {
  if (typeof value !== 'string' || !value.trim()) throw new Error(`${label} é obrigatório.`)
  return value.trim()
}
export function numberInRange(value: unknown, label: string, min = -Infinity, max = Infinity): number {
  if (value === '' || value == null || !Number.isFinite(Number(value))) throw new Error(`${label}: indica um número válido.`)
  const n = Number(value)
  if (n < min || n > max) throw new Error(`${label}: valor entre ${min} e ${max}.`)
  return n
}
export function validatePeriod(period: unknown, frequency: KpiFrequency = 'monthly'): string {
  const p = required(period, 'Período')
  const patterns = { daily: /^\d{4}-\d{2}-\d{2}$/, weekly: /^\d{4}-W(0[1-9]|[1-4]\d|5[0-3])$/, monthly: /^\d{4}-(0[1-9]|1[0-2])$/, quarterly: /^\d{4}-Q[1-4]$/, yearly: /^\d{4}$/ }
  if (!patterns[frequency].test(p)) throw new Error('Período incompatível com a frequência do KPI.')
  if (frequency === 'daily' && (Number.isNaN(Date.parse(p)) || new Date(p).toISOString().slice(0, 10) !== p)) throw new Error('Data inválida.')
  if (frequency === 'weekly' && p.endsWith('W53')) {
    const jan1 = new Date(`${p.slice(0, 4)}-01-01T00:00:00Z`).getUTCDay()
    const year = Number(p.slice(0, 4)); const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0)
    if (jan1 !== 4 && !(jan1 === 3 && leap)) throw new Error('Este ano não tem semana ISO 53.')
  }
  return p
}
export function kpiAssessment(value: number | null | undefined, target: number | null | undefined, warning: number | null | undefined, direction: KpiDirection = 'higher_is_better'): string {
  if (value == null) return 'Sem resultado'
  if (target == null) return 'Sem meta'
  const v = Number(value), t = Number(target), w = warning == null ? null : Number(warning)
  if (direction === 'target') return v === t ? 'Cumprido' : w != null && Math.abs(v - t) <= Math.abs(w) ? 'Em alerta' : 'Desvio'
  if (direction === 'lower_is_better') return v <= t ? 'Cumprido' : w != null && v <= w ? 'Em alerta' : 'Desvio'
  return v >= t ? 'Cumprido' : w != null && v >= w ? 'Em alerta' : 'Desvio'
}
export function normalizeCrossing(value: Partial<TowsCrossing>, items: SwotItem[]): Partial<TowsCrossing> {
  const p = { ...value, name: required(value.name, 'Nome'), s_item_id: null, w_item_id: null, o_item_id: null, t_item_id: null } as Partial<TowsCrossing>
  const pairs = { so: ['s_item_id', 'o_item_id'], wo: ['w_item_id', 'o_item_id'], st: ['s_item_id', 't_item_id'], wt: ['w_item_id', 't_item_id'] } as const
  const quadrants = { s_item_id: 'strengths', w_item_id: 'weaknesses', o_item_id: 'opportunities', t_item_id: 'threats' }
  if (!value.strategy_type || !pairs[value.strategy_type]) throw new Error('Tipo TOWS inválido.')
  for (const key of pairs[value.strategy_type]) {
    const item = items.find(i => i.id === value[key] && i.campaign_id === value.campaign_id && i.quadrant === quadrants[key])
    if (!item) throw new Error('Seleciona os dois fatores SWOT válidos da campanha.')
    p[key] = item.id
  }
  return p
}
