const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');const root=require('node:path').resolve(__dirname,'../..').replaceAll('\\','/');const {Client}=require(root+'/backend/node_modules/pg');const {createDataMaintenance,groups}=require(root+'/backend/data-maintenance');const {hashPassword}=require(root+'/backend/user-administration');const db=new Client({connectionString:process.env.DATABASE_URL});let checks=0;
(async()=>{await db.connect();await db.query('BEGIN');if(!(await db.query("select to_regclass('public.data_reset_history') present")).rows[0].present)await db.query(fs.readFileSync(root+'/supabase/migrations/0054_data_reset_history.sql','utf8').replace(/^\uFEFF/,'').replace(/^BEGIN;/,'').replace(/COMMIT;\s*$/,''));
const actor=(await db.query('select * from profiles where is_super_admin')).rows[0];const orgs=(await db.query('select id,name from organizations order by name')).rows;let claim={sub:actor.id,sv:actor.session_version},result;
const wrapper={query:(sql,args)=>sql==='BEGIN'?db.query('SAVEPOINT request'):sql==='COMMIT'?db.query('RELEASE SAVEPOINT request'):sql==='ROLLBACK'?db.query('ROLLBACK TO SAVEPOINT request'):db.query(sql,args),release(){}};
const handler=createDataMaintenance({pool:{connect:async()=>wrapper},verifyJwt:()=>claim,readBody:async r=>r.body,send:(_,status,data)=>result={status,data}});
async function call(action,body){await handler({method:'POST',headers:{authorization:'Bearer test'},body},{},'/auth/v1/admin/data-reset/'+action);return result}
await db.query('update auth.users set password_hash=$1 where id=$2',[hashPassword('QA-only-rollback-123'),actor.id]);
for(const module of Object.keys(groups)){
 await db.query('SAVEPOINT module_test');await db.query("select set_config('request.jwt.claims', '{}', true)");
 const org=orgs.find(o=>o.id===actor.organization_id)||orgs[0];
 // Simulate terminal queue status only in the rolled-back transaction.
 if(module==='lifecycle')await db.query("update lifecycle_cv_jobs set status='DONE' where organization_id=$1",[org.id]);
 const body={organization_id:org.id,module};let p=await call('preview',body);assert.equal(p.status,200,JSON.stringify(p));checks++;
 let r=await call('execute',{...body,token:p.data.token,confirmation:p.data.confirmation,password:'wrong'});assert.equal(r.status,403);checks++;
 r=await call('execute',{...body,token:p.data.token,confirmation:'wrong',password:'QA-only-rollback-123'});assert.equal(r.status,400);checks++;
 const otherBefore={};for(const table of Object.values(groups).flat())otherBefore[table]=(await db.query(`select count(*)::int n from ${table}`)).rows[0].n;
 r=await call('execute',{...body,token:p.data.token,confirmation:p.data.confirmation,password:'QA-only-rollback-123'});assert.equal(r.status,200,JSON.stringify(r));checks++;
 for(const table of Object.values(groups).flat()){const n=(await db.query(`select count(*)::int n from ${table}`)).rows[0].n;assert.equal(n,otherBefore[table]-(p.data.counts[table]||0),table);checks++}
 r=await call('execute',{...body,token:p.data.token,confirmation:p.data.confirmation,password:'QA-only-rollback-123'});assert.equal(r.status,409);checks++;
 await db.query('ROLLBACK TO module_test');
}

await db.query("select set_config('request.jwt.claims', '{}', true)");
const qaId=require('node:crypto').randomUUID();
await db.query("insert into auth.users(id,email,raw_user_meta_data,password_hash) values($1,$2,'{}',$3)",[qaId,'reset-qa-'+qaId+'@example.invalid',hashPassword('QA-only-rollback-123')]);
await db.query("update profiles set role='admin',active=true,organization_id=$2 where id=$1",[qaId,orgs[0].id]);
claim={sub:qaId,sv:0};
assert.equal((await call('preview',{organization_id:orgs[1].id,module:'quality'})).status,403);checks++;
assert.equal((await call('preview',{organization_id:orgs[0].id,module:'quality'})).status,200);checks++;
await db.query("update profiles set role='quality' where id=$1",[qaId]);
assert.equal((await call('preview',{organization_id:orgs[0].id,module:'quality'})).status,403);checks++;
claim={sub:actor.id,sv:actor.session_version};
const body={organization_id:actor.organization_id,module:'quality'};
let p=await call('preview',body);assert.equal(p.status,200);
await db.query("update quality_occurrences set description=description || ' QA' where organization_id=$1",[actor.organization_id]);
assert.equal((await call('execute',{...body,token:p.data.token,confirmation:p.data.confirmation,password:'QA-only-rollback-123'})).status,409);checks++;
await db.query('CREATE TABLE reset_external_test (occurrence_id uuid references public.quality_occurrences(id) on delete cascade)');
await db.query('insert into reset_external_test select id from quality_occurrences where organization_id=$1 limit 1',[actor.organization_id]);
assert.equal((await call('preview',body)).status,409);checks++;

claim={sub:actor.id,sv:actor.session_version+1};assert.equal((await call('preview',{organization_id:orgs[0].id,module:'quality'})).status,403);checks++;
await db.query('ROLLBACK');console.log(JSON.stringify({checks,rollback:true}));await db.end();})().catch(async e=>{console.error(e.message,e.where,e.stack);await db.query('ROLLBACK').catch(()=>{});await db.end();process.exitCode=1});


