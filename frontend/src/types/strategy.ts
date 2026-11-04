// Tipos de domínio da Plataforma Estratégica v1.5

export interface Organization {
  id: string
  name: string
  slug?: string | null
  description?: string | null
  tax_id?: string | null
  website?: string | null
  email?: string | null
  phone?: string | null
  address?: string | null
  city?: string | null
  country?: string | null
  logo_url?: string | null
  primary_color?: string | null
  secondary_color?: string | null
  active?: boolean
  created_at?: string
  updated_at?: string
}

export interface BrandKit {
  id: string
  organization_id: string
  name: string
  is_default: boolean
  primary_color: string
  secondary_color: string
  background_color: string
  text_color: string
  accent_color: string
  danger_color: string
  warning_color: string
  info_color: string
  success_color: string
  logo_url?: string | null
  font_heading: string
  font_body: string
}

export interface SwotCampaign {
  id: string
  organization_id: string
  cycle_id?: string | null
  name: string
  description?: string | null
  status: string
  starts_at?: string | null
  ends_at?: string | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export type SwotQuadrant = 'strengths' | 'weaknesses' | 'opportunities' | 'threats'

export const QUADRANT_LABEL: Record<SwotQuadrant, string> = {
  strengths: 'Forças',
  weaknesses: 'Fraquezas',
  opportunities: 'Oportunidades',
  threats: 'Ameaças',
}

export const QUADRANT_ICON: Record<SwotQuadrant, string> = {
  strengths: 'S',
  weaknesses: 'W',
  opportunities: 'O',
  threats: 'T',
}

export interface SwotItem {
  id: string
  campaign_id: string
  quadrant: SwotQuadrant
  title: string
  description?: string | null
  impact?: string | null
  probability?: string | null
  order_index?: number
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export type TowsStrategyType = 'so' | 'wo' | 'st' | 'wt'

export const TOWS_LABEL: Record<TowsStrategyType, string> = {
  so: 'SO — Forças + Oportunidades',
  wo: 'WO — Fraquezas + Oportunidades',
  st: 'ST — Forças + Ameaças',
  wt: 'WT — Fraquezas + Ameaças',
}

export interface TowsCrossing {
  disposition?: 'monitor' | 'not_relevant' | 'risk' | 'opportunity'
  id: string
  campaign_id: string
  strategy_type: TowsStrategyType
  name: string
  description?: string | null
  priority?: string | null
  s_item_id?: string | null
  w_item_id?: string | null
  o_item_id?: string | null
  t_item_id?: string | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export type RiskOpportunityType = 'risk' | 'opportunity'
export type RiskOpportunityStatus = 'identified' | 'analyzing' | 'mitigating' | 'monitored' | 'closed'

export interface RiskOpportunity {
  source_tows_id?: string | null
  id: string
  organization_id: string
  cycle_id?: string | null
  reference?: string | null
  type: RiskOpportunityType
  title: string
  description?: string | null
  probability?: number | null
  impact?: number | null
  score?: number | null
  status: RiskOpportunityStatus
  mitigation?: string | null
  responsible_id?: string | null
  due_date?: string | null
  closed_at?: string | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export type StrategicObjectiveStatus = 'draft' | 'approved' | 'active' | 'achieved' | 'cancelled'

export interface StrategicObjective {
  risk_ids?: string[]
  id: string
  organization_id: string
  cycle_id?: string | null
  parent_id?: string | null
  code: string
  name: string
  description?: string | null
  perspective?: string | null
  weight?: number
  status: StrategicObjectiveStatus
  progress?: number
  responsible_id?: string | null
  start_date?: string | null
  due_date?: string | null
  achieved_at?: string | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export type StrategicActionStatus = 'todo' | 'in_progress' | 'completed' | 'cancelled'

export interface StrategicAction {
  id: string
  objective_id: string
  name: string
  description?: string | null
  status: StrategicActionStatus
  priority?: string | null
  responsible_id?: string | null
  start_date?: string | null
  due_date?: string | null
  completed_at?: string | null
  progress?: number
  budget?: number | null
  actual_cost?: number | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export type KpiDirection = 'higher_is_better' | 'lower_is_better' | 'target'
export type KpiFrequency = 'daily' | 'weekly' | 'monthly' | 'quarterly' | 'yearly'

export interface Kpi {
  id: string
  organization_id: string
  objective_id?: string | null
  code: string
  name: string
  description?: string | null
  unit?: string | null
  direction?: KpiDirection
  frequency?: KpiFrequency
  formula?: string | null
  data_source?: string | null
  responsible_id?: string | null
  active?: boolean
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export interface KpiTarget {
  id: string
  kpi_id: string
  period: string
  target_value: number
  warning_value?: number | null
  created_at?: string
  updated_at?: string
}

export interface KpiResult {
  id: string
  kpi_id: string
  period: string
  value: number
  notes?: string | null
  entered_by?: string | null
  entered_at?: string
  created_at?: string
  updated_at?: string
}

export interface Meeting {
  id: string
  organization_id: string
  cycle_id?: string | null
  title: string
  description?: string | null
  meeting_type?: string | null
  status: string
  scheduled_at: string
  duration_min?: number | null
  location?: string | null
  online_url?: string | null
  minutes?: string | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export interface Decision {
  id: string
  organization_id: string
  meeting_id?: string | null
  code?: string | null
  title: string
  description?: string | null
  rationale?: string | null
  status: string
  impact_level?: string | null
  decided_by?: string | null
  decided_at?: string | null
  implemented_at?: string | null
  created_by?: string | null
  created_at?: string
  updated_at?: string
}

export interface GeneratedFile {
  id: string
  organization_id: string
  template_id?: string | null
  meeting_id?: string | null
  name: string
  file_type: string
  file_path?: string | null
  file_size?: number | null
  status: string
  error_message?: string | null
  generated_by?: string | null
  generated_at?: string
  created_at?: string
  updated_at?: string
}
