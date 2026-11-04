export interface CsvResult {codigo:string;periodo:string;valor:number;notas:string}
export function parseKpiCsv(text:string):CsvResult[] {
 if(text.length>1000000)throw new Error('O ficheiro excede 1 MB.')
 text=text.replace(/^\uFEFF/,'');const first=text.split(/\r?\n/)[0]||'';const sep=first.includes(';')?';':','
 const rows:string[][]=[];let row:string[]=[],cell='',quoted=false,closed=false
 for(let i=0;i<text.length;i++){
  const c=text[i]!
  if(quoted){if(c==='"'){if(text[i+1]==='"'){cell+='"';i++}else {quoted=false;closed=true}}else cell+=c;continue}
  if(c==='"'){if(cell||closed)throw new Error('Aspas CSV inválidas.');quoted=true;continue}
  if(c===sep){row.push(cell);cell='';closed=false;continue}
  if(c==='\n'||c==='\r'){if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell);if(row.some(v=>v.trim()))rows.push(row);row=[];cell='';closed=false;continue}
  if(closed)throw new Error('Conteúdo depois das aspas de fecho.');cell+=c
 }
 if(quoted)throw new Error('Aspas CSV por fechar.')
 row.push(cell);if(row.some(v=>v.trim()))rows.push(row)
 const header=rows.shift()?.map(c=>c.trim().toLowerCase());if(header?.join(',')!=='codigo,periodo,valor,notas')throw new Error('Cabeçalho esperado: codigo;periodo;valor;notas')
 if(!rows.length||rows.length>500)throw new Error('Importa entre 1 e 500 linhas.')
 const seen=new Set<string>()
 return rows.map((r,i)=>{if(r.length!==4)throw new Error(`Linha ${i+2}: quatro colunas obrigatórias.`)
  const [codigo,periodo,raw,notas]=r.map(c=>c.trim()) as [string,string,string,string];const value=raw.replace(',','.');
  if(!codigo||!periodo||!/^[-+]?\d+(\.\d+)?$/.test(value)||!Number.isFinite(Number(value)))throw new Error(`Linha ${i+2}: código, período ou valor inválido.`)
  const key=JSON.stringify([codigo,periodo]);if(seen.has(key))throw new Error(`Linha ${i+2}: código e período duplicados.`);seen.add(key)
  return {codigo,periodo,valor:Number(value),notas}
 })
}
