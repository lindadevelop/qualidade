const crypto=require('node:crypto');
const {hashPassword}=require('./user-administration');
const digest=s=>crypto.createHash('sha256').update(s).digest('hex');
const fail=(message,status=400)=>{throw Object.assign(new Error(message),{status})};
function recoveryTransport(env=process.env){
 if((env.AUTH_RECOVERY_EMAIL_ENABLED??env.QUALITY_EMAIL_ENABLED)!=='true'||!env.SMTP_HOST||!env.SMTP_FROM||!env.QUALITY_PUBLIC_URL)return null;
 let url;try{url=new URL(env.QUALITY_PUBLIC_URL);if(!['https:','http:'].includes(url.protocol)||url.username||url.password)return null}catch{return null}
 const transport=require('nodemailer').createTransport({host:env.SMTP_HOST,port:Number(env.SMTP_PORT||587),secure:env.SMTP_SECURE==='true',auth:env.SMTP_USER?{user:env.SMTP_USER,pass:env.SMTP_PASSWORD}:undefined,connectionTimeout:10000,socketTimeout:15000});
 return {transport,from:env.SMTP_FROM,baseUrl:url.origin};
}
function createPasswordRecovery({pool,readBody,send,delivery=recoveryTransport()}){return async(req,res,path)=>{
 if(!['/auth/v1/recover','/auth/v1/reset-password'].includes(path))return false;
 let c;try{
  if(req.method!=='POST')fail('Método inválido.',405);const body=await readBody(req);
  if(path.endsWith('/recover')){
   if(typeof body.email!=='string'||!/^\S+@\S+\.\S+$/.test(body.email)||body.email.length>254)fail('Indica um email válido.');
   const email=body.email.trim().toLowerCase(),hash=digest(email);
   c=await pool.connect();await c.query('BEGIN');await c.query('select pg_advisory_xact_lock(hashtext($1))',['recovery:'+hash]);
   if(Number((await c.query("select count(*) n from auth_recovery_attempts where email_hash=$1 and created_at>now()-interval '1 hour'",[hash])).rows[0].n)>=5)fail('Foram feitos vários pedidos. Tenta novamente mais tarde.',429);
   const attempt=(await c.query("insert into auth_recovery_attempts(email_hash,outcome) values($1,'pending') returning id",[hash])).rows[0].id;
   if(!delivery){await c.query("update auth_recovery_attempts set outcome='unavailable' where id=$1",[attempt]);await c.query('COMMIT');fail('A recuperação por email não está configurada neste ambiente. Pede ao administrador para definir uma nova senha.',503)}
   const user=(await c.query('select id,session_version from profiles where lower(email)=$1 and active',[email])).rows[0];
   if(!user){await c.query("update auth_recovery_attempts set outcome='unknown' where id=$1",[attempt]);await c.query('COMMIT');send(res,200,{message:'Se existir uma conta ativa para este email, receberás uma ligação de recuperação.'});return true}
   const token=crypto.randomBytes(32).toString('hex');const row=(await c.query("insert into auth_password_resets(user_id,token_hash,session_version,expires_at) values($1,$2,$3,now()+interval '30 minutes') returning id",[user.id,digest(token),user.session_version])).rows[0];await c.query('COMMIT');
   try{await delivery.transport.sendMail({from:delivery.from,to:email,subject:'Definir uma nova senha — Samsys',text:`Foi pedida uma nova senha para a tua conta. Abre esta ligação nos próximos 30 minutos:\n${delivery.baseUrl}/reset-password#token=${token}\n\nSe não fizeste este pedido, ignora esta mensagem.`});await c.query("update auth_recovery_attempts set outcome='sent' where id=$1",[attempt]);}
   catch(e){await c.query('update auth_password_resets set used_at=now() where id=$1',[row.id]);await c.query("update auth_recovery_attempts set outcome='failed' where id=$1",[attempt]);console.error('[recovery] Falha de entrega SMTP; pedido '+attempt);fail('Não foi possível enviar o email de recuperação. Tenta mais tarde ou contacta o administrador.',503)}
   send(res,200,{message:'Se existir uma conta ativa para este email, receberás uma ligação de recuperação.'});return true;
  }
  if(typeof body.token!=='string'||!(/^[a-f0-9]{64}$/).test(body.token))fail('Ligação inválida ou expirada. Pede uma nova recuperação.');
  if(body.password!==body.confirm_password)fail('As senhas não coincidem.');const passwordHash=hashPassword(body.password);
  c=await pool.connect();await c.query('BEGIN');const token=(await c.query('select * from auth_password_resets where token_hash=$1 for update',[digest(body.token)])).rows[0];
  if(!token||token.used_at||+token.expires_at<=Date.now())fail('Ligação inválida ou expirada. Pede uma nova recuperação.');
  const user=(await c.query('select id,active,session_version from profiles where id=$1 for update',[token.user_id])).rows[0];if(!user?.active||user.session_version!==token.session_version)fail('Ligação inválida ou expirada. Pede uma nova recuperação.');
  await c.query('update auth.users set password_hash=$2,updated_at=clock_timestamp() where id=$1',[user.id,passwordHash]);await c.query('update profiles set session_version=session_version+1,updated_at=clock_timestamp() where id=$1',[user.id]);await c.query('update auth_password_resets set used_at=now() where user_id=$1 and used_at is null',[user.id]);
  await c.query('insert into user_access_history(user_id,actor_id,before_data,after_data,password_changed) values($1,$1,$2,$3,true)',[user.id,{session_version:user.session_version},{session_version:user.session_version+1,reason:'Recuperação de senha confirmada'}]);await c.query('COMMIT');send(res,200,{message:'Senha alterada. Inicia sessão com a nova senha.'});
 }catch(e){if(c)await c.query('ROLLBACK').catch(()=>{});send(res,e.status||400,{msg:e.status?e.message:'Não foi possível concluir a recuperação. Tenta novamente.'})}finally{c?.release()}return true;
}}
module.exports={createPasswordRecovery,recoveryTransport};
