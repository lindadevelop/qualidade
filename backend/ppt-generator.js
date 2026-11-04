const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function createServer(options = {}) {
 const outputDir=options.outputDir||path.join(__dirname,'generated-pptx');
 const rest=options.rest||process.env.POSTGREST_URL||'http://127.0.0.1:3001';
 const auth=options.auth||process.env.AUTH_SERVER_URL||'http://127.0.0.1:3002';
 fs.mkdirSync(outputDir,{recursive:true});
 async function request(url,token,init={}) {
  const res=await fetch(url,{...init,headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`,apikey:'anon',...init.headers},signal:AbortSignal.timeout(20000)});
  if(!res.ok) { const e=new Error(`Serviço de dados: ${res.status}`);e.status=[401,403].includes(res.status)?res.status:502;throw e; }
  return res.status===204?null:res.json();
 }
 const get=(route,token)=>request(`${rest}${route}`,token);
 const generate=options.generate||((payload,file)=>new Promise((resolve,reject)=>{
  const py=spawn(process.env.PPT_PYTHON||'python',[path.join(__dirname,'ppt-template.py'),file],{stdio:['pipe','pipe','pipe'],windowsHide:true,env:{...process.env,PYTHONIOENCODING:'utf-8'}});
  const timeout=setTimeout(()=>{py.kill();reject(new Error('Tempo limite PPT'));},120000);
  let errors='';py.stdout.resume();py.stderr.on('data',c=>errors=(errors+c).slice(-4000));
  py.on('error',e=>{clearTimeout(timeout);reject(e)});py.on('close',code=>{clearTimeout(timeout);code===0?resolve():reject(new Error(`PPT ${code}: ${errors}`))});
  py.stdin.on('error',()=>{});py.stdin.end(JSON.stringify(payload));
 }));
 const json=(res,status,data)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data))};
 return http.createServer(async(req,res)=>{
  const url=new URL(req.url,'http://localhost'),token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
  res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Headers','authorization, apikey, content-type');res.setHeader('Access-Control-Allow-Methods','GET, POST, OPTIONS');
  if(req.method==='OPTIONS')return json(res,204,null);
  if(req.method==='GET'&&url.pathname==='/ppt/health')return json(res,200,{ok:true,service:'samsys-ppt',version:2});
  let partialFile;
  try {
   if(!token)return json(res,401,{error:'Não autorizado'});
   const user=await request(`${auth}/auth/v1/user`,token);if(!user?.id)return json(res,401,{error:'Não autorizado'});
   if(req.method==='GET'&&url.pathname.startsWith('/ppt/download/')) {
    const id=url.pathname.slice('/ppt/download/'.length);if(!UUID.test(id))return json(res,404,{error:'Ficheiro não encontrado'});
    const [record]=await get(`/generated_files?id=eq.${id}&status=eq.ready&select=id,name,organization_id`,token);
    const file=path.join(outputDir,`${id}.pptx`);if(!record||!fs.existsSync(file))return json(res,404,{error:'Ficheiro não encontrado'});
    const buffer=fs.readFileSync(file);res.writeHead(200,{'Content-Type':'application/vnd.openxmlformats-officedocument.presentationml.presentation','Content-Length':buffer.length,'Content-Disposition':`attachment; filename*=UTF-8''${encodeURIComponent(record.name)}`,'Cache-Control':'private, no-store'});return res.end(buffer);
   }
   if(req.method!=='POST'||url.pathname!=='/ppt/generate')return json(res,404,{error:'Rota não encontrada'});
   let body='';for await(const chunk of req){body+=chunk;if(Buffer.byteLength(body)>65536)return json(res,413,{error:'Pedido demasiado grande'})}
   let input;try{input=JSON.parse(body)}catch{return json(res,400,{error:'JSON inválido'})}
   const {organization_id:orgId,meeting_id:meetingId,template_id:templateId}=input;
   if(!UUID.test(orgId)||meetingId&&!UUID.test(meetingId)||templateId&&!UUID.test(templateId))return json(res,400,{error:'Identificador inválido'});
   const [org]=await get(`/organizations?id=eq.${orgId}&limit=1`,token);if(!org)return json(res,404,{error:'Organização não encontrada'});
   const names=['swot_campaigns','risk_opportunities','strategic_objectives','kpis','meetings','decisions','brand_kits','ppt_templates'];
   const [campaigns,risks,objectives,kpis,meetings,decisions,kits,templates]=await Promise.all(names.map(t=>get(`/${t}?organization_id=eq.${orgId}&order=created_at`,token)));
   const meeting=meetingId?meetings.find(m=>m.id===meetingId):null;if(meetingId&&!meeting)return json(res,400,{error:'Reunião de outra organização'});
   const template=templateId?templates.find(t=>t.id===templateId&&t.active):templates.find(t=>t.active&&t.is_default);
   if(templateId&&!template)return json(res,400,{error:'Template inativo ou de outra organização'});
   const swotCampaigns=await Promise.all(campaigns.filter(c=>!c.is_demo&&c.status!=='archived').map(async c=>({...c,items:await get(`/swot_items?campaign_id=eq.${c.id}&order=order_index`,token),crossings:await get(`/tows_crossings?campaign_id=eq.${c.id}&order=created_at`,token)})));
   const detailedObjectives=await Promise.all(objectives.map(async o=>({...o,actions:await get(`/strategic_actions?objective_id=eq.${o.id}&order=created_at`,token)})));
   const detailedKpis=await Promise.all(kpis.map(async k=>({...k,targets:await get(`/kpi_targets?kpi_id=eq.${k.id}&order=period`,token),results:await get(`/kpi_results?kpi_id=eq.${k.id}&order=period`,token)})));
   const id=crypto.randomUUID(),name=`${org.slug||'org'}-strategy-${new Date().toISOString().slice(0,10)}-${id.slice(0,6)}.pptx`;
   partialFile=path.join(outputDir,`${id}.pptx`);
   const brandKit=kits.find(k=>k.is_default)||kits[0];if(brandKit?.logo_asset_id){const [asset]=await get(`/brand_assets?id=eq.${brandKit.logo_asset_id}&organization_id=eq.${orgId}`,token);if(asset)brandKit.logo_base64=asset.content_base64;}
   await generate({id,name,template,organization:org,brandKit,meeting,swotCampaigns,risks,objectives:detailedObjectives,kpis:detailedKpis,decisions,generatedAt:new Date().toISOString()},partialFile);
   const size=fs.statSync(partialFile).size;
   await request(`${rest}/generated_files`,token,{method:'POST',headers:{Prefer:'return=representation'},body:JSON.stringify({id,organization_id:orgId,template_id:template?.id||null,meeting_id:meetingId||null,name,file_type:'pptx',file_path:`${id}.pptx`,file_size:size,status:'ready',generated_by:user.id,generated_at:new Date().toISOString()})});
   partialFile=null;return json(res,200,{id,name,size,url:`/ppt/download/${id}`});
  } catch(e){if(partialFile)fs.rmSync(partialFile,{force:true});console.error('[ppt]',e.message);return json(res,e.status||500,{error:e.status===401?'Sessão expirada. Inicia sessão novamente.':'Não foi possível concluir a exportação. Verifica os serviços e tenta novamente.'})}
 });
}
if(require.main===module)createServer().listen(Number(process.env.PPT_PORT||3007),'127.0.0.1',()=>console.log('[ppt-generator] pronto'));
module.exports={createServer};
