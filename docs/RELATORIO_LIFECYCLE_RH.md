# Relatório — Módulo LifeCycle RH (SAMSYS|Qualidade)

**Referência do programa:** OM — Projeto de Melhoria "LifeCycle RH Samsys" (1 OM, 85 ações: backlog B01–B18, plano de ação imediato, comunicações E01–E12, testes T, riscos R, decisões D, gates, checklists de admissão A01–A20).
**Data:** 2026-09-17
**Estado do módulo:** Núcleo operacional completo e validado E2E. Restringem-se os blocos com dependência de integrações externas (PHC, M365, Montepio).

---

## 1. Âmbito entregue

| Bloco | Descrição | Estado |
|---|---|---|
| B01–B03 | Núcleo P0: modelo de dados (LifeCycle ID, máquina de estados), fila única de candidaturas | ✅ Validado E2E |
| B07 | Registrar percurso em LifeCycle ID com consentimento | ✅ |
| B09 | Deteção de duplicados (email/telefone) | ✅ |
| B10 | Dashboard de recrutamento (KPIs, distribuição, por vaga) | ✅ |
| B11 | Comunicações E01–E12 com evidência + fecho de vaga | ✅ |
| B12 | Protocolo de estágio | ✅ |
| B13 | Gate Ready for Day 1 + admissão A01–A20 | ✅ |
| B14 | Offboarding integrado (checklist de saída, encerramento) | ✅ |
| B15 | Pool de talento com pesquisa | ✅ |
| B16 | Métricas operacionais | ✅ |
| B04–B06, B08 | Documental/arquivo/tarefas M365 | Parcial (documental evidenciado via E01; fora de âmbito interno) |
| B17 | Integração PHC | ⏳ Externo |
| B18 | Seguro Montepio | ⏳ Externo |

---

## 2. Máquina de estados do caso

`NA_FILA → EM_TRIAGEM → ENTREVISTA → SELECIONADO → PRE_ADMISSAO → READY_DAY1 → ATIVO → OFFBOARDING → ENCERRADO` (mais `NAO_SELECIONADO`).

Bloqueios (RF-10): **CLOSED/ENcerrar só com tarefas P0 concluídas**; **Ready for Day 1 só com todas as tarefas P0 de admissão concluídas**.

---

## 3. Funcionalidades por área da app

### Fila única
- Lista de candidaturas com **LifeCycle ID** (LCY-…) e **aging** (idade em dias) por estado.
- Avanço de estado (Triagem/Entrevista/Selecionar/Recusar) com badge de estado.
- **Deduplicação (B09)**: ao receber com email/telefone que coincide com caso ativo, sinaliza *"Possível duplicado de LCY-…"* e liga `duplicado_de`.

### Nova candidatura
- Validate: nome + consentimento obrigatórios (RGPD); LifeCycle ID automático.

### Vagas
- Criação com tipo (Colaborador/Estágio) e departamento.
- **Fecho de vaga (B11)**: encerra a vaga e recusa automaticamente as candidaturas ativas ainda em processo.

### Detalhe do caso
Comunicações E01–E12 (registo com evidência ligada ao LifeCycle ID), configuração de admissão, percurso de estágio, tarefas, offboarding.

### Admissão (B13)
- Definir data de entrada + vínculo → Pré-admissão.
- **Gerar tarefas A01–A20** (catálogo com código, setor, gate P0/P1, prazo relativo à data de entrada), idempotente.
- Marcar tarefa completa; **gate Ready for Day 1** bloqueado enquanto houver tarefas P0 pendentes.

### Offboarding (B14)
- **Iniciar offboarding** (data + motivo) → gera 8 tarefas de saída por setor.
- **Encerrar caso** apenas com P0 de saída concluídas.

