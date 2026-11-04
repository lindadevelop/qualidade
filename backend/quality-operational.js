const fail=message=>Object.assign(new Error(message),{status:400});
const normalize=name=>name.trim().toLocaleLowerCase('pt-PT');
function intervals(value,label){
 if(!Array.isArray(value)||!value.length||value.length>20||value.some(n=>!Number.isInteger(n)||n<1||n>10080)||new Set(value).size!==value.length)throw fail(`${label}: indica intervalos inteiros positivos, sem repetições.`);
 return value;
}
async function audit(c,org,actor,table,id,previous,result){
 await c.query('insert into audit_log(entity_type,entity_id,action,old_data,new_data,user_id,organization_id) values($1,$2,$3,$4,$5,$6,$7)',[table,id,previous?'update':'insert',previous,result,actor.id,org]);
}
async function saveSettings(c,org,actor,p,member){
 await c.query('select pg_advisory_xact_lock(hashtext($1))',['quality-settings:'+org]);
 const previous=(await c.query('select * from quality_settings where organization_id=$1 for update',[org])).rows[0]||null;
 if(p.expected_version!==undefined&&p.expected_version!==(previous?.version||0))throw Object.assign(fail('A configuração foi alterada. Recarrega antes de guardar.'),{status:409});
 if(typeof p.deadline_approval!=='boolean')throw fail('Seleciona Sim/Não para aprovação de prazos.');
 const reminders=intervals(p.reminder_days,'Lembretes'),retries=intervals(p.retry_minutes,'Tentativas de email'),overdue=intervals(p.overdue_reminder_days??previous?.overdue_reminder_days??[1,3],'Avisos em atraso');
 const quality=p.quality_escalation_days??previous?.quality_escalation_days??5,leader=p.leader_escalation_days??previous?.leader_escalation_days??10;
 for(const n of [quality,leader])if(!Number.isInteger(n)||n<1||n>3650)throw fail('Escalonamento: indica entre 1 e 3650 dias úteis.');
 const leaderId=Object.hasOwn(p,'escalation_leader_id')?(p.escalation_leader_id||null):(previous?.escalation_leader_id||null);await member(leaderId,true);
 if(p.nc_classifications!==undefined){
  if(!Array.isArray(p.nc_classifications)||p.nc_classifications.length>200)throw fail('Lista de classificações inválida.');
  const existing=(await c.query("select * from quality_catalogs where organization_id=$1 and kind='nc_classification' for update",[org])).rows;
  const names=new Set(),ids=new Set();
  for(const item of p.nc_classifications){
   if(!item||typeof item.name!=='string'||!item.name.trim()||item.name.trim().length>120||typeof item.active!=='boolean')throw fail('Classificação: nome e estado válidos são obrigatórios.');
   const name=item.name.trim(),key=normalize(name),old=item.id?existing.find(e=>e.id===item.id):null;
   if(item.id&&!old)throw fail('Classificação não pertence a esta empresa.');
   if(names.has(key)||(item.id&&ids.has(item.id)))throw fail('Existem classificações repetidas.');names.add(key);if(item.id)ids.add(item.id);
   if(!old&&['nc menor','nc maior'].includes(key))throw fail('Classificação base já existe e é protegida.');
   if(old?.is_system&&(name!==old.name||!item.active))throw fail('Classificação base protegida.');
   if(old&&name!==old.name&&(await c.query("select 1 from quality_occurrences where organization_id=$1 and type='NC' and lower(btrim(classification))=lower(btrim($2)) limit 1",[org,old.name])).rowCount)throw fail('Classificação já utilizada: apenas podes alterar o estado.');
  }
  // Omission is not deletion. Preserve all saved rows, including inactive ones.
  for(const old of existing)if(!ids.has(old.id)&&names.has(normalize(old.name)))throw fail('Já existe uma classificação com esse nome.');
  for(const item of p.nc_classifications){
   const old=item.id?existing.find(e=>e.id===item.id):null,name=item.name.trim();
   if(old&&old.name===name&&old.active===item.active)continue;
   const result=old?(await c.query('update quality_catalogs set name=$2,active=$3 where id=$1 returning *',[old.id,name,item.active])).rows[0]:(await c.query("insert into quality_catalogs(organization_id,kind,name,active) values($1,'nc_classification',$2,$3) returning *",[org,name,item.active])).rows[0];
   await audit(c,org,actor,'quality_catalogs',result.id,old,result);
  }
 }
 const result=(await c.query(`insert into quality_settings(organization_id,deadline_approval,reminder_days,retry_minutes,overdue_reminder_days,quality_escalation_days,leader_escalation_days,escalation_leader_id)
 values($1,$2,$3,$4,$5,$6,$7,$8) on conflict(organization_id) do update set deadline_approval=excluded.deadline_approval,reminder_days=excluded.reminder_days,retry_minutes=excluded.retry_minutes,overdue_reminder_days=excluded.overdue_reminder_days,quality_escalation_days=excluded.quality_escalation_days,leader_escalation_days=excluded.leader_escalation_days,escalation_leader_id=excluded.escalation_leader_id,version=quality_settings.version+1 returning *`,[org,p.deadline_approval,reminders,retries,overdue,quality,leader,leaderId])).rows[0];
 await audit(c,org,actor,'quality_settings',org,previous,result);return result;
}
module.exports={saveSettings,intervals};
