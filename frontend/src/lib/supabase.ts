import {API_BASE} from '@/lib/api-base'
// Cliente Supabase — frontend usa apenas URL + anon key (nunca service role)
// NOTA: tipos funcionais ("supabase gen types typescript" no projeto real) devem substituir
// o GenericSchema. Por agora o cliente é tipado genericamente (any) e os tipos de domínio
// vivem em src/types e são aplicados nas camadas de serviço.
import { createClient } from '@supabase/supabase-js'

const url = API_BASE as string
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY as string

export const isSupabaseConfigured = Boolean(url && anon)

export const supabase = createClient(url || 'http://localhost:54321', anon || 'anon', {
  global: { fetch: (input, init) => {
    const headers = new Headers(init?.headers)
    const organization = localStorage.getItem('samsys-qualidade:active-organization-id')
    if (organization && (input instanceof Request ? input.url : String(input)).includes('/rest/v1/')) headers.set('x-organization-id', organization)
    return fetch(input, { ...init, headers })
  } },
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})