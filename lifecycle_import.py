import os
# -*- coding: utf-8 -*-
"""
Registo do projeto de melhoria "LifeCycle RH Samsys" no programa da Qualidade.
--dry-run simula, --commit grava (transação + rollback em erro). Idempotente por reference.
Só cria a OM (projeto) + ações de referência/entregáveis; não executa tarefas RH reais.
"""
import sys, json, psycopg2
U_GERAL="5735e898-ac3c-4946-9ab8-2cc3e1c63079"
AREA_RH="af3f3610-562b-467b-b5bd-a014c0326e07"
ORIG_MELHORIA="50cb7984-1525-4d4f-9055-3ff1aabe8f2f"
DB=dict(host="127.0.0.1",port=5432,user="postgres",password=os.environ["PGPASSWORD"],dbname="samsys_qualidade")
DRY="--dry-run" in sys.argv

# ---- conteúdo (factos do relatório; datas/valores não inventados) ----
PROJ={
 "reference":"LCY-PROJ","name":"LifeCycle RH Samsys",
 "desc":"Projeto de melhoria para automatizar o ciclo de vida do colaborador (recrutamento, seleção, admissão, onboarding, vida ativa e offboarding). Processo: Recursos Humanos / Talento. Objetivo: reduzir tarefas manuais e duplicação de informação e assegurar rastreabilidade. Documento base: Relatorio_Projeto_LifeCycle_RH_Samsys_v5.docx (v1.0, 02/09/2026). Dono funcional: RH / Talento. Estado: proposta; âmbito e integrações por validar.",
}

# (id, prioridade, seção, titulo, equipa, aceitação/evidencia)
A=[
 ("B01","P0","backlog","Definir modelo de dados, LifeCycle ID e estados iniciais","dev-samsys","Caso pesquisável com ID, origem, estado e owner (RF-01..03). Evidência: modelo de dados e lista de estados aprovada."),
 ("B02","P0","backlog","Implementar receção de candidatura com validações e upload","dev-samsys","Candidatura válida criada sem intervenção RH (T01). RF-02, RF-06."),
 ("B03","P0","backlog","Associar candidatura a vaga + espontâneas + encaminhamento","dev-samsys/rh-talentos","100% das entradas ficam numa fila definida (RF-02)."),
 ("B04","P0","backlog","Definir contrato de integração e tratamento de erros","dev-samsys/printanyway","Evento de teste passa de uma solução à outra e retorna confirmação (RF-14)."),
 ("B05","P0","backlog","Definir matriz de documentos, templates e metadados","printanyway/rh-talentos","Cada tipo tem regra, template, destino e owner (RF-05, RF-07)."),
 ("B06","P0","backlog","Gerar, enviar e arquivar 1 cenário completo","printanyway","Evidência ligada ao mesmo LifeCycle ID (RF-06, RF-07)."),
 ("B07","P0","backlog","Definir gates e checklists de admissão/estágio/saída","rh-talentos","Critérios objetivos de pronto aprovados (ADM-P0-04, RF-03)."),
 ("B08","P1","backlog","Implementar tarefas internas e notificações por responsável","m365/dev-samsys","Sem reencaminhamento manual nos cenários piloto (RF-04, RF-08)."),
 ("B09","P1","backlog","Tratar duplicados e retry de falhas","dev-samsys/printanyway","Erro não cria novo caso/documento duplicado (T02, T09)."),
 ("B10","P1","backlog","Desenvolver dashboard operacional","rh-talentos/dev-samsys","Aging, bloqueios e SLA visíveis (RF-12)."),
 ("B11","P1","backlog","Automatizar fecho de vaga e comunicações a candidatos","rh-talentos/printanyway","Comunicação consistente e logada (T04, E01-E12)."),
 ("B12","P1","backlog","Implementar fluxo de protocolo de estágio","rh-talentos/printanyway","Protocolo percorre criação-aprovação-envio-arquivo (T06)."),
 ("B13","P1","backlog","Implementar Ready for Day 1","rh-talentos/m365","Tarefas críticas visíveis por nova admissão (T07, ADM-P0-06)."),
 ("B14","P1","backlog","Implementar offboarding integrado","rh-talentos/m365/printanyway","Checklist + documentos + cancelamentos com fecho controlado (T10, RF-10)."),
 ("B15","P2","backlog","Desenvolver pool de talento e pesquisa avançada","rh-talentos/dev-samsys","Pesquisa por função/competências/estado (RF-13)."),
 ("B16","P2","backlog","Definir métricas de experiência e melhoria contínua","rh-talentos","Feedback onboarding/offboarding integrado no reporting."),
 ("B17","P0","backlog","Integração PHC: criação/atualização da ficha de funcionário","enterprise-phc","Admissão aprovada cria/atualiza ficha no PHC sem redigitação; sucesso/erro registado no LifeCycle (T11, ADM-P0-03). NOTA: relatório lista Dev/RH; secções atribuem integração PHC à Enterprise/PHC (diverge — por validar)."),
 ("B18","P0","backlog","Seguro Montepio: recolha documental + email com anexos","rh-talentos/printanyway","Documentos pedidos na admissão; envio só quando completos; email/anexos/timestamp/resultado registados (T12, ADM-P0-02)."),
 # plano de ação imediato (§14)
 ("PA01","P1","plano-accao","Realizar workshop único de processo ponta-a-ponta e validar TO-BE e fronteiras","rh/dev/enterprise/printanyway","Mapa aprovado + decisões registadas."),
 ("PA02","P1","plano-accao","Fechar dicionário de dados, estados e LifeCycle ID","rh/dev/enterprise/printanyway","Data contract v1."),
 ("PA03","P1","plano-accao","Inventariar emails, documentos e pastas atuais","rh/printanyway","Matriz comunicação/documento/arquivo."),
 ("PA04","P1","plano-accao","Transformar trabalho existente em backlog integrado","todos","Backlog P0/P1 com owners."),
 ("PA05","P1","plano-accao","Selecionar golden path de piloto (candidatura->admissão normal)","todos","Cenário piloto e dados de teste."),
 ("PA06","P0","plano-accao","Implementar 1 cenário ponta-a-ponta incluindo integração PHC","dev/enterprise/printanyway","Demo funcional conjunta LifeCycle->PHC + documentos."),
 ("PA07","P0","plano-accao","Executar UAT T01-T09 e corrigir bloqueadores","rh/owners","Relatório UAT."),
 ("PA08","P1","plano-accao","Pilotar com uma vaga/estágio controlado","rh/líder-piloto","Métricas + issues reais."),
 ("PA09","P1","plano-accao","Adicionar offboarding e cenários de exceção","todos","Cobertura completa LifeCycle."),
 ("PA10","P1","plano-accao","Executar Go-live e melhoria contínua","rh","Processo oficial + dashboard."),
 ("PA11","P1","plano-accao","Validar mapeamento funcional/técnico dos campos PHC e checklist documental Montepio","rh/enterprise/dev/printanyway","Mapa de campos PHC aprovado + regra de gate documental do seguro."),
]

