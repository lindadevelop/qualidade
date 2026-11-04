-- ============================================================
-- demo_lifecycle.sql — Dados demo do módulo LifeCycle RH
-- APAGA e recria APENAS as tabelas lifecycle_* (vagas, casos,
-- tarefas, comunicações). NÃO toca em ocorrências/ações.
-- Idempotente: pode correr várias vezes.
-- ============================================================

DO $$
DECLARE
  -- vagas
  v_dev  uuid; v_com uuid; v_est uuid; v_fin uuid; v_sis uuid;
  -- casos
  c_rec  uuid; c_fil  uuid; c_tri  uuid; c_ent  uuid; c_sel  uuid;
  c_dupl uuid; c_pre  uuid; c_emip uuid; c_rdy  uuid; c_est  uuid;
  c_ati  uuid; c_off  uuid; c_enc  uuid; c_nsel uuid; c_pool uuid;
  r      record;
BEGIN

  -- -------- limpeza só do módulo LifeCycle --------
  TRUNCATE lifecycle_comunicacoes, lifecycle_tarefas, lifecycle_casos, lifecycle_vagas RESTART IDENTITY CASCADE;

  -- ============================================================
  -- VAGAS (vários estados)
  -- ============================================================
  INSERT INTO lifecycle_vagas (reference, titulo, departamento, funcao, local, tipo, motivo, data_desejada, estado, aprovador, aprovado_em, created_by, created_at)
  VALUES ('VG-2026-001','Desenvolvedor Fullstack','Desenvolvimento','Programador Fullstack','Lisboa','colaborador','Substituição / reforço de equipa', '2026-10-01','APROVADA', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '30 days', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '60 days')
  RETURNING id INTO v_dev;

  INSERT INTO lifecycle_vagas (reference, titulo, departamento, funcao, local, tipo, motivo, data_desejada, estado, aprovador, aprovado_em, created_by, created_at)
  VALUES ('VG-2026-002','Técnico Comercial','Comercial','Comercial de terreno','Norte','colaborador','Crescimento de carteira', '2026-11-15','APROVADA', '22222222-2222-2222-2222-222222222222', now()-interval '20 days', '22222222-2222-2222-2222-222222222222', now()-interval '50 days')
  RETURNING id INTO v_com;

  INSERT INTO lifecycle_vagas (reference, titulo, departamento, funcao, local, tipo, motivo, data_desejada, estado, aprovador, aprovado_em, created_by, created_at)
  VALUES ('VG-2026-003','Estagiário Quality & Processos','Qualidade','Estágio curricular','Porto','estagio','Protocolo de estágio AT', '2026-10-05','APROVADA', '5735e898-ac3c-4946-9ab8-2cc3e1c63079', now()-interval '15 days', '5735e898-ac3c-4946-9ab8-2cc3e1c63079', now()-interval '45 days')
  RETURNING id INTO v_est;

  INSERT INTO lifecycle_vagas (reference, titulo, departamento, funcao, local, tipo, motivo, data_desejada, estado, created_by, created_at)
  VALUES ('VG-2026-004','Técnico Administrativo Financeiro','Financeiro','Apoio administrativo','Centro','colaborador','Sazonalidade financeira', '2026-12-01','APROVACAO_PENDENTE', '66666666-6666-6666-6666-666666666666', now()-interval '12 days')
  RETURNING id INTO v_fin;

  INSERT INTO lifecycle_vagas (reference, titulo, departamento, funcao, local, tipo, motivo, data_desejada, estado, aprovador, aprovado_em, created_by, created_at)
  VALUES ('VG-2026-005','Técnico de Sistemas (Infraestruturas)','Sistemas','Suporte e infraestruturas','Lisboa','colaborador','Vaga preenchida internamente', '2026-08-01','ENCERRADA', '33333333-3333-3333-3333-333333333333', now()-interval '12 days', '33333333-3333-3333-3333-333333333333', now()-interval '90 days')
  RETURNING id INTO v_sis;

  -- ============================================================
  -- CASOS cobrindo TODOS os estados do ciclo
  -- ============================================================

  -- 1) Recebida (CANDIDATURA_RECEBIDA)
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, score, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100001', v_dev, 'Maria Silva', 'maria.silva@mail.pt', '+351 911 100 001', 'vaga', 'portal', 'recrutamento', 'CANDIDATURA_RECEBIDA', 'https://cv.demo/maria.pdf', true, now()-interval '1 day', 62, 'Programador', 'Desenvolvimento', '{"habilitacoes":"Licenciatura Eng. Informática","nivel":"junior","localizacao":"Lisboa"}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '1 day')
  RETURNING id INTO c_rec;

  -- 2) Na fila (NA_FILA)
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, score, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100002', v_dev, 'João Santos', 'joao.santos@mail.pt', '+351 911 100 002', 'vaga', 'linkedin', 'recrutamento', 'NA_FILA', 'https://cv.demo/joao.pdf', true, now()-interval '3 days', 71, 'Programador Backend', 'Desenvolvimento', '{"habilitacoes":"Mestrado","nivel":"junior","competencias":["PostgreSQL","Node"]}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '3 days')
  RETURNING id INTO c_fil;

  -- 3) Em triagem (EM_TRIAGEM) com score
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, score, decisao_triagem, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100003', v_dev, 'Ana Costa', 'ana.costa@mail.pt', '+351 911 100 003', 'vaga', 'portal', 'recrutamento', 'EM_TRIAGEM', 'https://cv.demo/ana.pdf', true, now()-interval '6 days', 78, 'APROVAR_PARA_ENTREVISTA', 'Programador Frontend', 'Desenvolvimento', '{"habilitacoes":"Licenciatura","nivel":"pleno"}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '6 days')
  RETURNING id INTO c_tri;

  -- 4) Entrevista (ENTREVISTA)
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, score, decisao_triagem, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100004', v_dev, 'Pedro Lima', 'pedro.lima@mail.pt', '+351 911 100 004', 'vaga', 'recomendacao', 'recrutamento', 'ENTREVISTA', 'https://cv.demo/pedro.pdf', true, now()-interval '9 days', 84, 'EM_AVALIACAO', 'Programador Fullstack', 'Desenvolvimento', '{"habilitacoes":"Mestrado","nivel":"pleno","entrevistadoEm":"2026-09-15"}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '9 days')
  RETURNING id INTO c_ent;

  -- 5) Selecionado (SELECIONADO) — associado à vaga Dev
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, score, decisao_triagem, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100005', v_dev, 'Rita Alves', 'rita.alves@mail.pt', '+351 911 100 005', 'vaga', 'portal', 'recrutamento', 'SELECIONADO', 'https://cv.demo/rita.pdf', true, now()-interval '12 days', 88, 'SELECIONADO', 'Programador Fullstack', 'Desenvolvimento', '{"habilitacoes":"Mestrado","nivel":"pleno"}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '12 days')
  RETURNING id INTO c_sel;

  -- 6) Não selecionado (NAO_SELECIONADO)
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, score, motivo_encerramento, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100006', v_dev, 'Bruno Rocha', 'bruno.rocha@mail.pt', '+351 911 100 006', 'vaga', 'portal', 'recrutamento', 'NAO_SELECIONADO', 'https://cv.demo/bruno.pdf', true, now()-interval '20 days', 48, 'Perfil não alinhado com os requisitos da vaga', 'Programador', 'Desenvolvimento', '{}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '20 days')
  RETURNING id INTO c_nsel;

  -- 7) DUPLICADO: mesma pessoa que Rita (mesmo email) -> aviso_duplicado + duplicado_de
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, consentimento, consentimento_em, dedup_hash, funcao, equipa, created_by, created_at)
  VALUES ('LCY-2026-100007', v_dev, 'Rita Alves', 'rita.alves@mail.pt', '+351 911 100 005', 'vaga', 'portal', 'recrutamento', 'NA_FILA', true, now()-interval '1 day', 'rita.alves@mail.pt|+351 911 100 005', 'Programador Fullstack', 'Desenvolvimento', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '1 day')
  RETURNING id INTO c_dupl;
  UPDATE lifecycle_casos SET duplicado_de = c_sel, aviso_duplicado = true WHERE id = c_dupl;

  -- 8) Pré-admissão (PRE_ADMISSAO) — vaga Comercial, pronta para integrar
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, consentimento, consentimento_em, data_entrada, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100008', v_com, 'Carla Mendes', 'carla.mendes@mail.pt', '+351 911 200 001', 'vaga', 'portal', 'recrutamento', 'PRE_ADMISSAO', true, now()-interval '10 days', '2026-10-12', 'Técnico Comercial', 'Comercial', '{"habilitacoes":"Licenciatura Gestão"}', '22222222-2222-2222-2222-222222222222', now()-interval '18 days')
  RETURNING id INTO c_pre;

  -- 9) Admissão em preparação (ADMISSAO_EM_PREPARACAO) — caso completo com tarefas A01-A20, algumas concluídas
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, data_entrada, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100009', v_dev, 'Hugo Ferreira', 'hugo.ferreira@mail.pt', '+351 911 100 009', 'vaga', 'recomendacao', 'recrutamento', 'ADMISSAO_EM_PREPARACAO', 'https://cv.demo/hugo.pdf', true, now()-interval '15 days', '2026-09-21', 'Programador Fullstack', 'Desenvolvimento', '{"habilitacoes":"Licenciatura","nivel":"pleno"}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '16 days')
  RETURNING id INTO c_emip;

  -- 10) Ready for Day 1 (READY_DAY1) — admissão completa
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, cv_url, consentimento, consentimento_em, data_entrada, funcao, equipa, dados, tipo_vinculo, estado_admissao, ready_day1_flag, ready_day1_em, created_by, created_at)
  VALUES ('LCY-2026-100010', v_dev, 'Inês Martins', 'ines.martins@mail.pt', '+351 911 100 010', 'vaga', 'portal', 'recrutamento', 'READY_DAY1', 'https://cv.demo/ines.pdf', true, now()-interval '25 days', '2026-09-23', 'Programador Fullstack', 'Desenvolvimento', '{"habilitacoes":"Mestrado"}', 'colaborador', 'READY_DAY1', true, now()-interval '2 days', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '28 days')
  RETURNING id INTO c_rdy;

  -- 11) ESTÁGIO (tipo=estagio, SELECIONADO) com tarefas de protocolo
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, consentimento, consentimento_em, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100011', v_est, 'Sofia Nunes', 'sofia.nunes@mail.pt', '+351 911 300 001', 'escolar', 'protocolo', 'estagio', 'SELECIONADO', true, now()-interval '8 days', 'Estagiária Quality', 'Qualidade', '{"habilitações":"Licenciatura","instituicao":"ISEP","duracaoMeses":6}', '5735e898-ac3c-4946-9ab8-2cc3e1c63079', now()-interval '8 days')
  RETURNING id INTO c_est;

  -- 12) Ativo (ATIVO) — passou integração complete
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, consentimento, consentimento_em, data_entrada, funcao, equipa, dados, tipo_vinculo, estado_admissao, ready_day1_flag, ready_day1_em, created_by, created_at)
  VALUES ('LCY-2026-100012', v_sis, 'Marco Teixeira', 'marco.teixeira@mail.pt', '+351 911 400 001', 'vaga', 'portal', 'recrutamento', 'ATIVO', true, now()-interval '80 days', '2026-08-03', 'Técnico Sistemas', 'Sistemas', '{}', 'colaborador', 'READY_DAY1', true, now()-interval '75 days', '33333333-3333-3333-3333-333333333333', now()-interval '90 days')
  RETURNING id INTO c_ati;

  -- 13) Offboarding (OFFBOARDING) — processo de saída em curso
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, consentimento, consentimento_em, data_entrada, funcao, equipa, tipo_vinculo, data_saida, motivo_saida, estado_offboarding, offboarding_em, created_by, created_at)
  VALUES ('LCY-2026-100013', v_sis, 'Vera Pinto', 'vera.pinto@mail.pt', '+351 911 400 013', 'vaga', 'portal', 'recrutamento', 'OFFBOARDING', true, now()-interval '300 days', '2025-11-03', 'Técnica Sistemas', 'Sistemas', 'colaborador', '2026-09-30', 'Mudança de projeto profissional', 'EM_CURSO', now()-interval '10 days', '33333333-3333-3333-3333-333333333333', now()-interval '320 days')
  RETURNING id INTO c_off;

  -- 14) Encerrado (ENCERRADO) — offboarding concluído
  INSERT INTO lifecycle_casos (reference, vaga_id, nome, email, telefone, origem, fonte, tipo, estado, consentimento, consentimento_em, data_entrada, funcao, equipa, tipo_vinculo, data_saida, motivo_saida, estado_offboarding, offboarding_em, offboarding_concluido_em, created_by, created_at)
  VALUES ('LCY-2026-100014', v_com, 'Tiago Neves', 'tiago.neves@mail.pt', '+351 911 200 014', 'vaga', 'portal', 'recrutamento', 'ENCERRADO', true, now()-interval '400 days', '2025-08-01', 'Técnico Comercial', 'Comercial', 'colaborador', '2026-07-31', 'Fim de contrato a termo', 'CONCLUIDO', now()-interval '60 days', now()-interval '55 days', '22222222-2222-2222-2222-222222222222', now()-interval '420 days')
  RETURNING id INTO c_enc;

  -- 15) Pool de talento: candidatura espontânea sem vaga
  INSERT INTO lifecycle_casos (reference, nome, email, telefone, origem, fonte, tipo, estado, consentimento, consentimento_em, funcao, equipa, dados, created_by, created_at)
  VALUES ('LCY-2026-100015', 'Joana Reis', 'joana.reis@mail.pt', '+351 961 500 015', 'espontanea', 'site', 'recrutamento', 'NA_FILA', true, now()-interval '5 days', 'Gestora de Projeto', 'Qualidade', '{"competencias":["ISO9001","Lean","Auditoria"]}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()-interval '5 days')
  RETURNING id INTO c_pool;

  -- ============================================================
  -- TAREFAS DE ADMISSÃO A01-A20 — para casos 100009 (parcial) e 100010 (completa)
  -- ============================================================

  -- 100009 Hugo: admissão em preparação -> P0 em maioria concluída, 2 P0 em aberto, P1/CONDICIONAL pendentes
  INSERT INTO lifecycle_tarefas (caso_id, titulo, sector, gate, due_date, status, sla_atraso, completed_at, created_by)
  SELECT c_emip, titulo, sector, gate, '2026-09-21', 'COMPLETED', false, now()-interval '2 days', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  FROM (VALUES
    ('A01','Confirmar decisão de admissão e condições contratuais','lider','P0'),
    ('A02','Enviar Ficha de Identificação v4 + pedido documental único (admissão e seguro)','rh','P0'),
    ('A03','Recolher Ficha de Identificação preenchida e anexos obrigatórios','rh','P0'),
    ('A04','Validar identidade, dados pessoais e documentação','rh','P0'),
    ('A05','Registar e validar condições finais de contrato e remuneração','rh','P0'),
    ('A06','Acionar admissão na Segurança Social / Census','rh','P0'),
    ('A07','Criar/atualizar ficha de funcionário no PHC (sem redigitação)','enterprise-phc','P0'),
    ('A08','Validar dados complementares no PHC','enterprise-phc','P0') )
  AS x(cod, titulo, sector, gate);

  -- P0 em aberto (2):
  INSERT INTO lifecycle_tarefas (caso_id, titulo, sector, gate, due_date, status, sla_atraso, created_by)
  VALUES (c_emip, 'Preparar contrato e descritivo de funções','rh','P0','2026-09-19','TODO',true,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Criar acessos, utilizador, rede e equipamentos','sistemas','P0','2026-09-18','IN_PROGRESS',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Preparar Welcome Kit','comunicacao','P1','2026-09-20','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Iniciar integração de Comunicação','comunicacao','P1','2026-09-19','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Agendar consulta de Medicina / HST','rh','P0','2026-09-17','COMPLETED',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Enviar pedido de Seguro de Saúde Montepio','rh','P0','2026-09-21','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Acionar Seguro de Estágio (se aplicável)','rh','CONDICIONAL','2026-09-21','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Registar incentivo de recomendação (se aplicável)','financeiro','CONDICIONAL','2026-09-21','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Notificar equipa / Welcome','lider','P1','2026-09-20','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Agendar acolhimento e almoço de indução','rh','P1','2026-09-21','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Preparar documentos e materiais para Day 1','rh','P0','2026-09-21','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
         (c_emip, 'Gate READY FOR DAY 1 (todas as tarefas P0 concluídas ou exceção)','rh','P0','2026-09-21','TODO',false,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

  -- 100010 Inês: READY_DAY1 -> TODAS as A01-A20 concluídas
  INSERT INTO lifecycle_tarefas (caso_id, titulo, sector, gate, due_date, status, sla_atraso, completed_at, created_by)
  SELECT c_rdy, titulo, sector, gate, '2026-09-23', 'COMPLETED', false, now()-interval '3 days', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  FROM (VALUES
    ('A01','Confirmar decisão de admissão e condições contratuais','lider','P0'),
    ('A02','Enviar Ficha de Identificação v4 + pedido documental único (admissão e seguro)','rh','P0'),
    ('A03','Recolher Ficha de Identificação preenchida e anexos obrigatórios','rh','P0'),
    ('A04','Validar identidade, dados pessoais e documentação','rh','P0'),
    ('A05','Registar e validar condições finais de contrato e remuneração','rh','P0'),
    ('A06','Acionar admissão na Segurança Social / Census','rh','P0'),
    ('A07','Criar/atualizar ficha de funcionário no PHC (sem redigitação)','enterprise-phc','P0'),
    ('A08','Validar dados complementares no PHC','enterprise-phc','P0'),
    ('A09','Preparar contrato e descritivo de funções','rh','P0'),
    ('A10','Criar acessos, utilizador, rede e equipamentos','sistemas','P0'),
    ('A11','Preparar Welcome Kit','comunicacao','P1'),
    ('A12','Iniciar integração de Comunicação','comunicacao','P1'),
    ('A13','Agendar consulta de Medicina / HST','rh','P0'),
    ('A14','Enviar pedido de Seguro de Saúde Montepio','rh','P0'),
    ('A15','Acionar Seguro de Estágio (se aplicável)','rh','CONDICIONAL'),
    ('A16','Registar incentivo de recomendação (se aplicável)','financeiro','CONDICIONAL'),
    ('A17','Notificar equipa / Welcome','lider','P1'),
    ('A18','Agendar acolhimento e almoço de indução','rh','P1'),
    ('A19','Preparar documentos e materiais para Day 1','rh','P0'),
    ('A20','Gate READY FOR DAY 1 (todas as tarefas P0 concluídas ou exceção)','rh','P0') )
  AS x(a, titulo, sector, gate);

  -- ============================================================
  -- TAREFAS DE OFFBOARDING — caso 100013 (em curso) e 100014 (concluído)
  -- ============================================================

  -- 100013 Vera: offboarding em curso (P0 maior parte concluída)
  INSERT INTO lifecycle_tarefas (caso_id, titulo, sector, gate, status, sla_atraso, completed_at, created_by)
  VALUES (c_off, 'Registar motivo e data de saída','rh','P0','COMPLETED',false,now()-interval '10 days','33333333-3333-3333-3333-333333333333'),
         (c_off, 'Preparar documentos de cessação/rescisão','rh','P0','COMPLETED',false,now()-interval '6 days','33333333-3333-3333-3333-333333333333'),
         (c_off, 'Cancelar/desativar acessos e utilizador','sistemas','P0','IN_PROGRESS',false,NULL,'33333333-3333-3333-3333-333333333333'),
         (c_off, 'Devolução de equipamento e ativos','logistica','P0','TODO',false,NULL,'33333333-3333-3333-3333-333333333333'),
         (c_off, 'Cancelar benefícios e seguros associados','rh','P0','TODO',false,NULL,'33333333-3333-3333-3333-333333333333'),
         (c_off, 'Realizar entrevista de saída','rh','P1','TODO',false,NULL,'33333333-3333-3333-3333-333333333333'),
         (c_off, 'Cancelar/acertar comunicações e alertas internos','comunicacao','P1','TODO',false,NULL,'33333333-3333-3333-3333-333333333333'),
         (c_off, 'Encerrar caso e arquivo final','rh','P0','TODO',false,NULL,'33333333-3333-3333-3333-333333333333');

  -- 100014 Tiago: offboarding concluído
  INSERT INTO lifecycle_tarefas (caso_id, titulo, sector, gate, status, sla_atraso, completed_at, created_by)
  SELECT c_enc, titulo, sector, gate, 'COMPLETED', false, now()-interval '55 days', '22222222-2222-2222-2222-222222222222'
  FROM (VALUES
    ('Registar motivo e data de saída','rh','P0'),
    ('Preparar documentos de cessação/rescisão','rh','P0'),
    ('Cancelar/desativar acessos e utilizador','sistemas','P0'),
    ('Devolução de equipamento e ativos','logistica','P0'),
    ('Cancelar benefícios e seguros associados','rh','P0'),
    ('Realizar entrevista de saída','rh','P1'),
    ('Cancelar/acertar comunicações e alertas internos','comunicacao','P1'),
    ('Encerrar caso e arquivo final','rh','P0') )
  AS x(titulo, sector, gate);

  -- ============================================================
  -- TAREFAS DE PROTOCOLO DE ESTÁGIO — caso 100011 Sofia
  -- ============================================================
  INSERT INTO lifecycle_tarefas (caso_id, titulo, sector, gate, status, sla_atraso, completed_at, created_by)
  VALUES (c_est, 'Validar elegibilidade e disponibilidade do estágio','rh','P0','COMPLETED',false,now()-interval '5 days','5735e898-ac3c-4946-9ab8-2cc3e1c63079'),
         (c_est, 'Preparar e aprovar o protocolo de estágio','rh','P0','COMPLETED',false,now()-interval '3 days','5735e898-ac3c-4946-9ab8-2cc3e1c63079'),
         (c_est, 'Enviar protocolo à instituição/estagiário','rh','P1','IN_PROGRESS',false,NULL,'5735e898-ac3c-4946-9ab8-2cc3e1c63079'),
         (c_est, 'Recolher assinatura e arquivar protocolo','rh','P1','TODO',false,NULL,'5735e898-ac3c-4946-9ab8-2cc3e1c63079'),
         (c_est, 'Acionar seguro de estágio (condicional)','rh','CONDICIONAL','TODO',false,NULL,'5735e898-ac3c-4946-9ab8-2cc3e1c63079');

  -- ============================================================
  -- COMUNICAÇÕES E01-E12 — evidência por caso
  -- ============================================================

  -- Inês (READY_DAY1): todas as comunicações emitidas
  INSERT INTO lifecycle_comunicacoes (caso_id, ref, tipo, destino, template, estado, enviado_em, created_at)
  SELECT c_rdy, ref, tipo, destino, template, 'ENVIADO', now()-interval '5 days', now()-interval '6 days'
  FROM (VALUES
    ('E01','email','candidato','Ficha de Identificação v4 + pedido documental único (admissão + seguro)'),
    ('E02','tarefa','interna','Admissão — workflow/tarefas (RH, líder, direção)'),
    ('E03','email','externo','Admissão SS/Census'),
    ('E04','integracao','phc','Criação de dados PHC (ficha de funcionário)'),
    ('E05','tarefa','sistemas-logistica','Novo colaborador — OPERACIONAL (acessos, rede, equipamentos)'),
    ('E06','tarefa','comunicacao','Integração — tarefa interna'),
    ('E07','email','equipa','Welcome a novo colega'),
    ('E08','email','montepio','Seguro de Saúde Montepio (após pack documental completo)'),
    ('E09','email','seguradora-estagio','Seguro de Estágio ATIVAR (condicional)'),
    ('E10','email','hst','Dados para agendamento de consulta HST'),
    ('E11','email','financeiro-rh','Incentivo à Atração e Fidelização (condicional)'),
    ('E12','notificacao','rh-lider','Confirmação Ready for Day 1') )
  AS x(ref, tipo, destino, template);

  -- Hugo (ADMISSAO_EM_PREPARACAO): E01-E07 enviadas, restantes pendentes
  INSERT INTO lifecycle_comunicacoes (caso_id, ref, tipo, destino, template, estado, enviado_em)
  SELECT c_emip, ref, tipo, destino, template, 'ENVIADO', now()-interval '4 days'
  FROM (VALUES
    ('E01','email','candidato','Ficha de Identificação v4 + pedido documental único (admissão + seguro)'),
    ('E02','tarefa','interna','Admissão — workflow/tarefas (RH, líder, direção)'),
    ('E03','email','externo','Admissão SS/Census'),
    ('E04','integracao','phc','Criação de dados PHC (ficha de funcionário)'),
    ('E05','tarefa','sistemas-logistica','Novo colaborador — OPERACIONAL (acessos, rede, equipamentos)'),
    ('E06','tarefa','comunicacao','Integração — tarefa interna'),
    ('E07','email','equipa','Welcome a novo colega') )
  AS x(ref, tipo, destino, template);

  INSERT INTO lifecycle_comunicacoes (caso_id, ref, tipo, destino, template, estado)
  SELECT c_emip, ref, tipo, destino, template, 'PENDENTE'
  FROM (VALUES
    ('E08','email','montepio','Seguro de Saúde Montepio (após pack documental completo)'),
    ('E09','email','seguradora-estagio','Seguro de Estágio ATIVAR (condicional)'),
    ('E10','email','hst','Dados para agendamento de consulta HST'),
    ('E11','email','financeiro-rh','Incentivo à Atração e Fidelização (condicional)'),
    ('E12','notificacao','rh-lider','Confirmação Ready for Day 1') )
  AS x(ref, tipo, destino, template);

  -- Estágio Sofia: E01, E09, E10 emitidas
  INSERT INTO lifecycle_comunicacoes (caso_id, ref, tipo, destino, template, estado, enviado_em)
  SELECT c_est, ref, tipo, destino, template, 'ENVIADO', now()-interval '3 days'
  FROM (VALUES
    ('E01','email','candidato','Ficha de Identificação v4 + pedido documental único (admissão + seguro)'),
    ('E09','email','seguradora-estagio','Seguro de Estágio ATIVAR (condicional)'),
    ('E10','email','hst','Dados para agendamento de consulta HST') )
  AS x(ref, tipo, destino, template);

  RAISE NOTICE 'Dataset LifeCycle demo carregado.';
END $$;