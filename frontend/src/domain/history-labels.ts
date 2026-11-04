import {platformModules} from './platform-modules'
const actions:Record<string,string>={INSERT:'Registo criado',UPDATE:'Dados alterados',DELETE:'Registo eliminado',insert:'Registo criado',update:'Dados alterados',delete:'Registo eliminado',create:'Registo criado',edit:'Dados alterados',asset_replace:'Imagem atualizada',state:'Estado alterado',collect:'Contributos guardados',submit:'Participação submetida',context_review:'Contexto validado',propose:'Grupos sugeridos',validate:'Grupo publicado'}
export function historyAction(row:Record<string,any>){if(row.operation==='asset_replace')return ({logo:'Logótipo principal substituído',icon:'Ícone compacto atualizado',favicon:'Favicon atualizado'} as Record<string,string>)[row.after_data?.kind]||'Imagem atualizada';return actions[row.operation]||'Alteração registada'}
export function readableChanges(table:string,row:Record<string,any>){
 const before=row.before_data||{},after=row.after_data||{},fields=platformModules[table]?.fields||[]
 return fields.filter(f=>!f.key.endsWith('_id')&&JSON.stringify(before[f.key])!==JSON.stringify(after[f.key])&&(f.key in before||f.key in after)).map(f=>{
 const display=(value:any)=>value==null?'—':typeof value==='boolean'?(value?'Sim':'Não'):f.options?.find(o=>o.value===value)?.label||String(value)
 return `${f.label}: ${display(before[f.key])} → ${display(after[f.key])}`
 })
}