# comunicações a implementar E01-E12 (não enviar agora)
E=[
 ("E01","comunicacoes","Enviar Ficha de Identificação v4 + lista única de documentos de admissão/seguro (trigger A01)"),
 ("E02","comunicacoes","Admissão — workflow/tarefas internas (RH, líder, direção) em vez de email (trigger decisão aprovada)"),
 ("E03","comunicacoes","Admissão SS/Census — email automático externo (trigger A05)"),
 ("E04","comunicacoes","Criação de dados PHC — integração obrigatória; email apenas em exceção técnica"),
 ("E05","comunicacoes","Novo colaborador — OPERACIONAL: tarefas internas (Sistemas + Logística)"),
 ("E06","comunicacoes","Integração — tarefa interna automática (Comunicação)"),
 ("E07","comunicacoes","Equipa [NOMEEQUIPA] [NOME] Welcome — email/Teams interno"),
 ("E08","comunicacoes","Seguro Saúde Montepio — email automático externo (trigger A04+pack completo)"),
 ("E09","comunicacoes","Seguro Estágio ATIVAR — email externo condicional"),
 ("E10","comunicacoes","Dados para agendamento consulta HST — email externo"),
 ("E11","comunicacoes","Incentivo à Atração e Fidelização — tarefa/email condicional (Financeiro + RH)"),
 ("E12","comunicacoes","Confirmação Ready for Day 1 — notificação interna"),
]

# cenários de teste / aceitação T01-T12
T=[
 ("T01","testes","Candidatura normal: submeter->criar ID->atribuir vaga->notificar owner; sem email manual"),
 ("T02","testes","Candidatura duplicada: bloqueada/sinalizada segundo regra"),
 ("T03","testes","Entrevista: mover->convite->feedback; histórico completo"),
 ("T04","testes","Não selecionado: template correto, envio logado, retenção/arquivo"),
 ("T05","testes","Selecionado: aceitar oferta->pré-admissão; dados migram sem redigitação"),
 ("T06","testes","Estágio: selecionado->protocolo; percurso específico rastreado"),
 ("T07","testes","Ready for Day 1: data de entrada; tarefas por área com prazos; bloqueios visíveis"),
 ("T08","testes","Alteração de data: datas dependentes atualizadas sem tarefas incoerentes"),
 ("T09","testes","Falha de email/documento: erro visível, retry/ação, sem falso concluído"),
 ("T10","testes","Saída: rescisão->offboarding; documentos e cancelamentos antes de fecho"),
 ("T11","testes","PHC ficha: aprovar admissão->enviar dados->receber confirmação; erro bloqueia gate"),
 ("T12","testes","Seguro Montepio: sem envio se faltar documento; anexos corretos; evidência integral"),
]

