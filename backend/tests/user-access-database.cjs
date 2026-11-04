const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');const {Client}=require('pg');const c=new Client({connectionString:process.env.DATABASE_URL});
const sql=fs.readFileSync(require('path').join(__dirname,'../../supabase/migrations/0053_user_company_access.sql'),'utf8').replace(/^\uFEFF/,'').replace(/^BEGIN;/m,'').replace(/^COMMIT;/m,'');let checks=0;
async function deny(fn,re){await c.query('savepoint bad');try{await fn();assert.fail('Expected denial')}catch(e){assert.match(e.message,re);checks++}finally{await c.query('rollback to savepoint bad')}}

(async()=>{await c.connect();await c.query('BEGIN');if(!(await c.query("select to_regprocedure('public.protect_super_administrator()') present")).rows[0].present)await c.query(sql);
const organizations=(await c.query('select id from organizations order by name')).rows;
const superUser=(await c.query('select * from profiles where is_super_admin')).rows[0];assert(superUser);assert.equal(superUser.email.toLowerCase(),'geral@samsys.pt');checks++;
const {createUserAdministration,verifyStoredPassword}=require('../user-administration');
let result,claim;
const proxy={query:(...args)=>c.query(...args),connect:async()=>({query:(text,params)=>text==='BEGIN'?c.query('SAVEPOINT admin_request'):text==='COMMIT'?Promise.resolve({rows:[]}):text==='ROLLBACK'?c.query('ROLLBACK TO SAVEPOINT admin_request'):c.query(text,params),release(){}})};
const handler=createUserAdministration({pool:proxy,verifyJwt:()=>claim,readBody:async req=>req.body,send:(_res,status,data)=>{result={status,data}}});
async function call(actor,method,path,body){claim={sub:actor.id,sv:actor.session_version};await handler({method,body,headers:{authorization:'Bearer test'}},{},path);return result}
const fields={full_name:'QA',role:'admin',active:true,module_access:{quality:true,strategy:true,lifecycle:true},password:'Teste-Seguro-123'};
let a=await call(superUser,'POST','/auth/v1/admin/users',{...fields,email:'qa-admin-a@example.invalid',organization_id:organizations[0].id});assert.equal(a.status,201,JSON.stringify(a));a=a.data;checks++;
let b=await call(superUser,'POST','/auth/v1/admin/users',{...fields,email:'qa-admin-b@example.invalid',organization_id:organizations[1].id});assert.equal(b.status,201);b=b.data;checks++;
let u=await call(a,'POST','/auth/v1/admin/users',{...fields,role:'quality',email:'qa-user-a@example.invalid',organization_id:a.organization_id});assert.equal(u.status,201,JSON.stringify(u));u=u.data;checks++;
for(const body of [{...fields,email:'forbidden@example.invalid',organization_id:a.organization_id},{...fields,role:'quality',email:'forbidden@example.invalid',organization_id:b.organization_id},{...fields,role:'quality',email:'forbidden@example.invalid',organization_id:a.organization_id,is_super_admin:true}]){const r=await call(a,'POST','/auth/v1/admin/users',body);assert([400,403].includes(r.status));checks++}
let r=await call(a,'GET','/auth/v1/admin/users');assert(r.data.every(x=>x.organization_id===a.organization_id&&!x.is_super_admin));checks++;
r=await call(a,'PATCH','/auth/v1/admin/users/'+b.id,{...fields,email:b.email,organization_id:b.organization_id,expected_updated_at:b.updated_at,expected_version:b.session_version});assert.equal(r.status,403);checks++;
r=await call(a,'PATCH','/auth/v1/admin/users/'+u.id,{...fields,role:'quality',email:u.email,organization_id:a.organization_id,expected_updated_at:u.updated_at,expected_version:u.session_version,password:'Nova-Senha-456'});assert.equal(r.status,200,JSON.stringify(r));assert.equal(r.data.session_version,1);checks++;
const stored=(await c.query('select id,password_hash from auth.users where id=$1',[u.id])).rows[0];assert(verifyStoredPassword(stored,'Nova-Senha-456'));assert(!verifyStoredPassword(stored,fields.password));checks++;
r=await call(superUser,'POST','/auth/v1/admin/users',{...fields,email:'forbidden@example.invalid',organization_id:a.organization_id,is_super_admin:true});assert.equal(r.status,400);checks++;
await deny(()=>c.query('update profiles set is_super_admin=true where id=$1',[a.id]),/superadministrador/i);
await deny(()=>c.query('delete from profiles where id=$1',[superUser.id]),/Superadministrador/);
await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:a.id,sv:a.session_version})]);await c.query('set local role authenticated');
assert((await c.query('select id,organization_id,is_super_admin from profiles')).rows.every(x=>x.organization_id===a.organization_id&&!x.is_super_admin));checks++;
assert.equal((await c.query('select id from organizations')).rows.length,1);checks++;
await deny(()=>c.query("select platform_module_write('organizations','{\"name\":\"forbidden\"}',null,null,true)"),/Empresa/);
const area=(await c.query("insert into quality_areas(name) values('QA empresa') returning organization_id")).rows[0];assert.equal(area.organization_id,a.organization_id);checks++;
assert((await c.query('select organization_id from quality_areas')).rows.every(x=>x.organization_id===a.organization_id));checks++;
await deny(()=>c.query("insert into quality_areas(name,organization_id) values('Outra empresa',$1)",[b.organization_id]),/Empresa/);
await deny(()=>c.query("update profiles set role='admin' where id=$1",[u.id]),/permission denied/);
await c.query('ROLLBACK');console.log(JSON.stringify({checks,rollback:true}));
})().catch(async e=>{await c.query('ROLLBACK').catch(()=>{});console.error(e.message,e.where,e.position);process.exitCode=1}).finally(()=>c.end());

