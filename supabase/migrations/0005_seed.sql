-- 0005_seed.sql
-- SAMSYS|Qualidade — dados demo (§63):
-- 10 utilizadores, 30 ocorrências (NC+OM), várias origens/áreas, ~70 ações,
-- ações concluídas/em atraso, eficácia pendente, ocorrências encerradas.
-- NOTA: as passwords de auth NÃO são guardadas aqui (primeiro admin via dashboard/RPC).

-- ---------------------------------------------------------------- UTILIZADORES (profiles)
-- Local (sem Supabase auth real): criar também em auth.users para respeitar a FK.
-- Em Supabase Cloud, os utilizadores de auth são criados pelo Supabase Auth; este bloco
-- é idempotente e só serve ambientes locais/shims.
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana.qualidade@samsys.pt',       '{"full_name":"Ana Qualidade"}'),
  ('22222222-2222-2222-2222-222222222222', 'bruno.direcao@samsys.pt',       '{"full_name":"Bruno Direção"}'),
  ('33333333-3333-3333-3333-333333333333', 'carla.sistemas@samsys.pt',      '{"full_name":"Carla Sistemas"}'),
  ('44444444-4444-4444-4444-444444444444', 'diogo.dev@samsys.pt',           '{"full_name":"Diogo Dev"}'),
  ('55555555-5555-5555-5555-555555555555', 'eva.comercial@samsys.pt',       '{"full_name":"Eva Comercial"}'),
  ('66666666-6666-6666-6666-666666666666', 'fabio.financeiro@samsys.pt',   '{"full_name":"Fábio Financeiro"}'),
  ('77777777-7777-7777-7777-777777777777', 'goncalo.phc@samsys.pt',         '{"full_name":"Gonçalo PHC"}'),
  ('88888888-8888-8888-8888-888888888888', 'helena.sage@samsys.pt',         '{"full_name":"Helena Sage"}'),
  ('99999999-9999-9999-9999-999999999999', 'ines.logistica@samsys.pt',      '{"full_name":"Inês Logística"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'joao.admin@samsys.pt',          '{"full_name":"João Admin"}')
on conflict (id) do nothing;

insert into public.profiles (id, full_name, email, role, department, job_title, active) values
  ('11111111-1111-1111-1111-111111111111', 'Ana Qualidade',   'ana.qualidade@samsys.pt',       'quality',      'Qualidade',      'Gestora da Qualidade', true),
  ('22222222-2222-2222-2222-222222222222', 'Bruno Direção',   'bruno.direcao@samsys.pt',       'management',   'Direção',        'Diretor',              true),
  ('33333333-3333-3333-3333-333333333333', 'Carla Sistemas',  'carla.sistemas@samsys.pt',      'action_owner', 'Sistemas',       'Analista de Sistemas', true),
  ('44444444-4444-4444-4444-444444444444', 'Diogo Dev',       'diogo.dev@samsys.pt',           'action_owner', 'Desenvolvimento','Developer',             true),
  ('55555555-5555-5555-5555-555555555555', 'Eva Comercial',   'eva.comercial@samsys.pt',       'action_owner', 'Comercial',      'Comercial',            true),
  ('66666666-6666-6666-6666-666666666666', 'Fábio Financeiro','fabio.financeiro@samsys.pt',   'action_owner', 'Financeiro',     'Controller',           true),
  ('77777777-7777-7777-7777-777777777777', 'Gonçalo PHC',     'goncalo.phc@samsys.pt',         'action_owner', 'PHC',            'Consultor PHC',        true),
  ('88888888-8888-8888-8888-888888888888', 'Helena Sage',     'helena.sage@samsys.pt',         'action_owner', 'Sage',           'Consultora Sage',      true),
  ('99999999-9999-9999-9999-999999999999', 'Inês Logística',  'ines.logistica@samsys.pt',      'action_owner', 'Logística',      'Coordenadora Logística', true),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'João Admin',      'joao.admin@samsys.pt',          'admin',        'Administração',  'Admin',                true)
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email,
  role = excluded.role,
  department = excluded.department,
  job_title = excluded.job_title,
  active = excluded.active;

-- ---------------------------------------------------------------- OCORRÊNCIAS NC/OM
-- origem/área resolvidas por nome (para o seed ser legível)
create or replace function public.seed_occurrence(
  p_type text, p_reference text, p_origin text, p_area text, p_desc text, p_resp text,
  p_date date, p_status text, p_eff text default null, p_cause text default null)
returns void language plpgsql as $$
declare v_origin uuid; v_area uuid; v_resp uuid; v_eff text; v_closed timestamptz; v_validated timestamptz;
begin
  select id into v_origin from public.quality_origins where name = p_origin;
  select id into v_area   from public.quality_areas  where name = p_area;
  select id into v_resp   from public.profiles       where full_name = p_resp;
  v_eff := p_eff;
  v_closed := case when p_status='CLOSED' then p_date + interval '30 days' else null end;
  v_validated := case when v_eff is not null then p_date + interval '25 days' else null end;
  insert into public.quality_occurrences
      (reference, year, type, origin_id, area_id, description, responsible_user_id, occurrence_date,
       status, cause_analysis, effectiveness_status, effectiveness_validated_at, closed_at, created_by, created_at)
    values
      (p_reference, extract(year from p_date)::int, p_type::public.occurrence_type, v_origin, v_area, p_desc, v_resp, p_date,
       p_status::public.occurrence_status, p_cause, v_eff, v_validated, v_closed, '11111111-1111-1111-1111-111111111111', p_date)
    on conflict (reference) do nothing;
