const {revisionCommand}=require('./strategy-participation');
const fail=(message,status=400)=>{throw Object.assign(new Error(message),{status})};
const scopes=['own_team','organization','other_team'];
const quadrants=['strengths','weaknesses','opportunities','threats'];
async function log(c,actor,org,type,id,action,before,after){await c.query('insert into platform_admin_history(organization_id,entity_type,entity_id,action,before_data,after_data,actor_id) values($1,$2,$3,$4,$5,$6,$7)',[org,type,id,action,before,after,actor.id])}
async function ownTeams(c,user,org){return (await c.query("select distinct a.team_id from user_assignments a join teams t on t.id=a.team_id where a.user_id=$1 and a.organization_id=$2 and a.kind='team' and a.active and t.active and (a.starts_on is null or a.starts_on<=current_date) and (a.ends_on is null or a.ends_on>=current_date)",[user,org])).rows.map(r=>r.team_id)}
async function configureContext(c,actor,org,campaign,p){
 if(campaign.quota_mode==='legacy')return;
 const limits=['min_own','max_own','min_other','max_other'];const values=limits.map((k,i)=>p[k]??(i%2?5:3));
 if(values.some(x=>!Number.isInteger(x)||x<1||x>1000)||values[1]<values[0]||values[3]<values[2])fail('Define mínimos e máximos válidos por participante e contexto.');
 if(campaign.collection_revision===2){const totals=(await c.query('select contribution_scope,count(*)::int n from swot_contributions where campaign_id=$1 group by user_id,contribution_scope,team_id',[campaign.id])).rows;if(totals.some(r=>r.n>(r.contribution_scope==='organization'?values[3]:values[1])))fail('O máximo não pode ficar abaixo dos contributos já guardados num contexto.');}
 const counts=campaign.collection_revision===2?[]:(await c.query("select user_id,count(*) filter(where contribution_scope='own_team')::int a,count(*) filter(where contribution_scope<>'own_team')::int b from swot_contributions where campaign_id=$1 group by user_id",[campaign.id])).rows;
 if(counts.some(r=>r.a>values[1]||r.b>values[3]))fail('O máximo não pode ficar abaixo dos contributos já guardados.');
 const submitted=(await c.query('select user_id from swot_submissions where campaign_id=$1',[campaign.id])).rows.map(r=>r.user_id);
 if(counts.some(r=>submitted.includes(r.user_id)&&(r.a<values[0]||r.b<values[2])))fail('O mínimo não pode invalidar participações já submetidas.');
 await c.query('update swot_campaigns set min_own=$2,max_own=$3,min_other=$4,max_other=$5 where id=$1',[campaign.id,...values]);
 if(!Array.isArray(p.validators))fail('Configura os responsáveis pela validação.');
 await c.query('delete from swot_campaign_validators where campaign_id=$1',[campaign.id]);
 for(const v of p.validators){
  if(!(await c.query("select 1 from profiles where id=$1 and organization_id=$2 and active and (role='admin' or module_access->>'strategy'='true')",[v.user_id,org])).rowCount)fail('O validador deve ser um utilizador ativo desta empresa com acesso à Estratégia.');
  if(v.team_id&&!(await ownTeams(c,v.user_id,org)).includes(v.team_id))fail('O validador de uma equipa deve ter uma atribuição ativa nessa equipa.');
  await c.query('insert into swot_campaign_validators(organization_id,campaign_id,user_id,team_id) values($1,$2,$3,$4) on conflict do nothing',[org,campaign.id,v.user_id,v.team_id||null]);
 }
}
async function contextCommand(c,actor,org,op,id,p){
 const manager=actor.role==='admin'||actor.roles?.includes('quality');
 if(op==='thematic_area_save'){
  if(!manager)fail('A configuração exige gestão da Estratégia.',403);
  const before=id?(await c.query('select * from strategy_thematic_areas where id=$1 and organization_id=$2 for update',[id,org])).rows[0]:null;
  if(id&&!before)fail('Área não encontrada.',404);if(before&&before.updated_at.toISOString()!==p.updated_at)fail('A área mudou. Recarrega os dados.',409);
  if(typeof p.name!=='string'||!p.name.trim()||p.name.length>200)fail('Preenche o nome da área temática.');
  const row=(await c.query(id?'update strategy_thematic_areas set name=$2,active=$3,updated_at=now() where id=$4 and organization_id=$1 returning *':'insert into strategy_thematic_areas(organization_id,name,active) values($1,$2,$3) returning *',id?[org,p.name.trim(),p.active!==false,id]:[org,p.name.trim(),p.active!==false])).rows[0];
  if(!Array.isArray(p.team_ids))fail('Seleciona as equipas sugeridas.');
  await c.query('delete from strategy_area_teams where area_id=$1',[row.id]);
  for(const team of new Set(p.team_ids)){if(!(await c.query('select 1 from teams where id=$1 and organization_id=$2 and active',[team,org])).rowCount)fail('Equipa inválida.');await c.query('insert into strategy_area_teams(organization_id,area_id,team_id) values($1,$2,$3)',[org,row.id,team])}
  await log(c,actor,org,'strategy_thematic_areas',row.id,id?'edit':'create',before,{...row,team_ids:p.team_ids});return row;
 }
 if(op==='structure_dependencies'||op==='structure_delete'){
  if(actor.role!=='admin')fail('Esta operação exige administração.',403);
  if(!['teams','cycles','ppt_templates','frameworks'].includes(p.table))fail('Tipo inválido.');
  const row=(await c.query(`select * from ${p.table} where id=$1 and organization_id=$2 for update`,[id,org])).rows[0];if(!row)fail('Registo não encontrado.',404);
  const refs=(await c.query("select cl.relname child,a.attname col from pg_constraint c join pg_class cl on cl.oid=c.conrelid join pg_namespace ns on ns.oid=cl.relnamespace join pg_attribute a on a.attrelid=cl.oid and a.attnum=c.conkey[1] where c.contype='f' and ns.nspname='public' and c.confrelid=to_regclass($1) and array_length(c.conkey,1)=1",['public.'+p.table])).rows;
  const dependencies=[];for(const r of refs){const n=Number((await c.query(`select count(*) n from "${r.child}" where "${r.col}"=$1`,[id])).rows[0].n);if(n)dependencies.push({table:r.child,count:n})}
  const used=(await c.query('select record_has_usage($1,$2,$3) used',[p.table,id,org])).rows[0].used;
  if(op==='structure_dependencies')return {dependencies,used};
  if(p.confirm_delete!==true)fail('Confirma a eliminação.');if(used)fail('Registo utilizado. Desativa ou arquiva; consulta as dependências.');
  await c.query(`delete from ${p.table} where id=$1`,[id]);await log(c,actor,org,p.table,id,'delete',row,null);return {deleted:true};
 }
 if(!['contribution_add','participation_submit','context_review','contribution_import','participation_exception'].includes(op))return undefined;
 const campaign=(await c.query('select * from swot_campaigns where id=$1 and organization_id=$2 for update',[id,org])).rows[0];if(!campaign)fail('Campanha não encontrada.',404);
 const revised=await revisionCommand(c,actor,org,op,campaign,p);if(revised!==undefined)return revised;
 if(campaign.quota_mode==='legacy'){if(op==='contribution_add')return undefined;fail('Esta campanha anterior usa as regras de recolha originais.');}
 if(['closed','archived'].includes(campaign.status))fail('A campanha está fechada.');
 if(op==='context_review'){
  if(!['open','validation'].includes(campaign.status))fail('A campanha não está em recolha ou validação.');
  const r=(await c.query('select r.* from swot_contributions r join swot_submissions s on s.campaign_id=r.campaign_id and s.user_id=r.user_id where r.id=$1 and r.campaign_id=$2 for update of r',[p.contribution_id,id])).rows[0];
  if(!r||r.contribution_scope==='own_team')fail('Contributo não submetido ou sem validação de contexto.');
  const isValidator=(await c.query('select 1 from swot_campaign_validators where campaign_id=$1 and user_id=$2 and team_id is not distinct from $3::uuid',[id,actor.id,r.team_id])).rowCount;
  if(!isValidator||(r.team_id&&!(await ownTeams(c,actor.id,org)).includes(r.team_id)))fail('A validação cabe ao responsável configurado para este contexto.',403);
  if(!['approved','rejected'].includes(p.decision)||typeof p.reason!=='string'||!p.reason.trim()||p.reason.length>2000)fail('Indica a decisão e a fundamentação.');
  if((await c.query('select 1 from swot_context_reviews where contribution_id=$1',[r.id])).rowCount)fail('Este contributo já foi validado.');
  const review=(await c.query('insert into swot_context_reviews(organization_id,contribution_id,decision,reason,reviewer_id) values($1,$2,$3,$4,$5) returning *',[org,r.id,p.decision,p.reason.trim(),actor.id])).rows[0];await log(c,actor,org,'swot_campaigns',id,'context_review',null,{...review});return review;
 }
 if(campaign.status!=='open'||campaign.starts_at&&Date.now()<+campaign.starts_at||campaign.ends_at&&Date.now()>+campaign.ends_at)fail('A recolha não está aberta neste período.');
 const own=await ownTeams(c,actor.id,org);
 if(!manager&&!(await c.query('select 1 from swot_campaign_audience where campaign_id=$1 and (user_id=$2 or team_id=any($3::uuid[]))',[id,actor.id,own])).rowCount)fail('Não estás incluído nos participantes desta campanha.',403);
 if((await c.query('select 1 from swot_submissions where campaign_id=$1 and user_id=$2',[id,actor.id])).rowCount)fail('A tua participação já foi submetida.');
 const counts=(await c.query("select count(*) filter(where contribution_scope='own_team')::int a,count(*) filter(where contribution_scope in ('organization','other_team'))::int b from swot_contributions where campaign_id=$1 and user_id=$2",[id,actor.id])).rows[0];
 if(op==='participation_submit'){
  if(counts.a<campaign.min_own||counts.b<campaign.min_other)fail(`Antes de submeter, regista pelo menos ${campaign.min_own} contributos sobre a própria equipa e ${campaign.min_other} sobre a organização/outras equipas. Faltam ${Math.max(0,campaign.min_own-counts.a)} no bloco A e ${Math.max(0,campaign.min_other-counts.b)} no bloco B.`);
  if(counts.a>campaign.max_own||counts.b>campaign.max_other)fail('Os contributos excedem os limites da campanha.');
  const row=(await c.query('insert into swot_submissions(organization_id,campaign_id,user_id) values($1,$2,$3) returning *',[org,id,actor.id])).rows[0];await log(c,actor,org,'swot_campaigns',id,'submit',null,row);return row;
 }
 if(p.entries)fail('Nesta recolha cada participante regista e submete os seus próprios contributos.');
 if(!quadrants.includes(p.quadrant)||!scopes.includes(p.contribution_scope)||typeof p.contribution!=='string'||!p.contribution.trim()||p.contribution.length>10000)fail('Preenche o quadrante, contexto e contributo.');
 if(!(await c.query('select 1 from strategy_thematic_areas where id=$1 and organization_id=$2 and active',[p.thematic_area_id||null,org])).rowCount)fail('Seleciona uma área temática ativa.');
 if(p.contribution_scope==='organization'){if(p.team_id)fail('No contexto organização não seleciones uma equipa.');}
 else {
  if(!(await c.query('select 1 from teams where id=$1 and organization_id=$2 and active',[p.team_id||null,org])).rowCount)fail('Seleciona uma equipa ativa.');
  if((p.contribution_scope==='own_team')!==own.includes(p.team_id))fail('Seleciona uma equipa compatível com o contexto: própria equipa ou outra equipa.');
 }
 if(p.contribution_scope!=='own_team'&&!(await c.query('select 1 from swot_campaign_validators where campaign_id=$1 and team_id is not distinct from $2::uuid',[id,p.team_id||null])).rowCount)fail('O gestor deve configurar um validador para este contexto antes de receber contributos.');
 if(p.contribution_scope==='own_team'?counts.a>=campaign.max_own:counts.b>=campaign.max_other)fail('Foi atingido o máximo de contributos deste bloco para a tua participação.');
 const row=(await c.query('insert into swot_contributions(campaign_id,organization_id,quadrant,user_id,contribution,team_id,source,author_label,thematic_area_id,contribution_scope) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) returning *',[id,org,p.quadrant,actor.id,p.contribution.trim(),p.team_id||null,'Aplicação',actor.full_name,p.thematic_area_id,p.contribution_scope])).rows[0];await log(c,actor,org,'swot_campaigns',id,'collect',null,{ids:[row.id]});return [row];
}
async function eligibleContributions(c,campaign){return (await c.query("select r.* from swot_contributions r where r.campaign_id=$1 and r.item_id is null and ($2='legacy' or (r.thematic_area_id is not null and exists(select 1 from swot_submissions s where s.campaign_id=r.campaign_id and s.user_id=r.user_id) and (r.contribution_scope='own_team' or exists(select 1 from swot_context_reviews v where v.contribution_id=r.id and v.decision='approved')))) order by r.created_at",[campaign.id,campaign.quota_mode])).rows}
module.exports={contextCommand,configureContext,eligibleContributions};
