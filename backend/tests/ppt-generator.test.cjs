const {test}=require('node:test');
const assert=require('node:assert/strict'),http=require('node:http'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createServer}=require('../ppt-generator');
test('PPT authentication, full payload, failed dependencies and metadata cleanup',async()=>{
 const id='00000000-0000-0000-0000-000000000001';let mode='ok',payload,metadata;
 const dataServer=http.createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json');
  if(req.headers.authorization!=='Bearer valid'){res.statusCode=401;return res.end('{}')}
  if(req.url.startsWith('/auth/'))return res.end(JSON.stringify({id}));
  if(mode==='failed-source'&&req.url.startsWith('/kpis')){res.statusCode=503;return res.end('{}')}
  if(req.method==='POST'){
   if(mode==='failed-metadata'){res.statusCode=403;return res.end('{}')}
   let body='';for await(const c of req)body+=c;metadata=JSON.parse(body);res.statusCode=201;return res.end(JSON.stringify([metadata]));
  }
  const table=req.url.split('?')[0].slice(1);
  const rows={ppt_templates:[{id,name:'Resumo',active:true,is_default:true,sections:['risks']}],organizations:[{id,name:'QA',slug:'qa'}],swot_campaigns:[{id,name:'Campanha'}],swot_items:[{id,title:'Força',quadrant:'strengths'}],tows_crossings:[{id,name:'Cruzar'}],strategic_objectives:[{id,name:'Objetivo'}],strategic_actions:[{id,name:'Ação'}],kpis:[{id,name:'KPI'}],kpi_targets:[{id,period:'2026-09',target_value:10}],kpi_results:[{id,period:'2026-09',value:0}],generated_files:metadata?[metadata]:[]};
  res.end(JSON.stringify(rows[table]||[]));
 });
 await new Promise(r=>dataServer.listen(0,'127.0.0.1',r));const source=`http://127.0.0.1:${dataServer.address().port}`;
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'samsys-ppt-test-'));
 const server=createServer({rest:source,auth:source,outputDir:dir,generate:async(p,file)=>{payload=p;fs.writeFileSync(file,'test-pptx')}});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const base=`http://127.0.0.1:${server.address().port}`;
 const generate=(template_id)=>fetch(`${base}/ppt/generate`,{method:'POST',headers:{Authorization:'Bearer valid'},body:JSON.stringify({organization_id:id,template_id})});
 try {
  assert.equal((await fetch(`${base}/ppt/generate`,{method:'POST'})).status,401);
  assert.equal((await fetch(`${base}/ppt/download/${id}`)).status,401);
  let res=await generate();assert.equal(res.status,200);const result=await res.json();
  assert.equal(payload.objectives[0].actions[0].name,'Ação');assert.equal(payload.kpis[0].results[0].value,0);assert.equal(payload.swotCampaigns[0].crossings[0].name,'Cruzar');
  assert.equal((await fetch(`${base}${result.url}`,{headers:{Authorization:'Bearer valid'}})).status,200);
  assert.equal(payload.template.name,'Resumo');assert.equal(metadata.template_id,id);
  assert.equal((await generate('00000000-0000-0000-0000-000000000099')).status,400);
  mode='failed-source';assert.equal((await generate()).status,502);assert.equal(fs.readdirSync(dir).length,1);
  mode='failed-metadata';assert.equal((await generate()).status,403);assert.equal(fs.readdirSync(dir).length,1);
 } finally {server.closeAllConnections();dataServer.closeAllConnections();await Promise.all([new Promise(r=>server.close(r)),new Promise(r=>dataServer.close(r))]);fs.rmSync(dir,{recursive:true,force:true})}
});
