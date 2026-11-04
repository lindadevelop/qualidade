const {validDate}=require('./quality-context');
const fail=m=>Object.assign(new Error(m),{status:400});
async function saveAssignments(c,user,org,items){
 if(!Array.isArray(items)||items.length>100)throw fail('Lista de atribuições inválida.');
 const existing=(await c.query('select * from user_assignments where user_id=$1 for update',[user])).rows;
 const ids=new Set(),keys=new Set();
 for(const item of items){
  if(!['team','permission'].includes(item.kind)||typeof item.active!=='boolean')throw fail('Atribuição inválida.');
  if(item.id&&!existing.some(r=>r.id===item.id))throw fail('Atribuição de outro utilizador.');
  if(item.id&&ids.has(item.id))throw fail('Atribuição repetida.');if(item.id)ids.add(item.id);
  const old=existing.find(r=>r.id===item.id);
  for(const k of ['starts_on','ends_on'])if(item[k]&&!validDate(item[k]))throw fail('Introduza uma data válida no formato dd/mm/aaaa.');
  if(item.starts_on&&item.ends_on&&item.ends_on<item.starts_on)throw fail('O fim da atribuição não pode ser anterior ao início.');
  if(item.kind==='team'){
   const team=(await c.query('select * from teams where id=$1 and organization_id=$2',[item.team_id,org])).rows[0];if(!team||!old&&!team.active||!item.function_name?.trim())throw fail('Selecione uma equipa ativa e indique a função.');
  }else if(!['quality','strategy','lifecycle'].includes(item.module)||!['quality','management','action_owner'].includes(item.role))throw fail('Perfil ou módulo inválido.');
  if(old?.used_at&&['kind','team_id','module','role','function_name'].some(k=>(old[k]||null)!==(item[k]||null)))throw fail('Termine a atribuição utilizada e adicione a nova responsabilidade.');
  const key=[item.kind,item.team_id,item.module,item.role].join(':');if(item.active&&keys.has(key))throw fail('Responsabilidade ativa repetida.');if(item.active)keys.add(key);
  const values=[user,org,item.kind,item.team_id||null,item.function_name?.trim()||null,item.module||null,item.role||null,item.active,item.starts_on||null,item.ends_on||null];
  if(old)await c.query('update user_assignments set organization_id=$2,kind=$3,team_id=$4,function_name=$5,module=$6,role=$7,active=$8,starts_on=$9,ends_on=$10 where user_id=$1 and id=$11',[...values,old.id]);
  else await c.query('insert into user_assignments(user_id,organization_id,kind,team_id,function_name,module,role,active,starts_on,ends_on) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',values);
 }
 for(const old of existing.filter(r=>!ids.has(r.id))){if(old.used_at)throw fail('Uma atribuição utilizada deve ser terminada, não removida.');await c.query('delete from user_assignments where id=$1',[old.id])}
 await c.query('update profiles set assignments_configured=true where id=$1',[user]);
}
async function deleteUnusedUser(c,actor,id,body){
 if(body.confirm_delete!==true)throw fail('Confirme a eliminação do utilizador sem utilização.');
 const user=(await c.query('select * from profiles where id=$1 for update',[id])).rows[0];
 if(!user)throw fail('Utilizador não encontrado.');
 if(user.id===actor.id||user.is_super_admin)throw fail('Não pode eliminar esta conta.');
 if(!actor.is_super_admin&&(user.organization_id!==actor.organization_id||user.role==='admin'))throw fail('Só pode gerir utilizadores da sua empresa.');
 if(user.role==='admin'&&user.active&&(await c.query("select 1 from profiles where organization_id=$1 and role='admin' and active and id<>$2",[user.organization_id,user.id])).rowCount===0)throw fail('Não pode eliminar o último administrador ativo.');
 if(user.account_used||(await c.query('select record_has_usage($1,$2,$3) used',['profiles',id,user.organization_id])).rows[0].used||(await c.query('select 1 from user_assignments where user_id=$1 and used_at is not null',[id])).rowCount)throw fail('Este utilizador já tem utilização ou histórico e não pode ser eliminado. Pode desativá-lo.');
 await c.query("insert into user_access_history(user_id,actor_id,before_data,after_data) values($1,$2,$3,$4)",[id,actor.id,{id:user.id,email:user.email,full_name:user.full_name},{deleted:true}]);
 await c.query('delete from user_assignments where user_id=$1',[id]);await c.query('delete from organization_memberships where user_id=$1',[id]);
 await c.query('delete from profiles where id=$1',[id]);await c.query('delete from auth.users where id=$1',[id]);return {deleted:true};
}
module.exports={saveAssignments,deleteUnusedUser};
