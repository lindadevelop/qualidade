// Tipos da base de dados Supabase — SAMSYS|Qualidade
// Podem ser regenerados com: supabase gen types typescript --project-id <id> > src/types/database.ts

export type ProfileRole = 'quality' | 'action_owner' | 'management' | 'admin'
export type OccurrenceType = 'NC' | 'OM'
export type OccurrenceStatus = 'OPEN' | 'IN_PROGRESS' | 'AWAITING_EFFECTIVENESS' | 'CLOSED'
export type ActionStatus = 'TODO' | 'IN_PROGRESS' | 'COMPLETED'
export type EffectivenessStatus = 'EFFECTIVE' | 'NOT_EFFECTIVE'

export interface Profile {
  is_super_admin: boolean
  organization_id: string | null
  module_access: { quality: boolean; strategy: boolean; lifecycle: boolean }

  id: string
  full_name: string | null
  email: string | null
  avatar_url: string | null
  role: ProfileRole
  department: string | null
  job_title: string | null
  active: boolean
  created_at: string
  updated_at: string
}

export interface QualityArea {
  id: string
  name: string
  description: string | null
  active: boolean
  sort_order: number
  created_at: string
  updated_at: string
}

export interface QualityOrigin {
  id: string
  name: string
  description: string | null
  active: boolean
  sort_order: number
  created_at: string
  updated_at: string
}

