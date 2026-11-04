const fail=message=>Object.assign(new Error(message),{status:400});
function validDate(v){if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(v))return false;const [y,m,d]=v.split('-').map(Number);return y>0&&m>0&&m<=12&&d>0&&d<=[31,y%4===0&&(y%100!==0||y%400===0)?29:28,31,30,31,30,31,31,30,31,30,31][m-1]}
function validateDates(p){for(const key of ['start_date','end_date','occurrence_date','deadline','new_deadline','effectiveness_due','implementation_due'])if(p[key]!=null&&p[key]!==''&&!validDate(p[key]))throw fail('Introduza uma data válida no formato dd/mm/aaaa.');for(const [start,end] of [['start_date','end_date']])if(p[start]&&p[end]&&p[end]<p[start])throw fail('A data de fim não pode ser anterior à data de início.');if(p.year!=null&&(!Number.isInteger(Number(p.year))||Number(p.year)<1||Number(p.year)>9999))throw fail('O ano deve ter até quatro dígitos.');for(const key of ['sent_at','responded_at'])if(p[key]&&(!validDate(String(p[key]).slice(0,10))||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})?$/.test(p[key])||Number.isNaN(Date.parse(p[key]))))throw fail('Introduza uma data e hora válidas.');}
const eligible=p=>p.active&&(p.roles||[p.role]).some(r=>['admin','quality','action_owner'].includes(r))&&(p.role==='admin'||p.module_access?.quality===true);
const approver=p=>p.active&&(p.roles||[p.role]).some(r=>['admin','quality','management'].includes(r))&&(p.role==='admin'||p.module_access?.quality===true);
function normVersion(name){return String(name).match(/(?:[:\s-])((?:19|20)\d{2})(?=\D|$)/)?.[1]||null}
async function saveScope(c,org,audit,p){
 const existing=(await c.query('select * from quality_audit_scope where audit_id=$1 for update',[audit.id])).rows;
 for(const [key,kind,col,table] of [['area_ids','area','area_id','quality_areas'],['standard_ids','standard','standard_id','quality_catalogs'],['site_names','site','site',null]]){
  if(!Object.hasOwn(p,key))continue;
  if(!Array.isArray(p[key])||p[key].some(v=>typeof v!=='string'||!v.trim()))throw fail('Seleciona um âmbito válido.');
  const values=[...new Set(p[key].map(v=>v.trim()))];
  for(const value of values){
   const old=existing.find(s=>s.kind===kind&&s[col]===value);
   if(table){const item=(await c.query(`select * from ${table} where id=$1 and organization_id=$2 for share`,[value,org])).rows[0];if(!item||!old&&!item.active||kind==='standard'&&item.kind!=='standard')throw fail('Seleciona apenas áreas e referenciais ativos desta empresa.');}
   if(!old)await c.query(`insert into quality_audit_scope(organization_id,audit_id,kind,${col}) values($1,$2,$3,$4)`,[org,audit.id,kind,value]);
  }
  for(const s of existing.filter(s=>s.kind===kind&&!values.includes(s[col]))){
   const used=(await c.query('select 1 from quality_occurrences where audit_id=$1 and (standard_scope_id=$2 or site_scope_id=$2 or ($3::uuid is not null and area_id=$3)) limit 1',[audit.id,s.id,s.area_id])).rowCount;
   if(used)throw fail('Este âmbito já está associado a constatações. Preserve a relação histórica.');
   await c.query('delete from quality_audit_scope where id=$1',[s.id]);
  }
 }
}
async function inheritContext(c,org,audit,p){
 const scope=(await c.query('select s.*,coalesce(a.active,c.active,true) active from quality_audit_scope s left join quality_areas a on a.id=s.area_id left join quality_catalogs c on c.id=s.standard_id where s.audit_id=$1',[audit.id])).rows;
 const choose=(kind,key,col)=>{const options=scope.filter(s=>s.kind===kind&&s.active);if(kind==='area'&&!options.length)throw fail('Esta auditoria não tem áreas/processos ativos associados. Edite a auditoria para definir o âmbito antes de registar a constatação.');if(!options.length){if(p[key])throw fail('Seleção fora do âmbito da auditoria.');return null}if(options.length===1){if(p[key]&&p[key]!==options[0][col])throw fail('Seleção fora do âmbito da auditoria.');return options[0][col]}if(!options.some(s=>s[col]===p[key]))throw fail('Selecione uma opção do âmbito da auditoria.');return p[key]};
 p.area_id=choose('area','area_id','area_id');p.standard_scope_id=choose('standard','standard_scope_id','id');p.site_scope_id=choose('site','site_scope_id','id');
 // General audit data lives only on the audit. Preserve explicit legacy values on old records.
 p.standard=null;p.site=null;
 const name=audit.kind==='EXTERNAL'?'Auditoria Externa':'Auditoria Interna';
 let origin=(await c.query('select id from quality_origins where organization_id=$1 and lower(name)=lower($2) order by active desc limit 1',[org,name])).rows[0];
 if(!origin)origin=(await c.query('insert into quality_origins(organization_id,name) values($1,$2) returning id',[org,name])).rows[0];
 p.origin_id=origin.id;
}
module.exports={validDate,validateDates,eligible,approver,normVersion,saveScope,inheritContext};
