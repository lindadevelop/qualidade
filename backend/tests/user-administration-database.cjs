const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');const {Client}=require('pg');const c=new Client({connectionString:process.env.DATABASE_URL});
const sql=fs.readFileSync(require('path').join(__dirname,'../../supabase/migrations/0053_user_company_access.sql'),'utf8').replace(/^\uFEFF/,'').replace(/^BEGIN;/m,'').replace(/^COMMIT;/m,'');let checks=0;
async function deny(fn,re){await c.query('savepoint bad');try{await fn();assert.fail('Expected denial')}catch(e){assert.match(e.message,re);checks++}finally{await c.query('rollback to savepoint bad')}}
(async()=>{await c.connect();await c.query('BEGIN');await c.query(sql);const orgs=(await c.query('select id from organizations order by name')).rows;const admin=(await c.query("select id from profiles where role in ('admin','quality') and active order by role='admin' desc limit 1")).rows[0];assert(admin,'Active account required');await c.query("update profiles set role='admin' where id=$1",[admin.id]);
const user=(await c.query("insert into auth.users(id,email,raw_user_meta_data) values(gen_random_uuid(),'access-test@example.invalid','{\"full_name\":\"Access test\"}') returning id")).rows[0];await c.query("update profiles set role='quality',organization_id=$2,module_access='{\"quality\":false,\"strategy\":true,\"lifecycle\":false}' where id=$1",[user.id,orgs[0].id]);
async function as(id,sv=0){await c.query('reset role');await c.query("select set_config('request.jwt.claims',$1,true),set_config('request.jwt.claim.sub',$2,true)",[JSON.stringify({sub:id,role:'authenticated',sv}),id]);await c.query('set local role authenticated')}

const {createUserAdministration,verifyStoredPassword}=require('../user-administration');
let result;
const proxy={query:(...args)=>c.query(...args),connect:async()=>({query:(text,params)=>text==='BEGIN'?c.query('SAVEPOINT admin_request'):text==='COMMIT'?Promise.resolve({rows:[]}):text==='ROLLBACK'?c.query('ROLLBACK TO SAVEPOINT admin_request'):c.query(text,params),release(){}})};
const handler=createUserAdministration({pool:proxy,verifyJwt:token=>({sub:token,sv:0}),readBody:async req=>req.body,send:(_res,status,data)=>{result={status,data}}});
async function call(method,path,body,actorId=admin.id){await handler({method,body,headers:{authorization:'Bearer '+actorId}},{},path);return result}
let response=await call('GET','/auth/v1/admin/users',null,user.id);assert.equal(response.status,403);checks++;
const fields={full_name:'Conta QA',email:'qa-created@example.invalid',role:'quality',active:true,organization_id:orgs[0].id,module_access:{quality:true,strategy:false,lifecycle:true},password:'QA-Password-123'};
response=await call('POST','/auth/v1/admin/users',fields);assert.equal(response.status,201,JSON.stringify(response));checks++;
const created=response.data;assert(!('password_hash' in created));assert(!JSON.stringify(created).includes(fields.password));checks++;
let authRow=(await c.query('select id,password_hash from auth.users where id=$1',[created.id])).rows[0];assert(verifyStoredPassword(authRow,fields.password));assert(authRow.password_hash.startsWith('scrypt$'));checks++;
response=await call('PATCH','/auth/v1/admin/users/'+created.id,{...fields,password:'New-Password-456',expected_updated_at:created.updated_at,expected_version:created.session_version,module_access:{quality:false,strategy:true,lifecycle:false}});assert.equal(response.status,200,JSON.stringify(response));assert.equal(response.data.session_version,1);checks++;
authRow=(await c.query('select id,password_hash from auth.users where id=$1',[created.id])).rows[0];assert(!verifyStoredPassword(authRow,fields.password));assert(verifyStoredPassword(authRow,'New-Password-456'));checks++;
response=await call('PATCH','/auth/v1/admin/users/'+created.id,{...fields,expected_updated_at:created.updated_at,expected_version:created.session_version});assert.equal(response.status,409);checks++;
const actorProfile=(await c.query('select * from profiles where id=$1',[admin.id])).rows[0];response=await call('PATCH','/auth/v1/admin/users/'+admin.id,{...actorProfile,active:false,expected_updated_at:actorProfile.updated_at,expected_version:actorProfile.session_version});assert.equal(response.status,400);checks++;
const audit=(await c.query('select * from user_access_history where user_id=$1',[created.id])).rows;assert.equal(audit.length,2);assert(audit.every(a=>a.password_changed));assert(!JSON.stringify(audit).includes('Password'));checks++;
await c.query('ROLLBACK');console.log(JSON.stringify({checks,rollback:true}));
})().catch(async e=>{await c.query('ROLLBACK').catch(()=>{});console.error(e.message,e.where,e.position,sql.slice(Number(e.position)-100,Number(e.position)+100));process.exitCode=1}).finally(()=>c.end());

