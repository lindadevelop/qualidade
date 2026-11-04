import {supabase} from '@/lib/supabase'
import {API_BASE} from '@/lib/api-base'
export async function strategyAdmin(path:string,body?:unknown){
 const {data:{session}}=await supabase.auth.getSession();if(!session)throw new Error('Inicia sessão novamente.')
 const r=await fetch(`${API_BASE}/auth/v1/strategy-admin/${path}`,{method:body?'POST':'GET',headers:{Authorization:`Bearer ${session.access_token}`,'Content-Type':'application/json','x-organization-id':localStorage.getItem('samsys-qualidade:active-organization-id')||''},body:body?JSON.stringify(body):undefined})
 const data=await r.json();if(!r.ok)throw new Error(data.msg||'Não foi possível concluir.');return data
}
export const strategyAdminCommand=(operation:string,id:string|null,payload:any)=>strategyAdmin('command',{operation,id,payload})