end;
$$;

select public.seed_occurrence('NC','NC-2026-0001','Auditoria Interna','Desenvolvimento','Falha de validação da versão do código em produção, causando erro visível ao utilizador.','Diogo Dev','2026-01-10','CLOSED','EFFECTIVE','Ausência de controlo de versões no deployment.');
select public.seed_occurrence('NC','NC-2026-0002','Reclamação','Comercial','Cliente recebeu fatura com valores incorretos. Origem: duplicação de encomenda no sistema.','Eva Comercial','2026-01-18','CLOSED','EFFECTIVE','Erro de parametrização de preços no módulo de faturação.');
select public.seed_occurrence('NC','NC-2026-0003','Auditoria Interna','Financeiro','Documentação de reconciliação bancária em atraso há mais de 30 dias.','Fábio Financeiro','2026-02-02','IN_PROGRESS','Atribuição de responsabilidade não definida.');
select public.seed_occurrence('NC','NC-2026-0004','Auditoria Externa','Sistemas','Não conformidade detetada em auditoria externa relativa a backup de servidores.','Carla Sistemas','2026-02-11','OPEN');
select public.seed_occurrence('NC','NC-2026-0005','Processo Interno','Desenvolvimento','Código entregue sem passar no pipeline de testes automatizados.','Diogo Dev','2026-02-20','IN_PROGRESS','Não existia gate de qualidade no CI.');
select public.seed_occurrence('OM','OM-2026-0001','Melhoria Interna','Desenvolvimento','Proposta para automatizar criação de ambientes de staging.','Diogo Dev','2026-02-25','OPEN');
select public.seed_occurrence('OM','OM-2026-0002','Revisão pela Gestão','Administração','Centralizar a receção e resposta a reclamações de clientes.','Bruno Direção','2026-03-01','AWAITING_EFFECTIVENESS','EFFECTIVE','Responsabilidade dispersa entre áreas.');
select public.seed_occurrence('NC','NC-2026-0006','Reclamação','Comercial','Resposta a reclamação de cliente excedeu o prazo contratual.','Eva Comercial','2026-03-05','IN_PROGRESS','Fluxo de escalamento ausente.');
select public.seed_occurrence('NC','NC-2026-0007','Auditoria Interna','PHC','Parametrização incorreta de módulo de inventário no PHC gerando divergências.','Gonçalo PHC','2026-03-12','OPEN');
select public.seed_occurrence('NC','NC-2026-0008','Processo Interno','Sistemas','Falha intermitente de ligação à base de dados do cliente.','Carla Sistemas','2026-03-18','IN_PROGRESS','Server sem monitorização de recursos.');
select public.seed_occurrence('NC','NC-2026-0009','Auditoria Externa','Financeiro','Incumprimento de prazos legais de submissão de declarações.','Fábio Financeiro','2026-03-25','AWAITING_EFFECTIVENESS','NOT_EFFECTIVE','Calendário fiscal não integrado no sistema.');
select public.seed_occurrence('OM','OM-2026-0003','Melhoria Interna','Desenvolvimento','Adoção de boas práticas de code review em pares.','Diogo Dev','2026-04-01','IN_PROGRESS');
select public.seed_occurrence('NC','NC-2026-0010','Reclamação','Logística','Entrega de encomenda em morada errada causada por erro de exportação logística.','Inês Logística','2026-04-08','IN_PROGRESS','Campo obrigatório de morada não validado.');
select public.seed_occurrence('NC','NC-2026-0011','Auditoria Interna','Desenvolvimento','Ausência de documentação técnica em dois módulos críticos.','Diogo Dev','2026-04-15','OPEN');
select public.seed_occurrence('NC','NC-2026-0012','Auditoria Interna','Sage','Parametrização de contas contabilísticas incorreta no Sage.','Helena Sage','2026-04-22','IN_PROGRESS','Duplicação de planos de contas.');
select public.seed_occurrence('OM','OM-2026-0004','Revisão pela Gestão','Administração','Definir indicadores KPI de qualidade mensais.','Bruno Direção','2026-05-01','AWAITING_EFFECTIVENESS','EFFECTIVE','Não existia histórico de medição.');
select public.seed_occurrence('NC','NC-2026-0013','Auditoria Interna','Financeiro','Atraso na conciliação de pagamentos de fornecedores.','Fábio Financeiro','2026-05-09','OPEN');
select public.seed_occurrence('NC','NC-2026-0014','Processo Interno','Comercial','Proposta comercial enviada ao cliente com cláusulas em branco.','Eva Comercial','2026-05-15','IN_PROGRESS','Template de proposta sem validação de campos.');
select public.seed_occurrence('NC','NC-2026-0015','Auditoria Interna','Sistemas','Incidente de segurança: acessos não revogados após saída de colaborador.','Carla Sistemas','2026-05-22','OPEN');
select public.seed_occurrence('OM','OM-2026-0005','Melhoria Interna','Desenvolvimento','Criar padrão de nomenclatura de branches e commits.','Diogo Dev','2026-05-28','OPEN');
select public.seed_occurrence('NC','NC-2026-0016','Reclamação','PHC','Erro de cálculo de IVA em processamento de faturação.','Gonçalo PHC','2026-06-02','IN_PROGRESS','Taxa de IVA atualizada manualmente e desatualizada.');
select public.seed_occurrence('NC','NC-2026-0017','Auditoria Interna','Logística','Divergência entre stock físico e stock em sistema.','Inês Logística','2026-06-12','IN_PROGRESS','Processos de inventário não documentados.');
select public.seed_occurrence('NC','NC-2026-0018','Auditoria Externa','Financeiro','Falta de aprovação formal de pagamentos acima de valor definido.','Fábio Financeiro','2026-06-18','OPEN');
select public.seed_occurrence('NC','NC-2026-0019','Processo Interno','Desenvolvimento','Erro de lógica em cálculo de comissões, afetando relatório de vendas.','Diogo Dev','2026-07-01','IN_PROGRESS','Regra de negócio não documentada.');
select public.seed_occurrence('NC','NC-2026-0020','Auditoria Interna','Comercial','Falta de seguimento de oportunidades em CRM.','Eva Comercial','2026-07-10','OPEN');
select public.seed_occurrence('OM','OM-2026-0006','Melhoria Interna','Sistemas','Automatizar relatório de incidentes mensal.','Carla Sistemas','2026-07-18','IN_PROGRESS');
select public.seed_occurrence('NC','NC-2026-0021','Auditoria Interna','Desenvolvimento','Erros de segmentação de tipos de venda no ERP PHC.','Gonçalo PHC','2026-07-25','OPEN');
select public.seed_occurrence('NC','NC-2026-0022','Reclamação','Logística','Devolução de produto recebido danificado por embalagem inadequada.','Inês Logística','2026-08-02','IN_PROGRESS','Padrão de embalagem não definido para transporte.');
select public.seed_occurrence('NC','NC-2026-0023','Auditoria Interna','Sistemas','Credenciais de serviço expostas em ficheiro de configuração.','Carla Sistemas','2026-08-12','OPEN');
select public.seed_occurrence('NC','NC-2026-0024','Processo Interno','Financeiro','Faturas de clientes não reconciliadas com pagamentos recebidos.','Fábio Financeiro','2026-08-18','OPEN');

