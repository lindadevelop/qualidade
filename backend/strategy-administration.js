// Campaign collection and consolidation preserve originals; publication requires a human.
const fail=(message,status=400)=>{throw Object.assign(new Error(message),{status})};
const quadrants=['strengths','weaknesses','opportunities','threats'];
const {saveBrandAsset}=require('./brand-assets');
const {ensureContexts,participantProgress}=require('./strategy-participation');
const {suggestGroups}=require('./swot-consolidation');
const {contextCommand,configureContext,eligibleContributions}=require('./strategy-context');
const nonempty=(value,label,max=2000)=>{if(typeof value!=='string'||!value.trim()||value.length>max)fail(`${label}: preenche um valor válido.`);return value.trim()};
async function history(c,actor,org,type,id,action,before,after){await c.query('insert into platform_admin_history(organization_id,entity_type,entity_id,action,before_data,after_data,actor_id) values($1,$2,$3,$4,$5,$6,$7)',[org,type,id,action,before,after,actor.id])}
async function strategyCommand(c,actor,org,operation,id,p){
 const contextual=await contextCommand(c,actor,org,operation,id,p);if(contextual!==undefined)return contextual;
 const manager=actor.role==='admin'||actor.roles?.includes('quality');
 if(!manager&&operation!=='contribution_add')fail('Esta operação exige responsabilidade de gestão da Estratégia.',403);
 if(operation==='brand_asset_upload')return saveBrandAsset(c,actor,org,id,p);
 if(operation==='campaign_save'){
  const before=id?(await c.query('select * from swot_campaigns where id=$1 and organization_id=$2 for update',[id,org])).rows[0]:null;
  if(id&&!before)fail('Campanha não encontrada.',404);
  if(before&&before.version!==p.version)fail('A campanha mudou. Recarrega os dados.',409);
  if(before&&['closed','archived'].includes(before.status))fail('Reabre a campanha antes de alterar a configuração.');
  const name=nonempty(p.name,'Nome',200),rules=nonempty(p.validation_rules,'Regras');
  if(!(await c.query('select 1 from cycles where id=$1 and organization_id=$2 and active',[p.cycle_id,org])).rowCount)fail('Seleciona um ciclo ativo desta empresa.');
  if(before&&before.cycle_id!==p.cycle_id&&(await c.query('select 1 from swot_contributions where campaign_id=$1 union all select 1 from swot_items where campaign_id=$1',[id])).rowCount)fail('Uma campanha utilizada mantém o ciclo original.');
  for(const key of ['starts_at','ends_at'])if(p[key]&&!Number.isFinite(Date.parse(p[key])))fail('Data inválida.');
  if(p.starts_at&&p.ends_at&&Date.parse(p.ends_at)<Date.parse(p.starts_at))fail('A data final deve ser igual ou posterior à inicial.');
  if(!Number.isInteger(p.min_per_quadrant)||!Number.isInteger(p.max_per_quadrant)||p.min_per_quadrant<0||p.max_per_quadrant<p.min_per_quadrant||p.max_per_quadrant<1||p.max_per_quadrant>1000)fail('Define limites válidos entre 0 e 1000 contributos por quadrante.');
  const values=[org,p.cycle_id,name,p.description||null,p.starts_at||null,p.ends_at||null,!!p.is_demo,p.min_per_quadrant,p.max_per_quadrant,rules,actor.id];
  const row=id?(await c.query('update swot_campaigns set cycle_id=$2,name=$3,description=$4,starts_at=$5,ends_at=$6,is_demo=$7,min_per_quadrant=$8,max_per_quadrant=$9,validation_rules=$10 where id=$12 and organization_id=$1 and $11::uuid is not null returning *',[...values,id])).rows[0]:(await c.query('insert into swot_campaigns(organization_id,cycle_id,name,description,starts_at,ends_at,is_demo,min_per_quadrant,max_per_quadrant,validation_rules,created_by) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) returning *',values)).rows[0];
  if(!Array.isArray(p.audience)||p.audience.length>1000)fail('Seleciona os participantes ou equipas.');
  await c.query('delete from swot_campaign_audience where campaign_id=$1',[row.id]);
  const seen=new Set();for(const a of p.audience){const table=a.kind==='team'?'teams':a.kind==='user'?'profiles':null;if(!table)fail('Participante inválido.');if(seen.has(a.kind+a.id))continue;seen.add(a.kind+a.id);if(!(await c.query(`select 1 from ${table} where id=$1 and organization_id=$2 and active`,[a.id,org])).rowCount)fail('Participante ou equipa de outra empresa ou inativo.');await c.query('insert into swot_campaign_audience(organization_id,campaign_id,user_id,team_id) values($1,$2,$3,$4)',[org,row.id,a.kind==='user'?a.id:null,a.kind==='team'?a.id:null])}
  await configureContext(c,actor,org,row,p);if(row.status==='open')await ensureContexts(c,row,org);
  const configured=(await c.query('select * from swot_campaigns where id=$1',[row.id])).rows[0];
  await history(c,actor,org,'swot_campaigns',row.id,id?'edit':'create',before,{...configured,audience:p.audience,validators:p.validators});return configured;
 }
 if(operation.startsWith('campaign_')||operation==='contribution_add'||operation==='propose_groups'||operation==='proposal_validate'){
  const campaign=(await c.query('select * from swot_campaigns where id=$1 and organization_id=$2 for update',[id,org])).rows[0];if(!campaign)fail('Campanha não encontrada.',404);
  if(operation==='campaign_upgrade'){if(campaign.status!=='draft')fail('A atualização das regras exige uma campanha em rascunho.');if((await c.query('select 1 from swot_contributions where campaign_id=$1',[id])).rowCount)fail('Campanha com recolha anterior. Cria uma nova campanha para preservar as regras e o histórico.');const row=(await c.query("update swot_campaigns set quota_mode='participant_context',collection_revision=2 where id=$1 returning *",[id])).rows[0];await history(c,actor,org,'swot_campaigns',id,'upgrade',campaign,row);return row;}
  if(operation==='campaign_transition'){
   if(campaign.version!==p.version)fail('A campanha mudou. Recarrega os dados.',409);
   const allowed={draft:['open','archived'],open:['validation','closed','archived'],validation:['open','closed','archived'],closed:['open','archived'],archived:['draft','open']};
   if(!allowed[campaign.status]?.includes(p.status))fail('Transição de estado inválida.');
   const reason=nonempty(p.reason,'Motivo da alteração',1000);
   if(campaign.quota_mode==='legacy'&&['validation','closed'].includes(p.status)){const counts=(await c.query('select quadrant,count(*) n from swot_contributions where campaign_id=$1 group by quadrant',[id])).rows;for(const q of quadrants)if(Number(counts.find(r=>r.quadrant===q)?.n||0)<campaign.min_per_quadrant)fail('Ainda não foi atingido o mínimo de contributos em todos os quadrantes.');}
   if(campaign.quota_mode==='participant_context'&&p.status==='open'&&!(await c.query('select 1 from swot_campaign_validators where campaign_id=$1 and team_id is null',[id])).rowCount)fail('Configura um validador para os contributos sobre a organização.');
   const row=(await c.query('update swot_campaigns set status=$2 where id=$1 returning *',[id,p.status])).rows[0];if(row.status==='open')await ensureContexts(c,row,org);await history(c,actor,org,'swot_campaigns',id,'state',campaign,{...row,reason});return row;
  }
  if(operation==='campaign_delete'){if(p.confirm_delete!==true)fail('Confirma a eliminação.');await c.query('delete from swot_campaign_audience where campaign_id=$1',[id]);await c.query('delete from swot_campaign_validators where campaign_id=$1',[id]);await c.query('delete from swot_campaigns where id=$1',[id]);await history(c,actor,org,'swot_campaigns',id,'delete',campaign,null);return {deleted:true}}
  if(['closed','archived'].includes(campaign.status))fail('A campanha está fechada. Reabre antes de alterar.');
  if(operation==='contribution_add'){
   if(campaign.status!=='open'||campaign.starts_at&&Date.now()<+campaign.starts_at||campaign.ends_at&&Date.now()>+campaign.ends_at)fail('A recolha não está aberta neste período.');
   if(!manager&&!(await c.query("select 1 from swot_campaign_audience a where a.campaign_id=$1 and (a.user_id=$2 or a.team_id in(select team_id from user_assignments where user_id=$2 and kind='team' and active and (starts_on is null or starts_on<=current_date) and (ends_on is null or ends_on>=current_date)))",[id,actor.id])).rowCount)fail('Não estás incluído nos participantes desta campanha.',403);
   const entries=p.entries||[p];if(!Array.isArray(entries)||!entries.length||entries.length>500)fail('Introduz entre 1 e 500 contributos.');if(!manager&&entries.length!==1)fail('A importação exige responsabilidade de gestão.',403);
   const saved=[];for(const entry of entries){if(!quadrants.includes(entry.quadrant))fail('Seleciona um quadrante.');const text=nonempty(entry.contribution,'Contributo',10000);
    if(entry.team_id&&!(await c.query(`select 1 from teams t where t.id=$1 and t.organization_id=$2 and t.active and ($3::boolean or exists(select 1 from user_assignments a where a.team_id=t.id and a.user_id=$4 and a.active and (starts_on is null or starts_on<=current_date) and (ends_on is null or ends_on>=current_date)))`,[entry.team_id,org,manager,actor.id])).rowCount)fail('Equipa inválida para este participante.');
    const count=Number((await c.query('select count(*) n from swot_contributions where campaign_id=$1 and quadrant=$2',[id,entry.quadrant])).rows[0].n);if(count>=campaign.max_per_quadrant)fail('Foi atingido o máximo de contributos deste quadrante.');
    const row=(await c.query('insert into swot_contributions(campaign_id,organization_id,quadrant,user_id,contribution,team_id,source,author_label) values($1,$2,$3,$4,$5,$6,$7,$8) returning *',[id,org,entry.quadrant,actor.id,text,entry.team_id||null,manager?entry.source||'Aplicação':'Aplicação',manager?entry.author_label||actor.full_name:actor.full_name])).rows[0];saved.push(row);
   }await history(c,actor,org,'swot_campaigns',id,'collect',null,{ids:saved.map(r=>r.id)});await c.query('update profiles set account_used=true where id=$1',[actor.id]);return saved;
  }
  if(operation==='propose_groups'){
   if(campaign.status!=='validation')fail('Passa a campanha para validação antes de consolidar.');
   const raw=await eligibleContributions(c,campaign);const groups=suggestGroups(raw);
   await c.query("delete from swot_proposals where campaign_id=$1 and status='proposed'",[id]);const result=[];
   for(const g of groups){result.push((await c.query('insert into swot_proposals(organization_id,campaign_id,quadrant,title,contribution_ids,created_by,thematic_area_id) values($1,$2,$3,$4,$5,$6,$7) returning *',[org,id,g.quadrant,g.title,g.items.map(r=>r.id),actor.id,g.items[0].thematic_area_id||null])).rows[0])}await history(c,actor,org,'swot_campaigns',id,'propose',null,{count:result.length});return result;
  }
  if(operation==='proposal_validate'){
   if(campaign.status!=='validation'||p.human_confirmed!==true)fail('A publicação exige validação humana na fase de validação.');
   const proposal=(await c.query("select * from swot_proposals where id=$1 and campaign_id=$2 and status='proposed' for update",[p.proposal_id,id])).rows[0];if(!proposal)fail('Proposta não encontrada ou já validada.');
   if(!quadrants.includes(p.quadrant))fail('Quadrante inválido.');const title=nonempty(p.title,'Texto final',10000);
   const raw=(await c.query('select * from swot_contributions where id=any($1::uuid[]) and campaign_id=$2 and item_id is null for update',[proposal.contribution_ids,id])).rows;if(raw.length!==proposal.contribution_ids.length)fail('Os originais já foram consolidados. Recria as sugestões.');
   const eligible=new Set((await eligibleContributions(c,campaign)).map(r=>r.id));if(raw.some(r=>!eligible.has(r.id)))fail('Existem contributos não submetidos ou sem aprovação do contexto.');
   const item=(await c.query('insert into swot_items(campaign_id,quadrant,title,description,created_by,thematic_area_id,contribution_scope,team_id) values($1,$2,$3,$4,$5,$6,$7,$8) returning *',[id,p.quadrant,title,`${raw.length} menções; originais preservados na recolha.`,actor.id,proposal.thematic_area_id,raw[0].contribution_scope,raw[0].team_id])).rows[0];
   await c.query('update swot_contributions set item_id=$2 where id=any($1::uuid[])',[proposal.contribution_ids,item.id]);await c.query("update swot_proposals set status='validated',title=$2,quadrant=$3,item_id=$4,validated_by=$5,validated_at=now() where id=$1",[proposal.id,title,p.quadrant,item.id,actor.id]);await history(c,actor,org,'swot_campaigns',id,'validate',null,{item_id:item.id,contribution_ids:proposal.contribution_ids});return item;
  }
 }
 fail('Operação desconhecida.');
}
function createStrategyAdministration({pool,verifyJwt,readBody,send}){return async(req,res,path)=>{
 if(!path.startsWith('/auth/v1/strategy-admin/'))return false;
 let c;try{const claims=verifyJwt((req.headers.authorization||'').replace(/^Bearer\s+/i,''));if(!claims||claims.type==='refresh_token')fail('Sessão inválida.',401);
 c=await pool.connect();await c.query('BEGIN');const actor=(await c.query("select *,effective_roles(id,'strategy') roles from profiles where id=$1 for share",[claims.sub])).rows[0];if(!actor?.active||actor.session_version!==(claims.sv??0))fail('Sessão desatualizada.',401);
 if(actor.role!=='admin'&&actor.module_access?.strategy!==true)fail('Sem acesso à Estratégia.',403);
 const org=req.headers['x-organization-id']||actor.organization_id;if(!org||!actor.is_super_admin&&org!==actor.organization_id)fail('Empresa inválida.',403);
 await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify(claims)]);
 let result;if(req.method==='GET'&&path.endsWith('/workspace')){result={};for(const table of ['swot_campaigns','swot_campaign_audience','swot_contributions','swot_proposals','cycles','teams','strategy_thematic_areas','strategy_area_teams','swot_campaign_validators','swot_submissions','swot_context_reviews','swot_participant_contexts'])result[table]=(await c.query(`select * from ${table} where organization_id=$1`,[org])).rows;result.user_assignments=(await c.query("select id,user_id,team_id,kind,active,starts_on,ends_on from user_assignments where organization_id=$1 and kind='team'",[org])).rows;result.participation=[];for(const camp of result.swot_campaigns.filter(r=>r.collection_revision===2&&r.quota_mode!=='legacy')){for(const person of await participantProgress(c,camp.id))if(actor.role==='admin'||actor.roles?.includes('quality')||person.user_id===actor.id)result.participation.push({...person,campaign_id:camp.id});}result.profiles=(await c.query('select id,full_name,active from profiles where organization_id=$1',[org])).rows;result.history=(await c.query('select * from platform_admin_history where organization_id=$1 order by created_at desc limit 200',[org])).rows;}
 else if(req.method==='POST'&&path.endsWith('/command')){const body=await readBody(req);result=await strategyCommand(c,actor,org,body.operation,body.id,body.payload||{})}else fail('Operação inválida.',405);
 await c.query('COMMIT');send(res,200,result);
 }catch(e){if(c)await c.query('ROLLBACK');send(res,e.status||400,{msg:e.status?e.message:e.code==='P0001'?e.message:'Não foi possível concluir. Verifica os dados e as dependências.'})}finally{c?.release()}return true;
}}
module.exports={createStrategyAdministration,strategyCommand};
