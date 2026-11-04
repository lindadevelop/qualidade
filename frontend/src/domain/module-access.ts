export type AppModule = 'quality' | 'strategy' | 'lifecycle'
export function moduleForPath(path:string):AppModule|null {
 if(path.startsWith('/lifecycle-rh'))return 'lifecycle'
 if(path.startsWith('/estrategia')||['/reunioes','/apresentacoes','/administracao/frameworks','/administracao/templates-ppt','/administracao/conectores'].includes(path))return 'strategy'
 if(['/auditorias','/meu-trabalho','/pesquisa','/notificacoes','/qualidade','/dashboard','/ocorrencias','/acoes','/eficacia','/relatorios','/assistente-ia','/revisao-gestao'].some(p=>path===p||path.startsWith(p+'/')))return 'quality'
 return null
}
