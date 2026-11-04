const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('node:assert/strict');
const {Client}=require('pg');
const c=new Client({connectionString:process.env.DATABASE_URL,connectionTimeoutMillis:5000});
const migration=fs.readFileSync(path.join(__dirname,'../../supabase/migrations/0051_strategy_workflows.sql'),'utf8').replace(/^BEGIN;/m,'').replace(/^COMMIT;/m,'');
let passed=0;
async function fails(fn,pattern){await c.query('SAVEPOINT expected_failure');try{await fn();throw new Error('Expected rejection')}catch(e){assert.match(e.message,pattern);passed++}finally{await c.query('ROLLBACK TO SAVEPOINT expected_failure')}}
async function write(table,payload,id=null,expected=null,confirmed=true,operation=id?'update':'insert'){
 const {rows}=await c.query('select public.strategy_write($1,$2,$3,$4,$5,$6) result',[table,operation,payload,id,expected,confirmed]);return rows[0].result;
}
(async()=>{
 await c.connect();await c.query('BEGIN');await c.query("SET LOCAL lock_timeout='3s'; SET LOCAL statement_timeout='20s'");
 if(!(await c.query("select 1 from pg_proc where proname='strategy_write'")).rowCount)await c.query(migration);
 const actor=(await c.query("select id,session_version from public.profiles where is_super_admin and active limit 1")).rows[0];assert(actor,'Need an existing quality/admin profile');
 await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor.id,role:'authenticated',sv:actor.session_version})]);
 // auth.uid implementation may use the individual GUC in this local stack.
 await c.query("select set_config('request.jwt.claim.sub',$1,true)",[actor.id]);
 const org=(await c.query("insert into public.organizations(name) values ('Codex transactional QA') returning id")).rows[0].id;
 const org2=(await c.query("insert into public.organizations(name) values ('Codex other QA') returning id")).rows[0].id;
 const campaign=(await c.query("insert into public.swot_campaigns(organization_id,name) values($1,'QA SWOT') returning id",[org])).rows[0].id;
 await c.query('SET LOCAL ROLE authenticated');
 await fails(()=>write('swot_items',{campaign_id:campaign,quadrant:'strengths',title:'Not approved'},null,null,false),/Validação humana/);
 await fails(()=>c.query("insert into public.swot_items(campaign_id,quadrant,title) values($1,'strengths','bypass')",[campaign]),/permission denied/);
 const strength=await write('swot_items',{campaign_id:campaign,quadrant:'strengths',title:'Equipa especializada'});
 const opportunity=await write('swot_items',{campaign_id:campaign,quadrant:'opportunities',title:'Mercado internacional'});
 await fails(()=>write('tows_crossings',{campaign_id:campaign,strategy_type:'so',name:'Missing factors'}),/dois fatores/);
 const cross=await write('tows_crossings',{campaign_id:campaign,strategy_type:'so',name:'Expandir',s_item_id:strength.id,o_item_id:opportunity.id,disposition:'opportunity'});
 const risk=await write('risk_opportunities',{organization_id:org,type:'opportunity',title:'Internacionalização',probability:3,impact:4,source_tows_id:cross.id});assert.equal(risk.score,12);passed++;
 await fails(()=>write('risk_opportunities',{organization_id:org2,type:'risk',title:'Cross org',probability:3,impact:4,source_tows_id:cross.id}),/outra organização/);
 const edited=await write('risk_opportunities',{...{title:'Expandir internacionalmente',probability:4,impact:5}},risk.id,risk.updated_at);assert.equal(edited.score,20);passed++;
 await fails(()=>write('risk_opportunities',{title:'Stale'},risk.id,'2000-01-01T00:00:00Z'),/registo mudou/);
 await fails(()=>write('risk_opportunities',{score:5},risk.id,risk.updated_at),/Campo não editável/);
 const objective=await write('strategic_objectives',{organization_id:org,code:'QA1',name:'Expandir',risk_ids:[risk.id]});
 await fails(()=>write('strategic_objectives',{organization_id:org2,code:'QA2',name:'Wrong org',risk_ids:[risk.id]}),/outra organização/);
 const action=await write('strategic_actions',{objective_id:objective.id,name:'Pesquisa',status:'completed',progress:30});assert.equal(action.progress,100);assert(action.completed_at);passed++;
 const kpi=await write('kpis',{organization_id:org,objective_id:objective.id,code:'QA-KPI',name:'Leads',frequency:'monthly',direction:'higher_is_better'});
 await fails(()=>write('kpi_targets',{kpi_id:kpi.id,period:'2026-13',target_value:10}),/Período incompatível/);
 await fails(()=>write('kpi_targets',{kpi_id:kpi.id,period:'2026-09',target_value:10,warning_value:20}),/Alerta incompatível/);
 const target=await write('kpi_targets',{kpi_id:kpi.id,period:'2026-09',target_value:10,warning_value:5});
 const result=await write('kpi_results',{kpi_id:kpi.id,period:'2026-09',value:0});assert.equal(result.value,0);assert.equal(result.entered_by,actor.id);passed++;
 await write('kpi_targets',{target_value:12},target.id,target.updated_at);
 await fails(()=>write('kpis',{frequency:'yearly'},kpi.id,kpi.updated_at),/histórico/);
 await fails(()=>write('strategic_objectives',{},objective.id,objective.updated_at,true,'delete'),/ações\/KPIs/);
 const history=(await c.query('select * from strategy_history where record_id=$1 order by reviewed_at',[target.id])).rows;assert.equal(history.length,2);assert.equal(history[1].before_data.target_value,10);assert.equal(history[1].after_data.target_value,12);passed++;
 await c.query('ROLLBACK');console.log(JSON.stringify({passed,rollback:true,migration:'0051'}));
})().catch(async e=>{await c.query('ROLLBACK').catch(()=>{});console.error(e.message, e.position, e.where); if(e.position) console.error(migration.slice(Number(e.position)-150,Number(e.position)+150));process.exitCode=1}).finally(()=>c.end());

