// services/strategy.ts — CRUD da Plataforma Estratégica v1.5
import { supabase } from '@/lib/supabase'
import type {
  Organization, BrandKit, SwotCampaign, SwotItem, TowsCrossing,
  RiskOpportunity, StrategicObjective, StrategicAction, Kpi, KpiTarget, KpiResult,
  Meeting, Decision, GeneratedFile,
} from '@/types/strategy'

async function getUserId(): Promise<string | null> {
  const r = await supabase.auth.getSession()
  return r.data.session?.user?.id ?? null
}

// ---------- Organizações ----------
export async function listOrganizations(): Promise<Organization[]> {
  const { data, error } = await supabase.from('organizations').select('*').eq('active', true).order('name')
  if (error) throw error
  return (data ?? []) as Organization[]
}

export async function getOrganization(id: string): Promise<Organization | null> {
  const { data, error } = await supabase.from('organizations').select('*').eq('id', id).maybeSingle()
  if (error) throw error
  return data as Organization | null
}

// ---------- Brand Kits ----------
export async function getBrandKit(organizationId: string): Promise<BrandKit | null> {
  const { data, error } = await supabase
    .from('brand_kits')
    .select('*')
    .eq('organization_id', organizationId)
    .or('is_default.eq.true')
    .order('is_default', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throw error
  if(data){for(const kind of ['logo','icon','favicon']){const id=(data as any)[kind+'_asset_id'];if(id){const a=await supabase.from('brand_assets').select('mime_type,content_base64').eq('id',id).eq('organization_id',organizationId).maybeSingle();if(a.error)(data as any).asset_warning='Uma imagem não pôde ser carregada. As cores e fontes foram mantidas.';if(a.data)(data as any)[kind+'_data']=`data:${a.data.mime_type};base64,${a.data.content_base64}`}}}
  return data as BrandKit | null
}

// ---------- SWOT ----------
export async function listSwotCampaigns(organizationId: string): Promise<SwotCampaign[]> {
  const { data, error } = await supabase
    .from('swot_campaigns')
    .select('*')
    .eq('organization_id', organizationId).eq('is_demo',false).neq('status','archived')
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as SwotCampaign[]
}

export async function createSwotCampaign(payload: Partial<SwotCampaign>): Promise<SwotCampaign> {
  const created_by = await getUserId()
  const { data, error } = await supabase.from('swot_campaigns').insert({ ...payload, created_by }).select().single()
  if (error) throw error
  return data as SwotCampaign
}

export async function listSwotItems(campaignId: string): Promise<SwotItem[]> {
  const { data, error } = await supabase
    .from('swot_items')
    .select('*')
    .eq('campaign_id', campaignId)
    .order('order_index', { ascending: true })
  if (error) throw error
  return (data ?? []) as SwotItem[]
}

export async function createSwotItem(payload: Partial<SwotItem>, confirmed = false): Promise<SwotItem> {
  return reviewedWrite('swot_items', 'insert', editable(payload), confirmed)
}

export async function updateSwotItem(id: string, payload: Partial<SwotItem>, confirmed = false): Promise<SwotItem> {
  return reviewedWrite('swot_items', 'update', editable(payload), confirmed, id, payload.updated_at)
}

export async function deleteSwotItem(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('swot_items', 'delete', {}, confirmed, id, expected)
}

// ---------- TOWS ----------
export async function listTowsCrossings(campaignId: string): Promise<TowsCrossing[]> {
  const { data, error } = await supabase
    .from('tows_crossings')
    .select('*')
    .eq('campaign_id', campaignId)
    .order('strategy_type')
  if (error) throw error
  return (data ?? []) as TowsCrossing[]
}

export async function createTowsCrossing(payload: Partial<TowsCrossing>, confirmed = false): Promise<TowsCrossing> {
  return reviewedWrite('tows_crossings', 'insert', editable(payload), confirmed)
}

export async function updateTowsCrossing(id: string, payload: Partial<TowsCrossing>, confirmed = false): Promise<TowsCrossing> {
  return reviewedWrite('tows_crossings', 'update', editable(payload), confirmed, id, payload.updated_at)
}

export async function deleteTowsCrossing(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('tows_crossings', 'delete', {}, confirmed, id, expected)
}

// ---------- Riscos / Oportunidades ----------
export async function listRiskOpportunities(organizationId: string): Promise<RiskOpportunity[]> {
  const { data, error } = await supabase
    .from('risk_opportunities')
    .select('*')
    .eq('organization_id', organizationId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as RiskOpportunity[]
}

export async function createRiskOpportunity(payload: Partial<RiskOpportunity>, confirmed = false): Promise<RiskOpportunity> {
  return reviewedWrite('risk_opportunities', 'insert', editable(payload), confirmed)
}

export async function updateRiskOpportunity(id: string, payload: Partial<RiskOpportunity>, confirmed = false): Promise<RiskOpportunity> {
  return reviewedWrite('risk_opportunities', 'update', editable(payload), confirmed, id, payload.updated_at)
}

export async function deleteRiskOpportunity(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('risk_opportunities', 'delete', {}, confirmed, id, expected)
}

// ---------- Objetivos e Ações ----------
export async function listStrategicObjectives(organizationId: string): Promise<StrategicObjective[]> {
  const { data, error } = await supabase
    .from('strategic_objectives')
    .select('*')
    .eq('organization_id', organizationId)
    .order('code')
  if (error) throw error
  return (data ?? []) as StrategicObjective[]
}

export async function createStrategicObjective(payload: Partial<StrategicObjective>, confirmed = false): Promise<StrategicObjective> {
  return reviewedWrite('strategic_objectives', 'insert', editable(payload), confirmed)
}

export async function updateStrategicObjective(id: string, payload: Partial<StrategicObjective>, confirmed = false): Promise<StrategicObjective> {
  return reviewedWrite('strategic_objectives', 'update', editable(payload), confirmed, id, payload.updated_at)
}

export async function deleteStrategicObjective(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('strategic_objectives', 'delete', {}, confirmed, id, expected)
}

export async function listStrategicActions(objectiveId: string): Promise<StrategicAction[]> {
  const { data, error } = await supabase
    .from('strategic_actions')
    .select('*')
    .eq('objective_id', objectiveId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as StrategicAction[]
}

export async function createStrategicAction(payload: Partial<StrategicAction>, confirmed = false): Promise<StrategicAction> {
  return reviewedWrite('strategic_actions', 'insert', editable(payload), confirmed)
}

export async function updateStrategicAction(id: string, payload: Partial<StrategicAction>, confirmed = false): Promise<StrategicAction> {
  return reviewedWrite('strategic_actions', 'update', editable(payload), confirmed, id, payload.updated_at)
}

export async function deleteStrategicAction(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('strategic_actions', 'delete', {}, confirmed, id, expected)
}

// ---------- KPIs ----------
export async function listKpis(organizationId: string): Promise<Kpi[]> {
  const { data, error } = await supabase
    .from('kpis')
    .select('*')
    .eq('organization_id', organizationId)
    .order('code')
  if (error) throw error
  return (data ?? []) as Kpi[]
}

export async function createKpi(payload: Partial<Kpi>, confirmed = false): Promise<Kpi> {
  return reviewedWrite('kpis', 'insert', editable(payload), confirmed)
}

export async function updateKpi(id: string, payload: Partial<Kpi>, confirmed = false): Promise<Kpi> {
  return reviewedWrite('kpis', 'update', editable(payload), confirmed, id, payload.updated_at)
}

export async function deleteKpi(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('kpis', 'delete', {}, confirmed, id, expected)
}

export async function listKpiTargets(kpiId: string): Promise<KpiTarget[]> {
  const { data, error } = await supabase.from('kpi_targets').select('*').eq('kpi_id', kpiId).order('period')
  if (error) throw error
  return (data ?? []) as KpiTarget[]
}

export async function upsertKpiTarget(payload: Partial<KpiTarget>, confirmed = false): Promise<KpiTarget> {
  return reviewedWrite('kpi_targets', payload.id ? 'update' : 'insert', editable(payload), confirmed, payload.id, payload.updated_at)
}

export async function deleteKpiTarget(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('kpi_targets', 'delete', {}, confirmed, id, expected)
}

export async function listKpiResults(kpiId: string): Promise<KpiResult[]> {
  const { data, error } = await supabase.from('kpi_results').select('*').eq('kpi_id', kpiId).order('period')
  if (error) throw error
  return (data ?? []) as KpiResult[]
}

export async function upsertKpiResult(payload: Partial<KpiResult>, confirmed = false): Promise<KpiResult> {
  return reviewedWrite('kpi_results', payload.id ? 'update' : 'insert', editable(payload), confirmed, payload.id, payload.updated_at)
}

export async function deleteKpiResult(id: string, expected?: string, confirmed = false): Promise<void> {
  await reviewedWrite('kpi_results', 'delete', {}, confirmed, id, expected)
}

// ---------- Reuniões / Decisões ----------
export async function listMeetings(organizationId: string): Promise<Meeting[]> {
  const { data, error } = await supabase.from('meetings').select('*').eq('organization_id', organizationId).order('scheduled_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as Meeting[]
}

export async function listDecisions(organizationId: string): Promise<Decision[]> {
  const { data, error } = await supabase.from('decisions').select('*').eq('organization_id', organizationId).order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as Decision[]
}

// ---------- Ficheiros gerados ----------
export async function listGeneratedFiles(organizationId: string): Promise<GeneratedFile[]> {
  const { data, error } = await supabase
    .from('generated_files')
    .select('*')
    .eq('organization_id', organizationId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as GeneratedFile[]
}

// Only the reviewed RPC can write official strategic data. Timestamps come from
// the version displayed to the user, not a fresh read that would hide conflicts.
async function reviewedWrite<T>(table: string, operation: string, payload: Record<string, unknown>, confirmed: boolean, id?: string, expected?: string): Promise<T> {
  if (!confirmed) throw new Error('Confirma a revisão humana antes de guardar.')
  const { data, error } = await supabase.rpc('strategy_write', {
    p_table: table, p_operation: operation, p_payload: payload,
    p_id: id ?? null, p_expected_updated_at: expected ?? null, p_human_confirmed: confirmed,
  })
  if (error) throw error
  return data as T
}
function editable(payload: object): Record<string, unknown> {
  const excluded = new Set(['id','created_by','created_at','updated_at','score','entered_by','entered_at','closed_at','completed_at','achieved_at'])
  return Object.fromEntries(Object.entries(payload).filter(([key, value]) => !excluded.has(key) && value !== undefined).map(([key,value]) => [key, value === '' && (key.endsWith('_id') || key.endsWith('_date') || ['warning_value','reference','budget','actual_cost'].includes(key)) ? null : value]))
}
export async function listStrategyHistory(table: string, id: string) {
  const [changes,assets,people]=await Promise.all([
    supabase.from('strategy_history').select('*').eq('table_name',table).eq('record_id',id),
    supabase.from('platform_admin_history').select('*').eq('entity_type',table).eq('entity_id',id),
    supabase.from('profiles').select('id,full_name')
  ])
  if(changes.error)throw changes.error
  if(assets.error)throw assets.error
  return [...(changes.data??[]),...(assets.data??[]).map((r:any)=>({...r,operation:r.action,reviewed_at:r.created_at,reviewed_by:r.actor_id}))].map((r:any)=>({...r,actor_name:people.data?.find((p:any)=>p.id===r.reviewed_by)?.full_name||'Utilizador'})).sort((a:any,b:any)=>Date.parse(b.reviewed_at)-Date.parse(a.reviewed_at))
}
export async function listStrategyPeople(): Promise<{id: string; full_name: string}[]> {
  const {data,error} = await supabase.from('profiles').select('id,full_name').order('full_name')
  if(error) throw error
  return data ?? []
}