export interface QualityOccurrence {
  id: string
  reference: string
  type: OccurrenceType
  year: number
  origin_id: string
  occurrence_date: string
  area_id: string
  description: string
  responsible_user_id: string | null
  cause_analysis: string | null
  status: OccurrenceStatus
  effectiveness_status: EffectivenessStatus | null
  effectiveness_notes: string | null
  effectiveness_evidence: unknown | null
  effectiveness_validated_by: string | null
  effectiveness_validated_at: string | null
  closed_at: string | null
  reopened_at: string | null
  reopened_by: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface QualityAction {
  id: string
  reference: string
  occurrence_id: string
  description: string
  responsible_user_id: string | null
  deadline: string | null
  status: ActionStatus
  completed_at: string | null
  created_by: string | null
  created_at: string
  updated_at: string
  // Fase 1 — Copiloto operacional
  plano_id?: string | null
  titulo?: string | null
  tipo?: string | null
  prioridade?: string | null
  criticidade?: string | null
  data_inicio?: string | null
  horas_previstas?: number | null
  horas_realizadas?: number | null
  percent_execucao?: number | null
  progresso_origem?: string | null
  resultado_esperado?: string | null
  resultado_real?: string | null
  bloqueio_motivo?: string | null
  verificar_eficacia?: boolean | null
  eficacia_validada?: boolean | null
  evidencias_obrigatorias?: boolean | null
  proposal_por_ia?: boolean | null
}

export interface QualityAttachment {
  id: string
  occurrence_id: string | null
  action_id: string | null
  file_name: string
  file_path: string
  file_type: string | null
  file_size: number | null
  description: string | null
  uploaded_by: string | null
  created_at: string
}

export interface QualityComment {
  id: string
  occurrence_id: string
  action_id: string | null
  comment: string
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface AuditLogEntry {
  id: string
  entity_type: string
  entity_id: string | null
  action: string
  old_data: Record<string, unknown> | null
  new_data: Record<string, unknown> | null
  changed_fields: Record<string, { old: string; new: string }> | null
  user_id: string | null
  created_at: string
}

export interface Notification {
  link?: string | null
  id: string
  user_id: string
  type: string
  title: string
  message: string | null
  entity_type: string | null
  entity_id: string | null
  read: boolean
  created_at: string
}

export interface FeatureFlag {
  id: string
  key: string
  enabled: boolean
  created_at: string
  updated_at: string
}

export interface Organization {
  id: string
  name: string
  slug?: string | null
  description?: string | null
  primary_color?: string | null
  secondary_color?: string | null
  active: boolean
  created_at: string
  updated_at: string
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
  font_heading: string
  font_body: string
}

// Minimalista — suficiente para tipar o cliente; expandir com `supabase gen types`.
type AnyArgs = Record<string, unknown>
export interface Database {
  public: {
    Tables: {
      profiles: { Row: Profile; Insert: Partial<Profile>; Update: Partial<Profile>; Relationships: [] }
      quality_areas: { Row: QualityArea; Insert: Partial<QualityArea>; Update: Partial<QualityArea>; Relationships: [] }
      quality_origins: { Row: QualityOrigin; Insert: Partial<QualityOrigin>; Update: Partial<QualityOrigin>; Relationships: [] }
      quality_occurrences: { Row: QualityOccurrence; Insert: Partial<QualityOccurrence>; Update: Partial<QualityOccurrence>; Relationships: [] }
      quality_actions: { Row: QualityAction; Insert: Partial<QualityAction>; Update: Partial<QualityAction>; Relationships: [] }
      quality_attachments: { Row: QualityAttachment; Insert: Partial<QualityAttachment>; Update: Partial<QualityAttachment>; Relationships: [] }
      quality_comments: { Row: QualityComment; Insert: Partial<QualityComment>; Update: Partial<QualityComment>; Relationships: [] }
      audit_log: { Row: AuditLogEntry; Insert: Partial<AuditLogEntry>; Update: Partial<AuditLogEntry>; Relationships: [] }
      organizations: { Row: Organization; Insert: Partial<Organization>; Update: Partial<Organization>; Relationships: [] }
      brand_kits: { Row: BrandKit; Insert: Partial<BrandKit>; Update: Partial<BrandKit>; Relationships: [] }
      swot_campaigns: { Row: any; Insert: any; Update: any; Relationships: [] }
      swot_items: { Row: any; Insert: any; Update: any; Relationships: [] }
      tows_crossings: { Row: any; Insert: any; Update: any; Relationships: [] }
      risk_opportunities: { Row: any; Insert: any; Update: any; Relationships: [] }
      strategic_objectives: { Row: any; Insert: any; Update: any; Relationships: [] }
      strategic_actions: { Row: any; Insert: any; Update: any; Relationships: [] }
      kpis: { Row: any; Insert: any; Update: any; Relationships: [] }
      kpi_targets: { Row: any; Insert: any; Update: any; Relationships: [] }
      kpi_results: { Row: any; Insert: any; Update: any; Relationships: [] }
      meetings: { Row: any; Insert: any; Update: any; Relationships: [] }
      decisions: { Row: any; Insert: any; Update: any; Relationships: [] }
      generated_files: { Row: any; Insert: any; Update: any; Relationships: [] }
      notifications: { Row: Notification; Insert: Partial<Notification>; Update: Partial<Notification>; Relationships: [] }
      feature_flags: { Row: FeatureFlag; Insert: Partial<FeatureFlag>; Update: Partial<FeatureFlag>; Relationships: [] }
    }
    Views: Record<string, never>
    Functions: {
      get_dashboard_metrics: { Args: AnyArgs; Returns: Record<string, number> }
      get_occurrence_evolution: { Args: { months: number }; Returns: { period: string; type: string; cnt: number }[] }
      get_occurrences_by_status: { Args: AnyArgs; Returns: { status: string; cnt: number }[] }
      get_occurrences_by_origin: { Args: AnyArgs; Returns: { origin_name: string; cnt: number }[] }
      get_occurrences_by_area: { Args: AnyArgs; Returns: { area_name: string; cnt: number }[] }
      get_actions_by_responsible: { Args: AnyArgs; Returns: unknown[] }
      get_urgent_actions: { Args: { limit_n: number }; Returns: unknown[] }
    }
    Enums: {
      profile_role: ProfileRole
      occurrence_type: OccurrenceType
      occurrence_status: OccurrenceStatus
      action_status: ActionStatus
    }
    CompositeTypes: Record<string, never>
  }
}