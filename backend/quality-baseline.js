const {validateDates,eligible,approver,normVersion,saveScope,inheritContext}=require('./quality-context');
const {saveSettings}=require('./quality-operational');
// DATE values are calendar dates, not instants in the server timezone.
require('pg').types.setTypeParser(1082,value=>value);
// Baseline v2.5. Every command is atomic and scoped to the current session/company.
const crypto=require('node:crypto'),fs=require('node:fs/promises'),path=require('node:path');
const fail=(message,status=400)=>Object.assign(new Error(message),{status});
const kinds=['CORRECTION','CORRECTIVE','IMPROVEMENT','RISK','OPPORTUNITY'];
const states=['Por responder','Em preparação','Submetida','Aceite','Pendente de evidência/verificação','Fechada externamente'];
const text=(v,label)=>{if(typeof v!=='string'||!v.trim())throw fail(`${label}: preenchimento obrigatório.`);return v.trim()};
const uuid=v=>typeof v==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(v);
function completeness(o,actions,evidence,reviews){
 const active=actions.filter(a=>a.status!=='CANCELLED'),mandatory=active.filter(a=>a.mandatory);
 const missing=[];
 const cause=o.type!=='NC'||!!(o.cause_analysis?.trim()&&o.root_cause?.trim()&&o.root_cause_confirmed_by&&o.corrective_required!==null&&(o.corrective_required||o.corrective_reason?.trim()));
 const done=mandatory.every(a=>a.status==='COMPLETED')&&(!o.corrective_required||active.some(a=>a.action_kind==='CORRECTIVE'&&a.status==='COMPLETED'));
 const proof=active.every(a=>!a.evidencias_obrigatorias||evidence.some(e=>e.action_id===a.id));
 const effective=!o.effectiveness_required||reviews.some(r=>r.cycle===o.cycle&&r.result==='EFFECTIVE');
 if(!cause)missing.push('Concluir e confirmar a análise da causa, causa raiz e decisão sobre ação corretiva.');
 if(!done)missing.push('Concluir todas as ações obrigatórias e a ação corretiva necessária.');
 if(!proof)missing.push('Anexar as evidências obrigatórias das ações.');
 if(o.approval_required&&o.approval_status!=='APPROVED')missing.push('Obter a aprovação do tratamento.');
 if(!effective)missing.push('A Qualidade deve avaliar a eficácia.');
 const nextAction=mandatory.find(a=>a.status!=='COMPLETED');
 return {cause,actions:done,evidence:proof,effectiveness:effective,missing,next:o.cancelled_at?'Registo anulado. O histórico permanece disponível.':o.status==='CLOSED'?'Tratamento encerrado. Consulta o histórico e as evidências.':missing[0]||'A Qualidade pode encerrar a ocorrência.',next_action:nextAction||null};
}
async function enqueue(c,{org,event,entity='quality_occurrences',id,recipient,title,message,link}){
 if(!recipient)return;
 const eligible=(await c.query("select id from profiles where id=$1 and active and (organization_id=$2 or is_super_admin) and (role='admin' or module_access->>'quality'='true')",[recipient,org])).rows[0];if(!eligible)return;
 await c.query('insert into notifications(user_id,type,title,message,entity_type,entity_id,event_key,organization_id,link) values($1,$2,$3,$4,$5,$6,$7,$8,$9) on conflict(event_key,user_id) where event_key is not null do nothing',[recipient,'quality',title,message,entity,id,event,org,link]);
 await c.query('insert into quality_outbox(organization_id,event_key,entity_type,entity_id,recipient_id,template,subject,message,link) values($1,$2,$3,$4,$5,$6,$7,$8,$9) on conflict(event_key,recipient_id,channel) do nothing',[org,event,entity,id,recipient,event.split(':')[0],`[Qualidade] ${title}`,message,link]);
}
async function qualityRecipients(c,org){return (await c.query("select id from profiles where active and organization_id=$1 and effective_roles(id,'quality') && ARRAY['quality','admin'] and (role='admin' or module_access->>'quality'='true')",[org])).rows.map(p=>p.id)}
async function update(c,table,id,patch){const keys=Object.keys(patch);if(!keys.length)return;return (await c.query(`update ${table} set ${keys.map((k,i)=>`"${k}"=$${i+2}`).join(',')} where id=$1 returning *`,[id,...keys.map(k=>patch[k])])).rows[0]}
function pick(body,keys){return Object.fromEntries(keys.filter(k=>Object.hasOwn(body,k)).map(k=>[k,body[k]===''?null:body[k]]))}
function createQualityBaseline({pool,verifyJwt,readBody,send,uploadDir=path.join(__dirname,'data','quality-evidence')}){
 return async function handle(req,res,pathname){
  if(!pathname.startsWith('/auth/v1/quality/'))return false;
  let c;
  try{
   const claims=verifyJwt((req.headers.authorization||'').replace(/^Bearer\s+/i,''));if(!claims||claims.type==='refresh_token')throw fail('Sessão inválida.',401);
   c=await pool.connect();await c.query('BEGIN');await c.query("SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='30s'");
   const actor=(await c.query("select *,effective_roles(id,'quality') roles from profiles where id=$1 for share",[claims.sub])).rows[0];
   if(!actor?.active||actor.session_version!==(claims.sv??0))throw fail('Sessão desatualizada. Inicia sessão novamente.',401);
   if(actor.role!=='admin'&&!actor.module_access?.quality)throw fail('Sem acesso à Qualidade.',403);
   const org=req.headers['x-organization-id']||actor.organization_id;
   if(!uuid(org)||!actor.is_super_admin&&org!==actor.organization_id)throw fail('Empresa não autorizada.',403);
   if(!(await c.query('select 1 from organizations where id=$1 and active',[org])).rowCount)throw fail('Empresa indisponível.',403);
   await c.query("select set_config('request.jwt.claims',$1,true),set_config('request.headers',$2,true)",[JSON.stringify(claims),JSON.stringify({'x-organization-id':org})]);
   const manager=(actor.roles||[actor.role]).some(r=>['admin','quality'].includes(r)),requireManager=()=>{if(!manager)throw fail('Operação reservada à Qualidade/Admin.',403)};
   const row=async(table,id)=>{if(!uuid(id))throw fail('Identificador inválido.');const r=(await c.query(`select * from ${table} where id=$1 and organization_id=$2 for update`,[id,org])).rows[0];if(!r)throw fail('Registo não encontrado.',404);return r};
   const member=async(id,approval=false)=>{if(!id)return;const user=(await c.query("select *,effective_roles(id,'quality') roles from profiles where id=$1 and organization_id=$2 for share",[id,org])).rows[0];if(!user||!(approval?approver(user):eligible(user)))throw fail('Utilizador inativo, sem permissão adequada ou de outra empresa.');};
   const writable=o=>{if(o.cancelled_at||o.status==='CLOSED')throw fail('Registo encerrado/anulado: reabre antes de alterar.',409)};
   const version=(r,p)=>{if(p.expected_version!==r.version)throw fail('O registo foi alterado. Recarrega antes de guardar.',409)};
   const canTreat=o=>{if(!manager&&o.responsible_user_id!==actor.id)throw fail('Não tens permissão para alterar este tratamento.',403)};
   const evidence=async(ids,occ)=>{if(!Array.isArray(ids))throw fail('Seleciona evidências válidas.');for(const id of ids){const e=await row('quality_attachments',id);if(e.occurrence_id!==occ)throw fail('Evidência de outra ocorrência.');}};
   const event=async(name,o,recipients,message)=>{for(const recipient of [...new Set(recipients.filter(Boolean))])await enqueue(c,{org,event:`${name}:${o.id}:${o.version}`,id:o.id,recipient,title:`${o.reference} · ${name}`,message:`${o.description}\n${message}`,link:`/ocorrencias/${o.id}`})};
   if(req.method==='GET'&&pathname.endsWith('/workspace')){
    const data={};for(const [key,table] of Object.entries({audits:'quality_audits',occurrences:'quality_occurrences',actions:'quality_actions',findings:'quality_findings',attachments:'quality_attachments',reviews:'quality_effectiveness_reviews',approvals:'quality_approval_decisions',deadlines:'quality_deadline_changes',external:'quality_external_responses',settings:'quality_settings',catalogs:'quality_catalogs',areas:'quality_areas',origins:'quality_origins',comments:'quality_comments',legacy_plans:'quality_compliance_plans',legacy_approvals:'quality_plan_approval_events',scope:'quality_audit_scope',auditors:'quality_auditors'}))data[key]=(await c.query(`select * from ${table} where organization_id=$1`,[org])).rows;
    const used=(await c.query("select lower(btrim(classification)) name,count(*)::int count from quality_occurrences where organization_id=$1 and type='NC' and classification is not null group by 1",[org])).rows;data.catalogs=data.catalogs.map(item=>({...item,used_count:item.kind==='nc_classification'?(used.find(u=>u.name===item.name.trim().toLocaleLowerCase('pt-PT'))?.count||0):0}));
    data.profiles=(await c.query("select id,full_name,role,active,module_access,effective_roles(id,'quality') roles from profiles where organization_id=$1",[org])).rows.map(p=>({...p,assignable:eligible(p),can_approve:approver(p)}));
    data.notifications=(await c.query('select * from notifications where user_id=$1 and organization_id=$2 order by created_at desc limit 100',[actor.id,org])).rows;
    data.outbox=manager?(await c.query('select id,entity_id,recipient_id,subject,status,attempts,created_at,sent_at,next_attempt_at,last_error from quality_outbox where organization_id=$1 order by created_at desc limit 200',[org])).rows:[];
    data.history=(await c.query("select * from audit_log where organization_id=$1 and entity_type like 'quality_%' order by created_at desc",[org])).rows;
    data.completeness=Object.fromEntries(data.occurrences.map(o=>[o.id,completeness(o,data.actions.filter(a=>a.occurrence_id===o.id),data.attachments.filter(e=>e.occurrence_id===o.id),data.reviews.filter(r=>r.occurrence_id===o.id))]));
    await c.query('COMMIT');send(res,200,data);return true;
   }
   if(req.method==='GET'&&pathname.includes('/evidence/')){
    const e=await row('quality_attachments',pathname.split('/').pop());
    let location;if(/^q25\/[a-f0-9-]+\/[a-f0-9-]+$/.test(e.file_path))location=path.join(uploadDir,...e.file_path.split('/').slice(1));
    else {const legacy=String(e.file_path).match(/(?:^|\/)([a-f0-9]{64}\.pdf)$/);if(!legacy)throw fail('Anexo legado indisponível neste armazenamento. Contacta o administrador para recuperar o original.',404);location=path.join(__dirname,'data','uploads',legacy[1])}
    let file;try{file=await fs.readFile(location)}catch(e){if(e.code==='ENOENT')throw fail('Ficheiro original não encontrado no armazenamento. Contacta o administrador.',404);throw e}await c.query('COMMIT');
    res.writeHead(200,{'Content-Type':e.file_type||'application/octet-stream','Content-Disposition':`attachment; filename*=UTF-8''${encodeURIComponent(e.file_name)}`,'X-Content-Type-Options':'nosniff','Cache-Control':'no-store'});res.end(file);return true;
   }
   if(req.method!=='POST'||!pathname.endsWith('/command'))throw fail('Operação inválida.',405);
   const b=await readBody(req),p=b.payload||{},op=b.operation;let result;
   validateDates(p);
   if(!['settings_save','occurrence_create','area_save','auditor_save'].includes(op)&&p.human_confirmed!==true)throw fail('Confirma a operação antes de guardar.');
   if(op==='audit_save'){
    requireManager();const old=b.id?await row('quality_audits',b.id):null;if(old)version(old,p);
    if(!['INTERNAL','EXTERNAL'].includes(p.kind))throw fail('Seleciona o tipo de auditoria.');text(p.title,'Título');if(p.kind==='EXTERNAL')text(p.auditor_entity,'Entidade auditora');
    if(p.lead_auditor_id!==old?.lead_auditor_id)await member(p.lead_auditor_id);validateDates({...old,...p});
    if(p.auditor_id&&p.auditor_id!==old?.auditor_id){const auditor=await row('quality_auditors',p.auditor_id);if(!auditor.active)throw fail('Selecione um auditor ativo.');}
    const fields=pick(p,['auditor_id','lead_auditor_id','kind','title','year','start_date','end_date','lead_auditor','team','standard','scope','areas','sites','auditor_entity','external_kind','accreditation','certificate','contract_reference','representative','headcount','conclusions','recommendation','status']);
    if(old)result=await update(c,'quality_audits',old.id,fields);else{const id=crypto.randomUUID();await c.query('insert into quality_audits(id,organization_id,reference,kind,title,year,created_by) values($1,$2,$3,$4,$5,$6,$7)',[id,org,`AUD-${new Date().getFullYear()}-${id.slice(0,8)}`,p.kind,p.title,p.year||new Date().getFullYear(),actor.id]);result=await update(c,'quality_audits',id,fields)}
    await saveScope(c,org,result,p);
   }else if(op==='occurrence_create'){
    requireManager();if(!['NC','OM'].includes(p.type))throw fail('Tipo inválido.');text(p.description,'Descrição');
    if(p.audit_id){const audit=await row('quality_audits',p.audit_id);await inheritContext(c,org,audit,p)}
    if(!p.audit_id&&p.standard_id){const standard=await row('quality_catalogs',p.standard_id);if(standard.kind!=='standard'||!standard.active)throw fail('Seleciona um referencial ativo.');p.standard=null}
    const area=await row('quality_areas',p.area_id);if(!area.active)throw fail('Seleciona uma área/processo ativa.');const origin=await row('quality_origins',p.origin_id);if(!p.audit_id&&!origin.active)throw fail('Seleciona uma origem ativa.');await member(p.responsible_user_id);
    if(p.type==='NC'&&p.classification){const classification=(await c.query("select name from quality_catalogs where organization_id=$1 and kind='nc_classification' and lower(name)=lower($2) and active for share",[org,text(p.classification,'Classificação')])).rows[0];if(!classification)throw fail('Seleciona uma classificação de NC ativa desta empresa.');p.classification=classification.name;}
    result=(await c.query(`insert into quality_occurrences(organization_id,type,origin_id,area_id,occurrence_date,description,responsible_user_id,created_by,audit_id,original_text,internal_context,external_reference,classification,standard,clause,site,effectiveness_required,assigned_at) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,case when $7::uuid is not null then now() end) returning *`,[org,p.type,p.origin_id,p.area_id,p.occurrence_date||new Date().toISOString().slice(0,10),p.description,p.responsible_user_id||null,actor.id,p.audit_id||null,p.audit_id?p.description:null,p.internal_context||null,p.external_reference||null,p.classification||null,p.standard||null,p.clause||null,p.site||null,p.type==='NC'])).rows[0];
    if(p.audit_id||p.standard_id)result=await update(c,'quality_occurrences',result.id,{standard_id:p.audit_id?null:p.standard_id||null,standard_scope_id:p.standard_scope_id||null,site_scope_id:p.site_scope_id||null});
    await event('Atribuição',result,[result.responsible_user_id],'Consulta a ocorrência e confirma a tomada de conhecimento.');
   }else if(op==='finding_create'){
    requireManager();await row('quality_audits',p.audit_id);text(p.classification,'Classificação');text(p.original_text,'Texto original');
    result=(await c.query('insert into quality_findings(organization_id,audit_id,classification,original_text,internal_context,created_by) values($1,$2,$3,$4,$5,$6) returning *',[org,p.audit_id,p.classification,p.original_text,p.internal_context||null,actor.id])).rows[0];
   }else if(['occurrence_save','ack_occurrence','close','reopen','cancel','approval_submit','approval_decide','effectiveness','external_response'].includes(op)){
    const o=await row('quality_occurrences',b.id);version(o,p);
    if(op==='occurrence_save'){
     writable(o);canTreat(o);if(!manager&&['responsible_user_id','approval_required','approver_id','effectiveness_required'].some(k=>Object.hasOwn(p,k)))throw fail('Só a Qualidade configura responsáveis, aprovação e eficácia.',403);
     if(['corrective_required','effectiveness_required','approval_required','recurrent'].some(k=>Object.hasOwn(p,k)&&p[k]!==null&&typeof p[k]!=='boolean'))throw fail('Valores booleanos inválidos.');
     if(o.original_text&&Object.hasOwn(p,'description')&&p.description!==o.description)throw fail('Acrescenta o contexto interno sem alterar o texto original do auditor.');
     const patch=pick(p,['description','internal_context','cause_analysis','root_cause','corrective_required','corrective_reason','effectiveness_required','effectiveness_criterion','effectiveness_due','responsible_user_id','approval_required','approver_id','recurrent','related_occurrence_id']);
     if(p.corrective_required===false)text(p.corrective_reason,'Justificação da dispensa');if(p.corrective_required===true||(p.corrective_required===undefined&&o.corrective_required))patch.effectiveness_required=true;
     if(p.related_occurrence_id)await row('quality_occurrences',p.related_occurrence_id);
     if(p.root_cause){patch.root_cause_confirmed_by=actor.id;patch.root_cause_confirmed_at=new Date()}
     if(p.responsible_user_id!==o.responsible_user_id)await member(p.responsible_user_id);if(p.approver_id!==o.approver_id)await member(p.approver_id,true);if(p.approval_required&&!p.approver_id&&!o.approver_id)throw fail('Seleciona um aprovador.');
     if(Object.hasOwn(p,'responsible_user_id')&&p.responsible_user_id!==o.responsible_user_id){patch.assigned_at=new Date();patch.acknowledged_by=null;patch.acknowledged_at=null}
     if(o.approval_status==='APPROVED'&&['cause_analysis','root_cause','corrective_required'].some(k=>Object.hasOwn(p,k)&&p[k]!==o[k]))patch.approval_status='DRAFT';
     result=await update(c,'quality_occurrences',o.id,patch);if(patch.assigned_at)await event('Reatribuição',result,[result.responsible_user_id],'A responsabilidade mudou. Confirma a tomada de conhecimento.');
    }else if(op==='ack_occurrence'){
     if(o.responsible_user_id!==actor.id)throw fail('Só o responsável pode confirmar conhecimento.',403);result=o.acknowledged_at?o:await update(c,'quality_occurrences',o.id,{acknowledged_by:actor.id,acknowledged_at:new Date()});
    }else if(op==='reopen'){
     requireManager();text(p.reason,'Motivo da reabertura');if(o.status!=='CLOSED')throw fail('Só é possível reabrir uma ocorrência encerrada.');
     result=await update(c,'quality_occurrences',o.id,{status:'IN_PROGRESS',cycle:o.cycle+1,reopen_reason:p.reason,reopened_at:new Date(),reopened_by:actor.id,effectiveness_status:null,effectiveness_validated_by:null,effectiveness_validated_at:null,approval_status:'DRAFT'});await event('Reabertura',result,[result.responsible_user_id],'Revê o tratamento. Motivo: '+p.reason);
    }else if(op==='cancel'){
     requireManager();text(p.reason,'Justificação da anulação');result=await update(c,'quality_occurrences',o.id,{cancelled_at:new Date(),cancelled_by:actor.id,cancellation_reason:p.reason});
    }else if(op==='approval_submit'){
     writable(o);canTreat(o);if(!o.approval_required||!o.approver_id)throw fail('Configura a aprovação e o aprovador.');
     await c.query("insert into quality_approval_decisions(organization_id,occurrence_id,cycle,decision,comment,actor_id) values($1,$2,$3,'SUBMITTED',$4,$5)",[org,o.id,o.cycle,p.comment||null,actor.id]);result=await update(c,'quality_occurrences',o.id,{approval_status:'SUBMITTED'});await event('Aprovação pendente',result,[o.approver_id],'Consulta o tratamento e aprova, devolve ou rejeita.');
    }else if(op==='approval_decide'){
     writable(o);if(actor.id!==o.approver_id)throw fail('Só o aprovador designado pode decidir.',403);if(o.approval_status!=='SUBMITTED')throw fail('Não existe submissão pendente.');
     if(!['APPROVED','RETURNED','REJECTED'].includes(p.decision))throw fail('Decisão inválida.');if(p.decision!=='APPROVED')text(p.comment,'Comentário');
     await c.query('insert into quality_approval_decisions(organization_id,occurrence_id,cycle,decision,comment,actor_id) values($1,$2,$3,$4,$5,$6)',[org,o.id,o.cycle,p.decision,p.comment||null,actor.id]);result=await update(c,'quality_occurrences',o.id,{approval_status:p.decision});await event(p.decision,result,[o.responsible_user_id],p.comment||'Tratamento aprovado.');
    }else if(op==='effectiveness'||op==='close'){
     requireManager();writable(o);const actions=(await c.query('select * from quality_actions where occurrence_id=$1',[o.id])).rows,attachments=(await c.query('select * from quality_attachments where occurrence_id=$1',[o.id])).rows,reviews=(await c.query('select * from quality_effectiveness_reviews where occurrence_id=$1',[o.id])).rows;
     const check=completeness(o,actions,attachments,reviews);let blockers=check.missing.filter(m=>!m.includes('avaliar a eficácia'));
     if(blockers.length)throw fail(blockers.join(' '));
     if(op==='effectiveness'){
      if(!['EFFECTIVE','NOT_EFFECTIVE'].includes(p.result))throw fail('Resultado inválido.');text(p.criterion,'Critério');text(p.conclusion,'Conclusão');await evidence(p.evidence_ids,o.id);if(!p.evidence_ids.length)throw fail('Seleciona as evidências consideradas.');
      if(o.effectiveness_due&&new Date(o.effectiveness_due)>new Date())throw fail('Aguarda a data prevista para avaliação da eficácia.');
      await c.query('insert into quality_effectiveness_reviews(organization_id,occurrence_id,cycle,result,criterion,evidence_ids,conclusion,evaluator_id) values($1,$2,$3,$4,$5,$6,$7,$8)',[org,o.id,o.cycle,p.result,p.criterion,p.evidence_ids,p.conclusion,actor.id]);
      result=await update(c,'quality_occurrences',o.id,{effectiveness_status:p.result,effectiveness_notes:p.conclusion,effectiveness_validated_by:actor.id,effectiveness_validated_at:new Date(),status:p.result==='EFFECTIVE'?'CLOSED':'IN_PROGRESS',...(p.result==='NOT_EFFECTIVE'?{cycle:o.cycle+1,approval_status:'DRAFT'}:{})});
      await event(p.result==='EFFECTIVE'?'Encerramento':'Eficácia não demonstrada',result,[o.responsible_user_id,...await qualityRecipients(c,org)],p.conclusion);
     }else{if(check.missing.length)throw fail(check.missing.join(' '));result=await update(c,'quality_occurrences',o.id,{status:'CLOSED',effectiveness_validated_by:actor.id,effectiveness_validated_at:new Date()});await event('Encerramento',result,[o.responsible_user_id],'Ocorrência encerrada após validação da Qualidade.')}
    }else{
     canTreat(o);const audit=o.audit_id?await row('quality_audits',o.audit_id):null;if(audit?.kind!=='EXTERNAL')throw fail('Esta ocorrência não provém de uma auditoria externa.');if(!states.includes(p.status))throw fail('Estado externo inválido.');await evidence(p.evidence_ids||[],o.id);
     const keys=['cause_sent','correction','corrective_action','implementation_due','evidence_ids','sent_at','status','auditor_original_text','auditor_name','responded_at','acceptance','additional_requests','future_verification'];const fields=pick(p,keys),id=crypto.randomUUID();await c.query(`insert into quality_external_responses(id,organization_id,occurrence_id,created_by,${Object.keys(fields).join(',')}) values($1,$2,$3,$4,${Object.keys(fields).map((_,i)=>'$'+(i+5)).join(',')})`,[id,org,o.id,actor.id,...Object.values(fields)]);result=await update(c,'quality_occurrences',o.id,{external_status:p.status});
    }
   }else if(['action_save','action_complete','action_cancel','ack_action','deadline_request','deadline_decide'].includes(op)){
    const old=b.id?await row('quality_actions',b.id):null;if(old)version(old,p);if(old?.status==='CANCELLED')throw fail('A ação foi anulada e permanece apenas para consulta.',409);
    const occurrenceId=old?.occurrence_id||p.occurrence_id;const o=occurrenceId?await row('quality_occurrences',occurrenceId):null;if(o)writable(o);
    if(!manager&&(!old||old.responsible_user_id!==actor.id))throw fail('Só podes alterar ações que te foram atribuídas.',403);
    if(op==='action_save'){
     if(!old)requireManager();if(!o&&(p.action_kind||old?.action_kind)!=='IMPROVEMENT')throw fail('Uma ação autónoma deve ser do tipo Melhoria.');if(!kinds.includes(p.action_kind||old?.action_kind))throw fail('Seleciona o tipo de ação.');if((p.action_kind||old?.action_kind)==='OPPORTUNITY'&&o?.type!=='OM')throw fail('Uma ação de oportunidade de melhoria exige uma OM.');
     if(!old||Object.hasOwn(p,'description'))text(p.description,'Descrição');
     if(old&&Object.hasOwn(p,'deadline')&&p.deadline!==old.deadline?.toISOString?.().slice(0,10)&&p.deadline!==old.deadline)throw fail('Utiliza Alterar prazo e indica o motivo.');
     if(!manager&&['responsible_user_id','mandatory','evidencias_obrigatorias','action_kind','deadline'].some(k=>Object.hasOwn(p,k)))throw fail('Só a Qualidade altera a atribuição e os requisitos da ação.',403);
     if(p.status&&!['TODO','IN_PROGRESS'].includes(p.status))throw fail('Utiliza a operação Concluir ação.');if(p.responsible_user_id!==old?.responsible_user_id)await member(p.responsible_user_id);
     const fields=pick(p,['description','action_kind','responsible_user_id','completion_criterion','effectiveness_criterion','effectiveness_due','mandatory','evidencias_obrigatorias','status']);
     if(old){if(Object.hasOwn(p,'responsible_user_id')&&p.responsible_user_id!==old.responsible_user_id)Object.assign(fields,{assigned_at:new Date(),acknowledged_by:null,acknowledged_at:null});result=await update(c,'quality_actions',old.id,fields)}else{result=(await c.query('insert into quality_actions(organization_id,occurrence_id,description,action_kind,responsible_user_id,deadline,original_deadline,assigned_at,created_by,completion_criterion,evidencias_obrigatorias) values($1,$2,$3,$4,$5,$6,$6,now(),$7,$8,$9) returning *',[org,occurrenceId||null,p.description,p.action_kind,p.responsible_user_id||null,p.deadline||null,actor.id,p.completion_criterion||null,p.evidencias_obrigatorias!==false])).rows[0];if(Object.keys(fields).length)result=await update(c,'quality_actions',result.id,fields)}
     if(!old||fields.assigned_at)await enqueue(c,{org,event:`Ação atribuída:${result.id}:${result.version}`,entity:'quality_actions',id:result.id,recipient:result.responsible_user_id,title:`Nova ação ${result.reference}`,message:`${result.description}. Prazo: ${result.deadline||'a definir'}. Confirma a tomada de conhecimento.`,link:occurrenceId?`/ocorrencias/${occurrenceId}?action=${result.id}`:`/meu-trabalho?action=${result.id}`});
     if(o?.approval_status==='APPROVED')await update(c,'quality_occurrences',o.id,{approval_status:'DRAFT'});
    }else if(op==='action_cancel'){
     requireManager();text(p.reason,'Justificação da anulação');result=await update(c,'quality_actions',old.id,{status:'CANCELLED',cancellation_reason:p.reason});
    }else if(op==='ack_action'){
     if(old.responsible_user_id!==actor.id)throw fail('Só o responsável confirma conhecimento.',403);result=old.acknowledged_at?old:await update(c,'quality_actions',old.id,{acknowledged_by:actor.id,acknowledged_at:new Date()});
    }else if(op==='action_complete'){
     if(old.status==='COMPLETED')throw fail('A ação já foi concluída.',409);if(!old.action_kind)throw fail('A Qualidade deve classificar o tipo desta ação legada.');
     if(old.evidencias_obrigatorias&&!(await c.query('select 1 from quality_attachments where action_id=$1',[old.id])).rowCount)throw fail('Falta a evidência obrigatória da ação.');
     if(o?.approval_required&&o.approval_status!=='APPROVED')throw fail('O tratamento aguarda aprovação.');
     result=await update(c,'quality_actions',old.id,{status:'COMPLETED',completed_at:new Date()});
     if(o){const current=await row('quality_occurrences',o.id);if(current.status==='AWAITING_EFFECTIVENESS'&&o.status!=='AWAITING_EFFECTIVENESS')await event('Eficácia por avaliar',current,await qualityRecipients(c,org),'Todas as ações estão concluídas. A Qualidade deve avaliar a eficácia na data prevista.');}
    }else if(op==='deadline_request'){
     text(p.reason,'Motivo');if(!/^\d{4}-\d{2}-\d{2}$/.test(p.new_deadline||''))throw fail('Novo prazo inválido.');const setting=(await c.query('select deadline_approval from quality_settings where organization_id=$1',[org])).rows[0];const pending=setting?.deadline_approval===true;if((await c.query("select 1 from quality_deadline_changes where action_id=$1 and status='PENDING'",[old.id])).rowCount)throw fail('Já existe um pedido de prazo pendente.',409);
     result=(await c.query('insert into quality_deadline_changes(organization_id,action_id,old_deadline,new_deadline,reason,requested_by,status,decided_by,decided_at) values($1,$2,$3,$4,$5,$6,$7,$8,$9) returning *',[org,old.id,old.deadline,p.new_deadline,p.reason,actor.id,pending?'PENDING':'APPROVED',pending?null:actor.id,pending?null:new Date()])).rows[0];
     if(!pending)await update(c,'quality_actions',old.id,{deadline:p.new_deadline});if(o)await event(pending?'Prazo para aprovação':'Prazo alterado',{...o,version:result.id},pending?await qualityRecipients(c,org):[old.responsible_user_id],p.reason);
    }else{
     requireManager();const change=await row('quality_deadline_changes',p.change_id);if(change.action_id!==old.id||change.status!=='PENDING')throw fail('Pedido de prazo inválido.');if(!['APPROVED','REJECTED'].includes(p.decision))throw fail('Decisão inválida.');if(p.decision==='REJECTED')text(p.reason,'Motivo');
     result=await update(c,'quality_deadline_changes',change.id,{status:p.decision,decided_by:actor.id,decided_at:new Date(),decision_comment:p.reason||null});if(p.decision==='APPROVED')await update(c,'quality_actions',old.id,{deadline:change.new_deadline});
     await enqueue(c,{org,event:`deadline-decision:${change.id}`,entity:'quality_actions',id:old.id,recipient:old.responsible_user_id,title:p.decision==='APPROVED'?'Novo prazo aprovado':'Alteração de prazo rejeitada',message:p.reason||`Novo prazo: ${change.new_deadline}`,link:o?`/ocorrencias/${o.id}`:'/qualidade/acoes'});
    }
   }else if(op==='comment'||op==='evidence_add'){
    const o=p.occurrence_id?await row('quality_occurrences',p.occurrence_id):null,a=p.action_id?await row('quality_actions',p.action_id):null,audit=p.audit_id?await row('quality_audits',p.audit_id):null;
    if(a&&a.occurrence_id!==(o?.id||null))throw fail('Ação de outra ocorrência.');
    if(!o&&!a&&!audit)throw fail('Indica o registo a que pertence a evidência.');
    if(!manager&&!(o?.responsible_user_id===actor.id||a?.responsible_user_id===actor.id||op==='comment'&&o&&(await c.query('select 1 from quality_actions where occurrence_id=$1 and responsible_user_id=$2',[o.id,actor.id])).rowCount))throw fail('Só podes acrescentar informação aos teus registos.',403);
    if(op==='comment'){text(p.comment,'Comentário');if(!o&&!a)throw fail('Associa o comentário a uma ocorrência ou ação.');result=(await c.query('insert into quality_comments(organization_id,occurrence_id,action_id,comment,created_by) values($1,$2,$3,$4,$5) returning *',[org,o?.id||null,a?.id||null,p.comment,actor.id])).rows[0]}
    else{
     const name=text(p.file_name,'Nome do ficheiro');if(name.length>200)throw fail('Nome de ficheiro demasiado longo.');text(p.description,'Descrição da evidência');
     const buffer=Buffer.from(p.content_base64||'','base64');if(!buffer.length||buffer.length>10*1024*1024)throw fail('O ficheiro deve ter até 10 MB.');
     const ext=path.extname(name).toLowerCase();if(!['.pdf','.png','.jpg','.jpeg','.txt','.csv','.docx','.xlsx'].includes(ext))throw fail('Formato não permitido. Usa PDF, imagem, texto, Word ou Excel.');
     const mime={'.pdf':'application/pdf','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.txt':'text/plain','.csv':'text/csv','.docx':'application/vnd.openxmlformats-officedocument.wordprocessingml.document','.xlsx':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}[ext];
     if(ext==='.pdf'&&buffer.subarray(0,5).toString()!=='%PDF-')throw fail('O conteúdo não é um PDF válido.');
     if(p.review_id){const review=await row('quality_effectiveness_reviews',p.review_id);if(review.occurrence_id!==o?.id)throw fail('Avaliação de outra ocorrência.');}
     if(p.external_response_id){const response=await row('quality_external_responses',p.external_response_id);if(response.occurrence_id!==o?.id)throw fail('Resposta de outra ocorrência.');}
     const id=crypto.randomUUID();await fs.mkdir(path.join(uploadDir,org),{recursive:true});await fs.writeFile(path.join(uploadDir,org,id),buffer,{flag:'wx'});
     result=(await c.query('insert into quality_attachments(id,organization_id,occurrence_id,action_id,audit_id,review_id,external_response_id,file_name,file_path,file_type,file_size,description,uploaded_by) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) returning *',[id,org,o?.id||null,a?.id||null,audit?.id||null,p.review_id||null,p.external_response_id||null,name,`q25/${org}/${id}`,mime,buffer.length,p.description,actor.id])).rows[0];
    }
   }else if(op==='notification_read'){
    result=(await c.query('update notifications set read=true where id=$1 and user_id=$2 and organization_id=$3 returning id',[b.id,actor.id,org])).rows[0];
   }else if(op==='notification_retry'){
    requireManager();const message=await row('quality_outbox',b.id);if(message.status!=='FAILED')throw fail('Só podes reenviar mensagens com falha.');result=await update(c,'quality_outbox',message.id,{status:'PENDING',next_attempt_at:new Date(),attempts:0,last_error:null});await c.query("insert into audit_log(entity_type,entity_id,action,user_id,organization_id) values('quality_outbox',$1,'manual_retry',$2,$3)",[message.id,actor.id,org]);
   }else if(op==='catalog_save'){
    requireManager();if(!['finding','standard'].includes(p.kind))throw fail('Catálogo inválido.');text(p.name,'Nome');const previous=b.id?await row('quality_catalogs',b.id):null;if(previous&&previous.kind!==p.kind)throw fail('Tipo de catálogo incompatível.');if(previous&&p.kind==='standard'&&normVersion(previous.name)!==normVersion(p.name))throw fail('Uma nova versão normativa exige um novo referencial. Preserve o anterior e use Adicionar referencial.');if(b.id){result=await update(c,'quality_catalogs',b.id,{name:p.name,active:p.active!==false})}else result=(await c.query('insert into quality_catalogs(organization_id,kind,name) values($1,$2,$3) returning *',[org,p.kind,p.name])).rows[0];await c.query("insert into audit_log(entity_type,entity_id,action,old_data,new_data,user_id,organization_id) values('quality_catalogs',$1,$2,$3,$4,$5,$6)",[result.id,previous?'update':'insert',previous,result,actor.id,org]);
   }else if(op==='auditor_save'){
    requireManager();const previous=b.id?await row('quality_auditors',b.id):null;text(p.name,'Nome');if(!['INTERNAL','EXTERNAL'].includes(p.kind))throw fail('Selecione auditor interno ou externo.');
    const patch=pick(p,['name','kind','entity','contact','active']);if(previous)result=await update(c,'quality_auditors',b.id,patch);else result=(await c.query('insert into quality_auditors(organization_id,name,kind,entity,contact) values($1,$2,$3,$4,$5) returning *',[org,p.name.trim(),p.kind,p.entity||null,p.contact||null])).rows[0];
   }else if(op==='origin_save'){
    requireManager();if(!p.name?.trim())throw fail('Indique o nome da origem.');if(b.id){await row('quality_origins',b.id);result=await update(c,'quality_origins',b.id,{name:p.name.trim(),active:p.active!==false})}else result=(await c.query('insert into quality_origins(organization_id,name,active) values($1,$2,$3) returning *',[org,p.name.trim(),p.active!==false])).rows[0];
   }else if(op==='config_delete'){
    requireManager();const table={area:'quality_areas',catalog:'quality_catalogs',auditor:'quality_auditors',origin:'quality_origins'}[p.kind];if(!table||p.confirm_delete!==true)throw fail('Confirme a eliminação do valor sem utilização.');const previous=await row(table,b.id);await c.query(`delete from ${table} where id=$1`,[b.id]);await c.query('insert into audit_log(entity_type,entity_id,action,old_data,user_id,organization_id) values($1,$2,$3,$4,$5,$6)',[table,b.id,'delete',previous,actor.id,org]);result={deleted:true};
   }else if(op==='area_save'){
    requireManager();const previous=b.id?await row('quality_areas',b.id):null;const name=text(p.name,'Designação');
    if(previous)result=await update(c,'quality_areas',previous.id,{name,active:p.active!==false});else result=(await c.query('insert into quality_areas(organization_id,name) values($1,$2) returning *',[org,name])).rows[0];
    await c.query("insert into audit_log(entity_type,entity_id,action,old_data,new_data,user_id,organization_id) values('quality_areas',$1,$2,$3,$4,$5,$6)",[result.id,previous?'update':'insert',previous,result,actor.id,org]);
   }else if(op==='settings_save'){
    requireManager();result=await saveSettings(c,org,actor,p,member);
   }else throw fail('Operação desconhecida.');
   await c.query('COMMIT');send(res,200,result||{ok:true});
  }catch(e){if(c)await c.query('ROLLBACK').catch(()=>{});send(res,e.status||400,{msg:e.status?e.message:(e.code==='P0001'?e.message:'Não foi possível guardar. Verifica os campos e as relações do registo.')})}finally{c?.release()}
  return true;
 };
}
module.exports={createQualityBaseline,completeness,enqueue,qualityRecipients};