# riscos R1-R10
R=[
 ("R1","risco","Duas equipas construírem soluções paralelas sem contrato de integração — mitigação: arquitetura e backlog únicos, demo conjunta"),
 ("R2","risco","Automatizar fluxo antigo com desperdícios — mitigação: aprovar TO-BE e gates antes de automatizar"),
 ("R3","risco","PrintAnyWay limitar-se a email/arquivo sem fechar casos de negócio — mitigação: cenários, entregáveis e critérios por fase"),
 ("R4","risco","RH continuar a ser middleware manual entre soluções — mitigação: integrações/eventos obrigatórios e tarefas por owner"),
 ("R5","risco","Dados duplicados ou inconsistentes — mitigação: master record, IDs, validações, deduplicação"),
 ("R6","risco","Acesso indevido a dados pessoais — mitigação: perfis, menor privilégio, testes de permissões, validação RGPD"),
 ("R7","risco","Templates desatualizados — mitigação: owner de template, versão, data de revisão"),
 ("R8","risco","Automação falhar silenciosamente — mitigação: monitoring, alertas, retry, dead-letter"),
 ("R9","risco","Baixa adoção por líderes/áreas — mitigação: UX simples, formação breve, piloto, disciplina"),
 ("R10","risco","Go-live sem baseline de indicadores — mitigação: medição AS-IS mínima antes do piloto"),
]

# decisões pendentes D01-D11
D=[
 (f"D0{i}","decisao",txt) for i,txt in enumerate([
  "Sistema/registo master do LifeCycle e local do estado oficial",
  "Interface técnica entre Desenvolvimento e PrintAnyWay",
  "Tarefas internas em M365/Teams/Planner vs workflow PrintAnyWay",
  "Documentos gerados automaticamente vs validação humana antes do envio",
  "Aprovações com valor formal e evidência",
  "Política de retenção de CVs/candidaturas e dossiers",
  "Perfis com acesso a dados pessoais por fase",
  "SLAs por fase e escalonamentos",
  "Sistema dos dashboards e owner dos indicadores",
  "Modelo de suporte pós go-live: incidente técnico vs alteração funcional",
  "Confirmar fronteiras técnicas: Dev programa LifeCycle; Enterprise/PHC integra ficha; PrintAnyWay documental/comunicações",
 ],1)]

# gates 0-6
G=[
 ("GATE0","gate","Gate 0 — Scope Freeze: TO-BE, papéis, dados, integrações e backlog P0 aprovados"),
 ("GATE1","gate","Gate 1 — Intake Ready: receção de candidaturas testada e integrada com fila única"),
 ("GATE2","gate","Gate 2 — Core Workflow Ready: estados, owners, tarefas, templates e arquivo operacionais"),
 ("GATE3","gate","Gate 3 — Hire/Intern Ready: seleção->admissão/estágio->ficha PHC->seguro Montepio->Ready for Day 1 testado"),
 ("GATE4","gate","Gate 4 — Exit Ready: offboarding testado com documentos e cancelamentos"),
 ("GATE5","gate","Gate 5 — Pilot Accepted: piloto sem defeitos críticos; métricas e suporte ativos"),
 ("GATE6","gate","Gate 6 — Go-Live: processo oficial; instruções antigas descontinuadas; owners treinados"),
]

# admissão A01-A20 -> checklist/spec por gate (não executar)
ADM=[
 ("ADM-CHK-P0","admissao-checklist","Checklist de admissão Gate P0 (A01-A13, A15-A20): decisão+condições, Ficha de Identificação v4 + pedido documental único, recolha, validação, condições finais, SS/Census, ficha PHC, contrato, acessos, HST, Seguro Montepio, incentivo, Day1."),
 ("ADM-CHK-P1","admissao-checklist","Checklist de admissão Gate P1 (A17-A20 + itens comunicação/welcome): notificação equipa, acolhimento/indução, welcome kit, docs Day 1."),
 ("ADM-CHK-ESTAGIO","admissao-checklist","Checklist específica de estágio (elegibilidade, protocolo, seguro estágio quando aplicável)."),
 ("ADM-CHK-OFF","admissao-checklist","Checklist de offboarding (documentos, devoluções, cancelamentos, entrevista de saída, arquivo final)."),
]

