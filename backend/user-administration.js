const {saveAssignments,deleteUnusedUser}=require('./user-assignments');
// Administrator-only account management. Passwords never appear in responses/audit.
const crypto = require('node:crypto');
function hashPassword(password) {
 if(typeof password!=='string'||password.length<8||password.length>256)throw Object.assign(new Error('A senha deve ter entre 8 e 256 caracteres.'),{status:400});
 const salt=crypto.randomBytes(16).toString('hex');
 return `scrypt$${salt}$${crypto.scryptSync(password,salt,32).toString('hex')}`;
}
function verifyStoredPassword(user,password){
 if(typeof password!=='string'||password.length>256)return false;
 const stored=user.password_hash||'';
 if(stored.startsWith('scrypt$')){const [,salt,hash]=stored.split('$');try{return crypto.timingSafeEqual(Buffer.from(hash,'hex'),crypto.scryptSync(password,salt,32))}catch{return false}}
 return stored==='sq$'+crypto.createHash('sha256').update(password+user.id).digest('hex');
}
function createUserAdministration({pool,verifyJwt,readBody,send}) {
 return async function handle(req,res,path){
  if(!path.startsWith('/auth/v1/admin/users'))return false;
  const claims=verifyJwt((req.headers.authorization||'').replace(/^Bearer\s+/i,''));
  if(!claims||claims.type==='refresh_token'){send(res,401,{msg:'Sessão inválida.'});return true}
  const actor=(await pool.query('select * from public.profiles where id=$1',[claims.sub])).rows[0];
  if(!actor?.active||actor.session_version!==(claims.sv??0)||actor.role!=='admin'){send(res,403,{msg:'Apenas o administrador pode gerir utilizadores.'});return true}
  if(req.method==='GET'&&path==='/auth/v1/admin/users'){
   const {rows}=await pool.query('select id,full_name,email,role,department,job_title,active,organization_id,module_access,is_super_admin,session_version,updated_at from public.profiles where ($1::boolean OR organization_id=$2 AND NOT is_super_admin) order by full_name',[actor.is_super_admin,actor.organization_id]);for(const u of rows)u.assignments=(await pool.query('select * from user_assignments where user_id=$1 order by created_at',[u.id])).rows;send(res,200,rows);return true;
  }
  const id=path.slice('/auth/v1/admin/users/'.length),creating=req.method==='POST'&&path==='/auth/v1/admin/users';
  if(!creating&&!(['PATCH','DELETE'].includes(req.method)&&/^[0-9a-f-]{36}$/i.test(id))){send(res,405,{msg:'Operação inválida.'});return true}
  const body=await readBody(req);let client;
  try{
   if(req.method==='DELETE'){client=await pool.connect();await client.query('BEGIN');await client.query("select pg_advisory_xact_lock(hashtext('samsys-user-management'))");const locked=(await client.query('select * from profiles where id=$1 for update',[actor.id])).rows[0];if(!locked?.active||locked.role!=='admin'||locked.session_version!==(claims.sv??0))throw Object.assign(new Error('Sessão desatualizada.'),{status:401});const deleted=await deleteUnusedUser(client,locked,id,body);await client.query('COMMIT');send(res,200,deleted);return true}
   if(Object.keys(body).some(k=>!['full_name','email','role','department','job_title','active','organization_id','module_access','password','expected_updated_at','expected_version','assignments'].includes(k)))throw Object.assign(new Error('Campo não editável.'),{status:400});
   if(!body.full_name?.trim()||body.full_name.length>200||typeof body.email!=='string'||!/^\S+@\S+\.\S+$/.test(body.email)||body.email.length>254)throw Object.assign(new Error('Nome e email válidos obrigatórios.'),{status:400});
   if(!['admin','quality','management','action_owner'].includes(body.role)||typeof body.active!=='boolean')throw Object.assign(new Error('Perfil ou estado inválido.'),{status:400});
   if(!body.module_access||['quality','strategy','lifecycle'].some(k=>typeof body.module_access[k]!=='boolean'))throw Object.assign(new Error('Seleciona os acessos aos módulos.'),{status:400});
   const passwordHash=body.password?hashPassword(body.password):null;
   if(creating&&!passwordHash)throw Object.assign(new Error('Senha inicial obrigatória.'),{status:400});
   client=await pool.connect();await client.query('BEGIN');await client.query("select pg_advisory_xact_lock(hashtext('samsys-user-management'))");
   const lockedActor=(await client.query('select * from profiles where id=$1 for update',[actor.id])).rows[0];
   if(!lockedActor.active||lockedActor.role!=='admin'||lockedActor.session_version!==(claims.sv??0))throw Object.assign(new Error('Sessão desatualizada.'),{status:401});
   const existing=creating?null:(await client.query('select * from profiles where id=$1 for update',[id])).rows[0];
   if(!creating&&!existing)throw Object.assign(new Error('Utilizador não encontrado.'),{status:404});
   const superActor=lockedActor.is_super_admin===true;
   if(!superActor && (!lockedActor.organization_id || body.organization_id!==lockedActor.organization_id || existing && (existing.organization_id!==lockedActor.organization_id || existing.is_super_admin || existing.role==='admin') || body.role==='admin'))throw Object.assign(new Error('Só podes gerir utilizadores da tua empresa; administradores são geridos pelo superadministrador.'),{status:403});
   if(existing?.is_super_admin && (body.role!=='admin'||!body.active||body.email.trim().toLowerCase()!==existing.email.toLowerCase()||body.organization_id!==existing.organization_id))throw Object.assign(new Error('O estatuto e a identidade do superadministrador estão protegidos.'),{status:403});
   if(existing&&(body.expected_version!==existing.session_version||!body.expected_updated_at||new Date(body.expected_updated_at).getTime()!==new Date(existing.updated_at).getTime()))throw Object.assign(new Error('O utilizador mudou. Recarrega antes de guardar.'),{status:409});
   if(existing?.id===actor.id&&(!body.active||body.role!=='admin'))throw Object.assign(new Error('Não podes retirar o teu próprio acesso de administrador.'),{status:400});
   if(existing?.role==='admin'&&existing.active&&(!body.active||body.role!=='admin')){
    const {rows}=await client.query("select count(*) n from profiles where role='admin' and active and id<>$1 and organization_id=$2",[id,existing.organization_id]);if(Number(rows[0].n)===0)throw Object.assign(new Error('É obrigatório manter um administrador ativo.'),{status:400});
   }
   const organization=body.organization_id||null;
   if(!existing?.is_super_admin&&!organization)throw Object.assign(new Error('Empresa obrigatória.'),{status:400});
   if(organization&&!(await client.query('select 1 from organizations where id=$1 and active',[organization])).rowCount)throw Object.assign(new Error('Empresa inválida ou inativa.'),{status:400});
   const userId=existing?.id||crypto.randomUUID(),email=body.email.trim().toLowerCase();
   if((await client.query('select 1 from auth.users where lower(email)=$1 and id<>$2',[email,userId])).rowCount)throw Object.assign(new Error('Este email já está em utilização.'),{status:409});
   if(creating)await client.query('insert into auth.users(id,email,raw_user_meta_data,password_hash) values($1,$2,$3,$4)',[userId,email,{full_name:body.full_name.trim()},passwordHash]);
   else await client.query("update auth.users set email=$2,raw_user_meta_data=coalesce(raw_user_meta_data,'{}')||$3::jsonb,password_hash=coalesce($4,password_hash),updated_at=clock_timestamp() where id=$1",[userId,email,JSON.stringify({full_name:body.full_name.trim()}),passwordHash]);
   const modules=Object.fromEntries(['quality','strategy','lifecycle'].map(k=>[k,body.role==='admin'||body.module_access[k]]));
   const updated=(await client.query('update profiles set full_name=$2,email=$3,role=$4,department=$5,job_title=$6,active=$7,organization_id=$8,module_access=$9,session_version=session_version+$10,updated_at=clock_timestamp() where id=$1 returning id,full_name,email,role,department,job_title,active,organization_id,module_access,is_super_admin,session_version,updated_at',[userId,body.full_name.trim(),email,body.role,body.department||null,body.job_title||null,body.active,organization,modules,creating?0:1])).rows[0];
   await client.query('update organization_memberships set active=false where user_id=$1',[userId]);
   if(organization)await client.query("insert into organization_memberships(organization_id,user_id,role,active) values($1,$2,'member',$3) on conflict(organization_id,user_id) do update set active=excluded.active",[organization,userId,body.active]);
   const assignmentItems=body.assignments??(creating||existing.role!==body.role?['quality','strategy','lifecycle'].filter(()=>body.role!=='admin').map(module=>({kind:'permission',module,role:body.role,active:true})):null);
   await client.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify(claims)]);
   if(assignmentItems)await saveAssignments(client,userId,organization,assignmentItems);
   const safeBefore=existing?Object.fromEntries(Object.keys(updated).map(k=>[k,existing[k]])):null;
   await client.query('insert into user_access_history(user_id,actor_id,before_data,after_data,password_changed) values($1,$2,$3,$4,$5)',[userId,actor.id,safeBefore,updated,!!passwordHash]);
   await client.query('COMMIT');send(res,creating?201:200,updated);
  }catch(e){if(client)await client.query('ROLLBACK');send(res,e.status||400,{msg:e.status?e.message:'Não foi possível guardar o utilizador. Verifica os dados.'})}finally{client?.release()}
  return true;
 }
}
module.exports={hashPassword,verifyStoredPassword,createUserAdministration};
