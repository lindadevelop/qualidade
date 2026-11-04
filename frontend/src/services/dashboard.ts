import {API_BASE} from '@/lib/api-base'
// Métricas agregadas do dashboard — via RPC no PostgreSQL (nunca descarregar registos)
import { supabase } from '@/lib/supabase'

export interface DashboardMetrics {
  open_nc: number
  open_om: number
  overdue_actions: number
  awaiting_effectiveness: number
  closed: number
  total_actions_open: number
}

export async function fetchDashboardMetrics(): Promise<DashboardMetrics> {
  const { data, error } = await supabase.rpc('get_dashboard_metrics')
  if (error) throw error
  return (data ?? {}) as DashboardMetrics
}

export async function fetchEvolution(months = 12) {
  const { data, error } = await supabase.rpc('get_occurrence_evolution', { months })
  if (error) throw error
  return (data ?? []) as { period: string; type: string; cnt: number }[]
}

export async function fetchByStatus() {
  const { data, error } = await supabase.rpc('get_occurrences_by_status')
  if (error) throw error
  return (data ?? []) as { status: string; cnt: number }[]
}

export async function fetchByOrigin() {
  const { data, error } = await supabase.rpc('get_occurrences_by_origin')
  if (error) throw error
  return (data ?? []) as { origin_name: string; cnt: number }[]
}

export async function fetchByArea() {
  const { data, error } = await supabase.rpc('get_occurrences_by_area')
  if (error) throw error
  return (data ?? []) as { area_name: string; cnt: number }[]
}

export async function fetchActionsByResponsible() {
  const { data, error } = await supabase.rpc('get_actions_by_responsible')
  if (error) throw error
  return (data ?? []) as { full_name: string; total: number; open_cnt: number; overdue: number; completed: number }[]
}

export async function fetchUrgentActions(limit = 8) {
  const { data, error } = await supabase.rpc('get_urgent_actions', { limit_n: limit })
  if (error) throw error
  return (data ?? []) as {
    action_id: string; action_ref: string; action_description: string
    occurrence_ref: string; occurrence_id: string; responsible: string | null
    deadline: string | null; status: string; urgency: number
  }[]
}

/** Saúde operacional da Qualidade (Copiloto) — via tool MCP /mcp/tools/call. */
export async function fetchQualityHealth(): Promise<any | null> { // eslint-disable-line @typescript-eslint/no-explicit-any
  const { data: s } = await supabase.auth.getSession()
  const token = s.session?.access_token
  if (!token) throw new Error('Sessão inválida')
  const res = await fetch(`${API_BASE}/mcp/tools/call`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, apikey: import.meta.env.VITE_SUPABASE_ANON_KEY },
    body: JSON.stringify({ name: 'get_quality_health_check', args: {} }),
  })
  if (!res.ok) return null
  const r = await res.json()
  return r.ok ? r.data : null
}
