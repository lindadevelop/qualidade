import { supabase } from '@/lib/supabase'
import {platformModules, type ModuleDefinition} from '@/domain/platform-modules'
export type PlatformRow=Record<string,any> & {id:string;updated_at:string}
export async function listModule(def:ModuleDefinition,organizationId:string):Promise<PlatformRow[]> {
 let query=supabase.from(def.table).select(def.table==='meeting_presenters'?'*,meetings!inner(organization_id)':'*')
 if(!def.global) query=query.eq(def.table==='meeting_presenters'?'meetings.organization_id':'organization_id',organizationId)
 const {data,error}=await query.order(def.table==='meetings'?'scheduled_at':'created_at',{ascending:false})
 if(error)throw error;return (data??[]) as unknown as PlatformRow[]
}
export async function moduleOptions(organizationId:string) {
 const tables=['profiles','frameworks','cycles','meetings']
 const rows=await Promise.all(tables.map(async table=>{
  if(table==='profiles'){const {data,error}=await supabase.from('profiles').select('id,full_name,active').eq('organization_id',organizationId).order('full_name');if(error)throw error;return data??[]}
  if(!organizationId)return []
  return listModule(platformModules[table]!,organizationId)
 }))
 return Object.fromEntries(tables.map((t,i)=>[t,rows[i]!.map((r:Record<string,any>)=>({value:r.id,label:(r.full_name||r.title||r.name)+(r.active===false?' (inativo)':''),active:r.active}))]))
}
export async function saveModule(table:string,payload:Record<string,unknown>,confirmed:boolean,existing?:PlatformRow):Promise<PlatformRow> {
 if(!confirmed)throw new Error('Confirma a revisão dos dados.')
 const {data,error}=await supabase.rpc('platform_module_write',{p_table:table,p_payload:payload,p_id:existing?.id??null,p_expected_updated_at:existing?.updated_at??null,p_human_confirmed:confirmed})
 if(error){if(error.code==='23505'&&table==='organization_memberships')throw new Error('Este utilizador já é membro. Em Administração geral → Utilizadores, edita a ficha para acrescentar equipas e funções.');if(error.code==='23505')throw new Error('Já existe um registo com este código, identificador ou associação.');throw error}
 return data as PlatformRow
}

