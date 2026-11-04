// Event outbox: SMTP never runs inside a user's business transaction.
const {enqueue,qualityRecipients}=require('./quality-baseline');
function retryAt(attempt,minutes,now=new Date()){return attempt<=minutes.length?new Date(now.getTime()+minutes[attempt-1]*60000):null}
function businessDaysLate(deadline,now){
 const start=new Date(String(deadline).slice(0,10)+'T00:00:00Z'),end=new Date(now.toISOString().slice(0,10)+'T00:00:00Z');let days=0;
 for(start.setUTCDate(start.getUTCDate()+1);start<=end;start.setUTCDate(start.getUTCDate()+1))if(start.getUTCDay()!==0&&start.getUTCDay()!==6)days++;
 return days;
}
async function reminders(pool,now=new Date()){
 const c=await pool.connect();try{await c.query('BEGIN');
 const actions=(await c.query(`select a.*,o.cancelled_at from quality_actions a left join quality_occurrences o on o.id=a.occurrence_id where a.status not in ('COMPLETED','CANCELLED') and a.deadline is not null and o.cancelled_at is null`)).rows;
 for(const a of actions){const settings=(await c.query('select * from quality_settings where organization_id=$1',[a.organization_id])).rows[0];const days=Math.round((new Date(a.deadline).getTime()-new Date(now.toISOString().slice(0,10)).getTime())/86400000);
 const late=days<0?businessDaysLate(a.deadline,now):0,qualityDays=settings?.quality_escalation_days??5,leaderDays=settings?.leader_escalation_days??10;
 const link=a.occurrence_id?`/ocorrencias/${a.occurrence_id}?action=${a.id}`:'/qualidade/acoes';
 if(late>=qualityDays)for(const recipient of await qualityRecipients(c,a.organization_id))await enqueue(c,{org:a.organization_id,event:`escalation:${a.id}:${String(a.deadline).slice(0,10)}:${qualityDays}-business-days`,entity:'quality_actions',id:a.id,recipient,title:`${a.reference} · Atraso para acompanhamento da Qualidade`,message:`A ação atingiu ${qualityDays} dias úteis de atraso. ${a.description}`,link});
 if(settings?.escalation_leader_id&&late>=leaderDays)await enqueue(c,{org:a.organization_id,event:`leader-escalation:${a.id}:${String(a.deadline).slice(0,10)}:${leaderDays}-business-days`,entity:'quality_actions',id:a.id,recipient:settings.escalation_leader_id,title:`${a.reference} · Atraso para acompanhamento do líder`,message:`A ação atingiu ${leaderDays} dias úteis de atraso. ${a.description}`,link});
 if(!(settings?.reminder_days||[7,3,1]).includes(days)&&!(settings?.overdue_reminder_days||[1,3]).includes(-days))continue;
 await enqueue(c,{org:a.organization_id,event:`deadline:${a.id}:${new Date(a.deadline).toISOString().slice(0,10)}:${days}`,entity:'quality_actions',id:a.id,recipient:a.responsible_user_id,title:`${a.reference} · ${days<0?'Prazo ultrapassado':'Prazo próximo'}`,message:`${a.description}. Atualiza o ponto de situação e junta a evidência necessária.`,link:a.occurrence_id?`/ocorrencias/${a.occurrence_id}?action=${a.id}`:'/meu-trabalho'});
 }await c.query('COMMIT');}catch(e){await c.query('ROLLBACK');throw e}finally{c.release()}
}
async function sendNext(pool,transport,{baseUrl,from,now=new Date()}={}){
 const c=await pool.connect();let job;
 try{
  await c.query('BEGIN');
  // Uncertain deliveries are not automatically resent: avoids duplicates after a crash.
  await c.query("update quality_outbox set status='FAILED',last_error='Entrega incerta após interrupção; verificar antes de reenviar.' where status='SENDING' and locked_at<now()-interval '10 minutes'");
  job=(await c.query("select * from quality_outbox where status='PENDING' and next_attempt_at<=$1 order by created_at for update skip locked limit 1",[now])).rows[0];
  if(!job){await c.query('COMMIT');return false}
  await c.query("update quality_outbox set status='SENDING',locked_at=now(),attempts=attempts+1 where id=$1",[job.id]);await c.query('COMMIT');
  let error=null;
  try{
   const recipient=(await c.query("select email from profiles where id=$1 and active and (organization_id=$2 or is_super_admin) and (role='admin' or module_access->>'quality'='true')",[job.recipient_id,job.organization_id])).rows[0];
   if(!recipient||!/^\S+@\S+\.\S+$/.test(recipient.email||''))throw new Error('Destinatário inválido ou sem acesso atual.');
   if(!transport||!baseUrl||!from)throw new Error('SMTP não configurado.');
   await transport.sendMail({from,to:recipient.email,subject:job.subject,text:`Olá,\n\n${job.message}\n\n${new URL(job.link,baseUrl).href}\n\nQualidade que se vê. Melhoria que se acompanha.`,messageId:`<${job.id}@quality.local>`});
  }catch(e){error=String(e.message).slice(0,1000)}
  await c.query('BEGIN');const settings=(await c.query('select retry_minutes from quality_settings where organization_id=$1',[job.organization_id])).rows[0];const next=error?retryAt(job.attempts+1,settings?.retry_minutes||[5,30,120],now):null;
  await c.query('update quality_outbox set status=$2,last_error=$3,next_attempt_at=coalesce($4,next_attempt_at),sent_at=$5,locked_at=null where id=$1',[job.id,error?(next?'PENDING':'FAILED'):'SENT',error,next,error?null:now]);
  await c.query("insert into audit_log(entity_type,entity_id,action,new_data,organization_id) values('quality_outbox',$1,$2,$3,$4)",[job.id,error?'email_failed':'email_sent',{attempt:job.attempts+1,next_attempt_at:next},job.organization_id]);await c.query('COMMIT');return true;
 }catch(e){await c.query('ROLLBACK').catch(()=>{});throw e}finally{c.release()}
}
function startQualityWorker(pool){
 // Deployment must explicitly enable delivery after SMTP configuration/UAT.
 const deliveryEnabled=process.env.QUALITY_EMAIL_ENABLED==='true';
 const nodemailer=require('nodemailer');const transport=process.env.SMTP_HOST?nodemailer.createTransport({host:process.env.SMTP_HOST,port:Number(process.env.SMTP_PORT||587),secure:process.env.SMTP_SECURE==='true',auth:process.env.SMTP_USER?{user:process.env.SMTP_USER,pass:process.env.SMTP_PASSWORD}:undefined,connectionTimeout:10000,socketTimeout:15000}):null;
 let busy=false;const timer=setInterval(async()=>{if(busy)return;busy=true;try{await reminders(pool);if(!deliveryEnabled)return;for(let i=0;i<10;i++)if(!await sendNext(pool,transport,{baseUrl:process.env.QUALITY_PUBLIC_URL,from:process.env.SMTP_FROM}))break}catch{console.error('[quality-worker] Falha temporária; próxima execução agendada.')}finally{busy=false}},60000);timer.unref();return timer;
}
module.exports={retryAt,businessDaysLate,reminders,sendNext,startQualityWorker};