### Comunicações (B11)
- Catálogo E01–E12 (Ficha de Identificação, SS/Census, PHC, acessos, Welcome, seguro Montepio, seguro de estágio, HST, Incentivo à Atração, Ready for Day 1).
- Registo "enviado" com evidência (ref, tipo, destino, template, estado ENVIADO) por caso.

### Protocolo de estágio (B12)
- Ativa percurso de estágio: caso passa a `tipo=estagio`, gera tarefas de protocolo (elegibilidade, aprovação, envio, assinatura, acionamento de seguro), idempotente.

### Análise (B10)
- KPIs: **aging médio**, **% tarefas P0 concluídas**, **% processo automatizado**.
- **Distribuição por estado** (barras proporcionais).
- **Candidaturas por vaga** (inclui candidaturas espontâneas).

### Pool de talento (B15)
- Pesquisa por **nome, função ou equipa** com badge de estado.

---

## 4. Modelo de dados (migrations)

| Migration | Objeto |
|---|---|
| `0017_lifecycle.sql` | `lifecycle_vagas`, `lifecycle_casos` (LifeCycle ID + estados), `lifecycle_tarefas`; RLS leitura autenticada/escrita RH-admin |
| `0018_lifecycle_admissao.sql` | Tarefas: `gate`/`depends_on`/`sla_ms`; caso: `tipo_vinculo`, `estado_admissao`, `ready_day1_flag`, `ready_day1_em` |
| `0019_lifecycle_offboarding.sql` | Caso: `data_saida`, `motivo_saida`, `estado_offboarding`, timestamps |
| `0020_lifecycle_avancado.sql` | `lifecycle_comunicacoes` (evidência E01–E12); caso: `dedup_hash`, `duplicado_de`, `aviso_duplicado` |

Serviço `frontend/src/services/lifecycle.ts`: contratos de dados, catálogos (A01–A20, offboarding, estágio, E01–E12), funções CRUD + análise/pool, gerações idempotentes.

---

## 5. Validação (E2E, browser → BD)

| Cenário | Resultado |
|---|---|
| Candidatura → LifeCycle ID → fila | ✅ |
| Admissão → 20 tarefas A01–A20 → completas → **Ready for Day 1** | ✅ (READY_DAY1, 20/20) |
| Offboarding → 8 tarefas de saída → completas → **Encerrar caso** | ✅ (ENCERRADO/CONCLUIDO) |
| 2ª candidatura com mesmo email → aviso de duplicado | ✅ (`duplicado_de` ligado) |
| Comunicação E01 → registo ENVIADO com evidência | ✅ |
| Fecho de vaga → estado ENCERRADA | ✅ |
| Percurso de estágio → `tipo=estagio` + tarefas de protocolo | ✅ |
| Dashboard Análise (3 KPIs, distribuição, por vaga) | ✅ |
| Pool de talento, pesquisa "Dev" filtra por função | ✅ |

Regra de escrita: **CLOSED só com eficácia/estado efetivo + validado**; todas as gerações de tarefas são idempotentes (re-execução não duplica).

---

## 6. Estado atual da base de dados

Tabelas `lifecycle_*` **vazias** (módulo pronto para uso real em produção; dados demo/teste removidos).

---

## 7. Pendentes / dependências externas

| Item | Bloco | Dependência |
|---|---|---|
| Integração PHC (criação ficha funcionário) | B17 | API PHC |
| Seguro de Saúde Montepio | B18 | Parceiro Montepio |
| Tarefas M365 / arquivo documental | B04–B06, B08 | Microsoft 365 |

Estes não bloqueiam a operação da app — são ações de integração com sistemas de terceiros.

---

## 8. Acesso

App no ar em `https://inc-meters-farming-civilization.trycloudflare.com/lifecycle-rh` (túnel efémero trycloudflare; menu **Recursos Humanos → LifeCycle RH**, restrito a RH-admin).

**Commits do módulo:** `b6ead9b`, `1b9876d`, `8ba8713`, `96b9067`, `f21798c`, `7f52af2`.