drop function if exists public.seed_occurrence(text,text,text,text,text,date,text,text,text);

-- ---------------------------------------------------------------- AÇÕES (~70)
-- ajudar: atribute a cada ocorrência ações no estado adequado
create or replace function public.seed_actions() returns void language plpgsql as $$
declare
  r record; n int; i int; aresp uuid; astatus text;
begin
  for r in select * from public.quality_occurrences loop
    n := 1 + ((extract(day from r.occurrence_date))::int % 3); -- 1..3 ações
    for i in 1..n loop
      aresp := r.responsible_user_id;
      if aresp is null then aresp := '44444444-4444-4444-4444-444444444444'; end if;
      -- estado coerente com a ocorrência
      astatus := 'COMPLETED';
      if r.status in ('OPEN') then astatus := 'TODO';
      elsif r.status = 'IN_PROGRESS' and i <= 1 then astatus := 'TODO';
      elsif r.status = 'IN_PROGRESS' and i > 1 then astatus := 'COMPLETED';
      elsif r.status = 'AWAITING_EFFECTIVENESS' then astatus := 'COMPLETED';
      end if;
      insert into public.quality_actions
        (occurrence_id, description, responsible_user_id, deadline, status, completed_at, created_by, created_at)
      values
        (r.id, 'Ação ' || i || ' para ocorrência ' || r.reference || ' — investigar e implementar medida corretiva.',
         aresp,
         r.occurrence_date + interval '14 days',
         astatus::public.action_status,
         case when astatus='COMPLETED' then r.occurrence_date + interval '12 days' else null end,
         '11111111-1111-1111-1111-111111111111', r.occurrence_date + interval '2 days');
    end loop;
  end loop;
end;
$$;
select public.seed_actions();
drop function if exists public.seed_actions();

-- ---------------------------------------------------------------- SINC. CONTADORES
-- O seed insere referências explícitas, pelo que o trigger do contador não corre.
-- Sincronizar occurrence_counters com o máximo existente (evita referências duplicadas).
insert into public.occurrence_counters (type, year, last_value)
select type, year, max(substring(reference from '\\d+$')::int)
from public.quality_occurrences
group by type, year
on conflict (type, year) do update
  set last_value = greatest(public.occurrence_counters.last_value, excluded.last_value);