# --- simples:
ACTION_ITEMS = []
for it in A: ACTION_ITEMS.append((it[0],it[1],it[2],it[3],it[4],it[5]))
for i,it in enumerate(E,1): ACTION_ITEMS.append((f"E{i:02d}","comunicacoes","",it[2],"",f"Catálogo de comunicação a implementar. Trigger: {it[1]}"))
for i,it in enumerate(T,1): ACTION_ITEMS.append((f"T{i:02d}","testes","",it[2],"","Cenário de teste/aceitação.")
)
for it in R: ACTION_ITEMS.append((it[0],"risco","",it[2],"Riscos e mitigação do projeto",f"Risco: {it[2]}"))
for i,it in enumerate(D,1): ACTION_ITEMS.append((it[0],"decisao","",it[2],"RH/Dev/Enterprise/PrintAnyWay","Decisão pendente de validação.")
)
ACTION_ITEMS += [(f"GATE{g}","gate","",t,"RH","Marco do projeto; condição de saída definida.") for g,(a,b,t) in enumerate(G)]
ACTION_ITEMS += [(a,"admissao-checklist","",t,"RH","Checklist/especificação do processo de admissão (não executada agora).") for a,b,t in ADM]

# ---- dry-run: mostrar contagens ----
print("MODO:", "DRY-RUN" if DRY else "EXECUÇÃO")
print("Projeto 1 OM +", len(ACTION_ITEMS), "ações de referência")
for pr,c in __import__('collections').Counter(x[1] for x in ACTION_ITEMS).items():
    print("  ", pr, c)
print("Prioridades:", dict(__import__('collections').Counter(x[1] for x in [it for it in A])))
if DRY: sys.exit(0)

conn=psycopg2.connect(**DB); conn.autocommit=False; cur=conn.cursor()
try:
    # tags
    tags_pool=set()
    for it in ACTION_ITEMS: tags_pool.add(it[1])  # secção
    tags_pool.update(["P0","P1","P2","rh-talentos","dev-samsys","enterprise-phc","printanyway","lifecycle-rh"])
    # PR são secções; também prioridades são tags
    tag_id={}
    for t in tags_pool:
        cur.execute("insert into public.quality_tags(name) values (%s) on conflict (name) do nothing",(t,))
    cur.execute("select name,id from public.quality_tags where name=any(%s)",(list(tags_pool),))
    tag_id={r[0]:r[1] for r in cur.fetchall()}

    # OM projeto (upsert por reference)
    cur.execute("select id from public.quality_occurrences where reference='LCY-PROJ'")
    ex=cur.fetchone()
    if ex:
        cur.execute("update quality_occurrences set type='OM',year=%s,origin_id=%s,area_id=%s,occurrence_date=%s,description=%s,responsible_user_id=%s,status=%s,created_by=%s where id=%s",
          (2026,ORIG_MELHORIA,AREA_RH,"2026-09-17",PROJ['desc'],U_GERAL,"IN_PROGRESS",U_GERAL,ex[0])); oid=ex[0]; ostat="updated"
    else:
        cur.execute("""insert into quality_occurrences(reference,type,year,origin_id,occurrence_date,area_id,description,responsible_user_id,status,created_by)
            values('LCY-PROJ','OM',2026,%s,%s,%s,%s,%s,'IN_PROGRESS',%s) returning id""",
            (ORIG_MELHORIA,"2026-09-17",AREA_RH,PROJ['desc'],U_GERAL,U_GERAL)); oid=cur.fetchone()[0]; ostat="created"
    # tags do projeto
    for t in ["lifecycle-rh","backlog"]:
        if t in tag_id: cur.execute("insert into quality_occurrence_tags(occurrence_id,tag_id) values(%s,%s) on conflict do nothing",(oid,tag_id[t]))

    created=updated=0
    for ref,sec,pr,txt,eq,acc in ACTION_ITEMS:
        desc=f"{txt}. [Secção: {pr}] [Prioridade: {sec}] [Equipa: {eq}] {acc}".replace(" | "," // ")
        cur.execute("select id from quality_actions where reference=%s",(ref,))
        ex=cur.fetchone()
        if ex:
            cur.execute("update quality_actions set occurrence_id=%s,description=%s,responsible_user_id=%s,status=%s where id=%s",
              (oid,desc,U_GERAL,"IN_PROGRESS",ex[0])); updated+=1
        else:
            cur.execute("insert into quality_actions(reference,occurrence_id,description,responsible_user_id,status,created_by) values(%s,%s,%s,%s,'IN_PROGRESS',%s) returning id",
              (ref,oid,desc,U_GERAL,U_GERAL)); created+=1
    # TODO: tags de prioridade por ação (P0/P1/P2) — usando o modelo: sem coluna p/ ação; tagged na seção. Marcamos via nome.
    conn.commit()
    print("PROJETO:", ostat, "UUID:", oid)
    print("Ações criadas:", created, "| atualizadas:", updated)
    conn.close()
except Exception as e:
    conn.rollback(); print("ERRO -> ROLLBACK:", e); conn.close(); raise