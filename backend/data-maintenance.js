const crypto = require('node:crypto');
const {verifyStoredPassword} = require('./user-administration');
const groups = {
 quality: ['quality_occurrences','quality_actions','quality_attachments','quality_comments','quality_compliance_plans','quality_compliance_plan_links','quality_occurrence_categories','quality_occurrence_relations','quality_occurrence_tags','quality_plan_approval_events','quality_progress_history','quality_work_logs','quality_action_dependencies','ai_interactions'],
 lifecycle: ['lifecycle_avaliacoes','lifecycle_casos','lifecycle_certificacoes','lifecycle_competencias','lifecycle_comunicacoes','lifecycle_cv_jobs','lifecycle_entrevistas','lifecycle_experiencias','lifecycle_formacoes','lifecycle_idiomas','lifecycle_pessoas','lifecycle_projetos','lifecycle_referencias','lifecycle_tarefas','lifecycle_vagas'],
 strategy: ['swot_campaigns','swot_items','swot_contributions','tows_crossings','risk_opportunities','strategic_objectives','strategic_actions','kpis','kpi_targets','kpi_results','effectiveness_evaluations','projects','decisions','evidences','meetings','meeting_presenters','submissions','generated_files']
};
const titles={quality:'Qualidade',lifecycle:'LifeCycle RH',strategy:'Estratégia'};
const derived={swot_items:'campaign_id in (select id from swot_campaigns where organization_id=$1)',swot_contributions:'item_id in (select id from swot_items where campaign_id in (select id from swot_campaigns where organization_id=$1))',tows_crossings:'campaign_id in (select id from swot_campaigns where organization_id=$1)',strategic_actions:'objective_id in (select id from strategic_objectives where organization_id=$1)',kpi_targets:'kpi_id in (select id from kpis where organization_id=$1)',kpi_results:'kpi_id in (select id from kpis where organization_id=$1)',meeting_presenters:'meeting_id in (select id from meetings where organization_id=$1)',submissions:'meeting_id in (select id from meetings where organization_id=$1)'};
const q=s=>'"'+s.replaceAll('"','""')+'"';
const fail=(msg,status=400)=>Object.assign(new Error(msg),{status});
// Snapshot under table locks: ctids are used only inside this transaction.
async function snapshot(client,module,organization){
 const tables=groups[module];
 const fks=(await client.query(`select nc.nspname schema,cc.relname child,cp.relname parent,
 array_agg(ac.attname::text order by k.i) child_columns,array_agg(ap.attname::text order by k.i) parent_columns
 from pg_constraint c join pg_class cc on cc.oid=c.conrelid join pg_namespace nc on nc.oid=cc.relnamespace
 join pg_class cp on cp.oid=c.confrelid join pg_namespace np on np.oid=cp.relnamespace
 cross join lateral generate_subscripts(c.conkey,1) k(i)
 join pg_attribute ac on ac.attrelid=c.conrelid and ac.attnum=c.conkey[k.i]
 join pg_attribute ap on ap.attrelid=c.confrelid and ap.attnum=c.confkey[k.i]
 where c.contype='f' and np.nspname='public' and cp.relname=any($1::text[]) group by c.oid,nc.nspname,cc.relname,cp.relname`,[tables])).rows;
 const locks=[...new Set([...tables.map(t=>'public.'+q(t)),...fks.map(f=>q(f.schema)+'.'+q(f.child))])].sort();
 await client.query('LOCK TABLE '+locks.join(',')+' IN SHARE ROW EXCLUSIVE MODE');
 if(module==='lifecycle'&&(await client.query("select 1 from lifecycle_cv_jobs where organization_id=$1 and lower(status::text) not in ('done','completed','failed','cancelled','error') limit 1",[organization])).rowCount)throw fail('Existem CV em processamento ou em fila. Aguarda a conclusão antes de limpar.',409);
 const counts={},digest=crypto.createHash('sha256');
 for(const table of tables){
  await client.query(`CREATE TEMP TABLE ${q('reset_'+table)} ON COMMIT DROP AS SELECT ctid as __reset_tid,t.* FROM public.${q(table)} t WHERE ${derived[table]||'organization_id=$1'}`,[organization]);
  const result=(await client.query(`select count(*)::int n,md5(coalesce(string_agg(h,',' order by h),'')) digest from (select md5((to_jsonb(t)-'__reset_tid')::text) h from ${q('reset_'+table)} t) hashes`)).rows[0];
  counts[table]=result.n;digest.update(table+':'+result.digest);
 }
 for(const fk of fks){
  const join=fk.child_columns.map((c,i)=>`c.${q(c)}=p.${q(fk.parent_columns[i])}`).join(' and ');
  const selected=fk.schema==='public'&&tables.includes(fk.child)?`and not exists(select 1 from ${q('reset_'+fk.child)} s where s.__reset_tid=c.ctid)`:'';
  if((await client.query(`select 1 from ${q(fk.schema)}.${q(fk.child)} c join ${q('reset_'+fk.parent)} p on ${join} where true ${selected} limit 1`)).rowCount)throw fail(`Existem ligações a registos preservados (${fk.child}). Remove essas ligações antes de limpar este programa.`,409);
 }
 const remaining=new Set(tables),order=[];
 while(remaining.size){const next=[...remaining].find(t=>!fks.some(f=>f.schema==='public'&&f.parent===t&&f.child!==t&&remaining.has(f.child)));if(!next)throw fail('Existem dependências circulares; a limpeza foi bloqueada.',409);order.push(next);remaining.delete(next)}
 return {counts,fingerprint:digest.digest('hex'),order};
}
function createDataMaintenance({pool,verifyJwt,readBody,send}){
 const previews=new Map(),attempts=new Map();
 return async(req,res,path)=>{
  if(!path.startsWith('/auth/v1/admin/data-reset'))return false;
  let client;
  try{
   if(req.method!=='POST'||!['/auth/v1/admin/data-reset/preview','/auth/v1/admin/data-reset/execute'].includes(path))throw fail('Operação inválida.',405);
   const claims=verifyJwt((req.headers.authorization||'').replace(/^Bearer\s+/i,''));
   if(!claims||claims.type==='refresh_token')throw fail('Sessão inválida.',401);
   const body=await readBody(req),execute=path.endsWith('/execute');
   if(body.module==='quality')throw fail('A baseline v2.5 preserva os dados de Qualidade. Utiliza Anular na ocorrência ou ação; a limpeza definitiva está desativada.',409);
   if(!Object.hasOwn(groups,body.module)||!/^[-0-9a-f]{36}$/i.test(body.organization_id||''))throw fail('Seleciona uma empresa e um programa válidos.');
   client=await pool.connect();await client.query('BEGIN');await client.query("SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='30s'");
   const actor=(await client.query('select * from profiles where id=$1 for update',[claims.sub])).rows[0];
   if(!actor?.active||actor.role!=='admin'||actor.session_version!==(claims.sv??0))throw fail('Apenas administradores com sessão válida podem limpar dados.',403);
   if(!actor.is_super_admin&&actor.organization_id!==body.organization_id)throw fail('Só podes limpar os dados da tua empresa.',403);
   const org=(await client.query('select id,name from organizations where id=$1 for share',[body.organization_id])).rows[0];if(!org)throw fail('Empresa não encontrada.',404);
   for(const [key,p] of previews)if(p.expires<Date.now())previews.delete(key);
   const phrase=`APAGAR ${titles[body.module]} — ${org.name}`;
   let previous;
   if(execute){
    previous=previews.get(body.token);
    if(!previous||previous.actor!==actor.id||previous.organization!==org.id||previous.module!==body.module||previous.version!==actor.session_version)throw fail('A pré-visualização expirou. Volta a verificar os dados.',409);
    if(body.confirmation!==phrase)throw fail('Escreve a frase de confirmação exatamente como apresentada.');
    for(const [key,a] of attempts)if(a.expires<Date.now())attempts.delete(key);
    const attempt=attempts.get(actor.id)||{count:0,expires:Date.now()+900000};
    if(attempt.count>=5)throw fail('Demasiadas senhas incorretas. Aguarda 15 minutos.',429);
    const user=(await client.query('select id,password_hash from auth.users where id=$1',[actor.id])).rows[0];
    if(!verifyStoredPassword(user,body.password)){attempt.count++;attempts.set(actor.id,attempt);throw fail('Senha incorreta.',403)}
    attempts.delete(actor.id);
   }
   const state=await snapshot(client,body.module,org.id);
   if(!execute){
    await client.query('ROLLBACK');const token=crypto.randomBytes(32).toString('hex');
    // One outstanding preview per administrator, bounded lifetime and memory.
    for(const [key,p] of previews)if(p.actor===actor.id)previews.delete(key);
    previews.set(token,{actor:actor.id,version:actor.session_version,organization:org.id,module:body.module,fingerprint:state.fingerprint,expires:Date.now()+300000});
    send(res,200,{token,counts:state.counts,confirmation:phrase,expires_in:300});
   }else{
    if(previous.fingerprint!==state.fingerprint)throw fail('Os dados mudaram. Volta a pré-visualizar antes de apagar.',409);
    await client.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({...claims,role:'authenticated'})]);
    for(const table of state.order)await client.query(`DELETE FROM public.${q(table)} WHERE ctid in (select __reset_tid from ${q('reset_'+table)})`);
    await client.query('insert into data_reset_history(actor_id,organization_id,module,record_counts) values($1,$2,$3,$4)',[actor.id,org.id,body.module,state.counts]);
    await client.query('COMMIT');previews.delete(body.token);send(res,200,{counts:state.counts,msg:`Dados de ${titles[body.module]} apagados para ${org.name}.`});
   }
  }catch(e){if(client)await client.query('ROLLBACK').catch(()=>{});send(res,e.status||409,{msg:e.status?e.message:'Não foi possível concluir a limpeza. Nenhum dado foi apagado; tenta novamente ou verifica as dependências.'})}finally{client?.release()}
  return true;
 };
}
module.exports={createDataMaintenance,snapshot,groups};


