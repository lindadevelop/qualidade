const crypto=require('node:crypto');
const fail=(message,status=400)=>{throw Object.assign(new Error(message),{status})};
const active="a.active and (a.starts_on is null or a.starts_on<=current_date) and (a.ends_on is null or a.ends_on>=current_date)";
const manager=a=>a.role==='admin'||a.roles?.includes('quality');
async function audit(c,actor,org,id,action,after){await c.query("insert into platform_admin_history(organization_id,entity_type,entity_id,action,after_data,actor_id) values($1,'swot_campaigns',$2,$3,$4,$5)",[org,id,action,after,actor.id])}
async function ensureContexts(c,campaign,org,userIds){
 if(campaign.collection_revision!==2||campaign.quota_mode==='legacy')return;
 if(!userIds)userIds=(await c.query(`select distinct p.id from profiles p join swot_campaign_audience s on s.campaign_id=$1 and (s.user_id=p.id or s.team_id in(select a.team_id from user_assignments a where a.user_id=p.id and a.kind='team' and ${active})) where p.organization_id=$2 and p.active`,[campaign.id,org])).rows.map(r=>r.id);
 for(const user of userIds){
  if((await c.query('select 1 from swot_participant_contexts where campaign_id=$1 and user_id=$2',[campaign.id,user])).rowCount)continue;
  const teams=(await c.query(`select distinct t.id,t.name from teams t join user_assignments a on a.team_id=t.id where a.user_id=$1 and a.organization_id=$2 and a.kind='team' and ${active} and t.active and (exists(select 1 from swot_campaign_audience where campaign_id=$3 and user_id=$1) or not exists(select 1 from swot_campaign_audience where campaign_id=$3 and team_id is not null) or exists(select 1 from swot_campaign_audience where campaign_id=$3 and team_id=t.id))`,[user,org,campaign.id])).rows;
  for(const t of [...teams,{id:null,name:'Organização / Corporativa'}])await c.query('insert into swot_participant_contexts(organization_id,campaign_id,user_id,team_id,label) values($1,$2,$3,$4,$5) on conflict do nothing',[org,campaign.id,user,t.id,t.name]);
 }
}
async function participantProgress(c,id){
 const contexts=(await c.query("select x.*,p.full_name,c.min_own,c.max_own,c.min_other,c.max_other,(select count(*)::int from swot_contributions r where r.campaign_id=x.campaign_id and r.user_id=x.user_id and ((x.team_id is null and r.contribution_scope='organization') or (x.team_id=r.team_id and r.contribution_scope='own_team'))) realized from swot_participant_contexts x join profiles p on p.id=x.user_id join swot_campaigns c on c.id=x.campaign_id where x.campaign_id=$1 order by p.full_name,x.label",[id])).rows;
 const submitted=(await c.query('select * from swot_submissions where campaign_id=$1',[id])).rows;
 const users=[];for(const x of contexts){let u=users.find(u=>u.user_id===x.user_id);if(!u){const completion=submitted.find(s=>s.user_id===x.user_id);u={user_id:x.user_id,name:x.full_name,contexts:[],completion,state:completion?(completion.completion_type==='exception'?'exception':'completed'):'not_started'};users.push(u)}const recommended=x.team_id?x.min_own:x.min_other,max=x.team_id?x.max_own:x.max_other;u.contexts.push({team_id:x.team_id,label:x.label,realized:x.realized,recommended,max,remaining:Math.max(0,recommended-x.realized)});if(!u.completion&&x.realized>0)u.state='in_progress'}return users;
}
async function addEntry(c,actor,org,campaign,p,{imported=false,batch=null}={}){
 const userId=p.author_id||actor.id;if(userId!==actor.id&&!manager(actor))fail('Não podes registar em nome de outro participante.',403);
 const author=(await c.query("select id,full_name from profiles where id=$1 and organization_id=$2 and active and (role='admin' or module_access->>'strategy'='true')",[userId,org])).rows[0];if(!author)fail('Autor: seleciona um utilizador ativo desta empresa com acesso à Estratégia.');
 if(!(await c.query('select 1 from swot_participant_contexts where campaign_id=$1 and user_id=$2',[campaign.id,userId])).rowCount){
  if(!(manager(actor)&&userId===actor.id))fail('Autor: o utilizador não está incluído nesta campanha.');await ensureContexts(c,campaign,org,[userId]);
 }
 if((await c.query('select 1 from swot_submissions where campaign_id=$1 and user_id=$2',[campaign.id,userId])).rowCount)fail('A participação deste autor já foi concluída.');
 if(!['strengths','weaknesses','opportunities','threats'].includes(p.quadrant))fail('Quadrante: seleciona uma opção válida.');
 if(typeof p.contribution!=='string'||!p.contribution.trim()||p.contribution.length>10000)fail('Texto: preenche entre 1 e 10000 caracteres.');
 if(!['own_team','organization','other_team'].includes(p.contribution_scope))fail('Contexto: seleciona uma opção válida.');
 if(!(await c.query('select 1 from strategy_thematic_areas where id=$1 and organization_id=$2 and active',[p.thematic_area_id||null,org])).rowCount)fail('Área temática: seleciona uma área ativa desta empresa.');
 const own=(await c.query('select team_id from swot_participant_contexts where campaign_id=$1 and user_id=$2 and team_id is not null',[campaign.id,userId])).rows.map(r=>r.team_id);
 if(p.contribution_scope==='organization'){if(p.team_id)fail('Equipa: a componente corporativa não tem equipa alvo.');}
 else{if(!(await c.query('select 1 from teams where id=$1 and organization_id=$2 and active',[p.team_id||null,org])).rowCount)fail('Equipa: seleciona uma equipa ativa.');if((p.contribution_scope==='own_team')!==own.includes(p.team_id))fail('Contexto: a equipa não corresponde a uma equipa representada ou a outra equipa.');}
 if(p.contribution_scope!=='own_team'&&!(await c.query('select 1 from swot_campaign_validators where campaign_id=$1 and team_id is not distinct from $2::uuid',[campaign.id,p.team_id||null])).rowCount)fail('Validação: configura um responsável para este contexto.');
 const n=(await c.query('select count(*)::int n from swot_contributions where campaign_id=$1 and user_id=$2 and contribution_scope=$3 and team_id is not distinct from $4::uuid',[campaign.id,userId,p.contribution_scope,p.team_id||null])).rows[0].n;
 if(n>=(p.contribution_scope==='organization'?campaign.max_other:campaign.max_own))fail('Máximo atingido neste contexto. O coordenador deve ajustar a regra antes de continuar.');
 const row=(await c.query('insert into swot_contributions(campaign_id,organization_id,quadrant,user_id,contribution,team_id,source,author_label,thematic_area_id,contribution_scope,imported_by,import_batch_id) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) returning *',[campaign.id,org,p.quadrant,userId,p.contribution.trim(),p.team_id||null,imported?'Importação de folha de cálculo':'Aplicação',author.full_name,p.thematic_area_id,p.contribution_scope,imported?actor.id:null,batch])).rows[0];return row;
}
async function revisionCommand(c,actor,org,op,campaign,p){
 if(campaign.collection_revision!==2||campaign.quota_mode==='legacy')return undefined;
 if(!['contribution_add','contribution_import','participation_submit','participation_exception'].includes(op))return undefined;
 if(op==='participation_exception'){if(!['open','validation'].includes(campaign.status))fail('A campanha deve estar em recolha ou validação.');}
 else if(campaign.status!=='open'||campaign.starts_at&&Date.now()<+campaign.starts_at||campaign.ends_at&&Date.now()>+campaign.ends_at)fail('A recolha não está aberta neste período.');
 await ensureContexts(c,campaign,org);
 if(op==='participation_submit'||op==='participation_exception'){
  const exception=op==='participation_exception';if(exception&&!manager(actor))fail('Só o coordenador pode autorizar uma exceção.',403);const user=exception?p.user_id:actor.id;
  const progress=(await participantProgress(c,campaign.id)).find(u=>u.user_id===user);if(!progress)fail('Participante não incluído na campanha.');if(progress.completion)fail('Participação já concluída.');
  if(!exception&&progress.contexts.some(x=>x.remaining>0))fail('Existem contextos abaixo do mínimo recomendado. Completa os contributos ou pede ao coordenador para concluir com exceção.');
  if(exception&&(typeof p.reason!=='string'||!p.reason.trim()||p.reason.length>2000))fail('Indica o motivo da conclusão com exceção.');
  const row=(await c.query('insert into swot_submissions(organization_id,campaign_id,user_id,completion_type,authorized_by,exception_reason) values($1,$2,$3,$4,$5,$6) returning *',[org,campaign.id,user,exception?'exception':'completed',actor.id,exception?p.reason.trim():null])).rows[0];await audit(c,actor,org,campaign.id,exception?'complete_exception':'submit',row);return row;
 }
 if(op==='contribution_add'){if(p.entries)fail('Usa a importação para validar as linhas do lote.');if(p.author_id&&p.author_id!==actor.id)fail('O contributo individual usa o autor autenticado.');const row=await addEntry(c,actor,org,campaign,p);await audit(c,actor,org,campaign.id,'collect',{ids:[row.id]});return [row];}
 if(!manager(actor))fail('A importação exige gestão da campanha.',403);
 if(!Array.isArray(p.entries)||p.entries.length<1||p.entries.length>500)fail('Introduz entre 1 e 500 linhas.');const result={imported:[],errors:[],batch_id:crypto.randomUUID()};
 for(let i=0;i<p.entries.length;i++){
  await c.query('SAVEPOINT import_line');try{const entry={...p.entries[i],quadrant:p.entries[i].quadrant||p.quadrant};
   if(entry.author_email){const u=(await c.query('select id from profiles where organization_id=$1 and lower(email)=lower($2) and active',[org,String(entry.author_email).trim()])).rows[0];if(!u)fail('Autor: email não encontrado nesta empresa.');entry.author_id=u.id}
   const row=await addEntry(c,actor,org,campaign,entry,{imported:true,batch:result.batch_id});result.imported.push({line:i+1,id:row.id});await c.query('RELEASE SAVEPOINT import_line');
  }catch(e){await c.query('ROLLBACK TO SAVEPOINT import_line');await c.query('RELEASE SAVEPOINT import_line');result.errors.push({line:i+1,message:e.status?e.message:'Formato ou referência inválida nesta linha.'})}
 }
 await audit(c,actor,org,campaign.id,'import',{batch_id:result.batch_id,ids:result.imported.map(r=>r.id),errors:result.errors});return result;
}
module.exports={ensureContexts,participantProgress,revisionCommand};
