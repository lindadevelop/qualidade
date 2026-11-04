# Estado consolidado da Plataforma Estratégica

Versão publicada: **0.5.0-rc.5**. Publicação e testes em 06/10/2026.

Este relatório complementa o estado rc4 e incorpora o delta de 06/10. O PDF de 02/10 novamente enviado foi comparado com o DOCX anteriormente analisado: **119 de 119 parágrafos de referência coincidem**, sem requisito adicional identificado. As regras de 06/10 prevalecem nos pontos alterados.

## Delta de 06 de outubro

| ID | Estado | Onde verificar / evidência | Resultado dos testes |
|---|---|---|---|
| PE-D01 | Não aplicável — pedido de desenvolvimento retirado | O carregamento de logótipo, ícone e favicon já existe em Identidade visual → Editar | Funcionalidade reconhecida como validada no PDF de 06/10; nenhuma recriação do carregamento |
| PE-D02 | Implementado | Fontes separadas, pré-visualização, informação sobre kit predefinido e mensagem em caso de falha. Uma falha de imagem deixa de repor cores e fontes | PASS — Roboto nos títulos e Lato no texto persistem e são efetivamente usados na página após recarregar, em ambiente QA |
| PE-D03 | Implementado | Histórico da identidade, equipas e ciclos com autor, data, campos legíveis e valores anterior/novo. Imagens identificadas por finalidade. Códigos em detalhes técnicos. Campanhas mostram ações e autor em português | PASS — nome do autor e alteração de fonte apresentados no navegador |
| PE-D04 | Implementado | Administração geral → Utilizadores. Várias equipas/funções e perfis por módulo; atualização de equipas ao regressar ao ecrã | PASS — três equipas e dois perfis numa conta; edição, remoção de uma atribuição e manutenção das restantes |
| PE-D05 | Implementado | Organizações → Membros. Nome “Associar membro à organização”, empresa explícita, ativos por defeito, Mostrar inativos e atualização ao mudar de empresa | PASS — nova associação ativa de utilizador inativo bloqueada no servidor; opções anteriores conservadas |
| PE-D06 | Implementado | Organizações → Equipas → Utilização / eliminar. Dependências atuais apresentadas; eliminação também verifica histórico | PASS — equipa utilizada protegida; nome corrigível; equipa sem utilização eliminável |
| PE-D07 | Implementado | Frameworks → Ciclos → Utilização / eliminar e Editar | PASS — ciclo utilizado não eliminável, framework protegido, redução do período bloqueada e extensão permitida |
| PE-D08 | Implementado nas novas campanhas | Área obrigatória na recolha; catálogo por organização; filtros e contagens por área na recolha e SWOT oficial; área conservada na consolidação | PASS — ausência de área rejeitada, áreas diferentes não fundidas e área mantida no item oficial; oito áreas Samsys configuradas |
| PE-D09 | Implementado | Campanhas SWOT → Configurar áreas temáticas e equipas sugeridas | PASS — uma área ligada a várias equipas; ligação funciona como sugestão e não impede contribuição transversal |
| PE-D10 | Implementado nas novas campanhas | Contadores A/B, quotas 3–5 configuráveis, guardar contributos e submeter participação; responsáveis por organização/equipa; validação do contexto antes da consolidação | PASS — 2 próprios bloqueiam, 3+3 permitem submissão, sexto em A ou B bloqueado, várias equipas não reiniciam quota e gestor não substitui o validador da equipa |
| PE-D11 | Não aplicável — pedido de desenvolvimento retirado | Gestão de campanhas existente reutilizada e ampliada para as novas regras | PASS — criação, abertura, recolha, validação e publicação pelo navegador |

## Reconciliação com o delta de 02 de outubro

| ID | Estado atual | Evidência e resultado |
|---|---|---|
| RPG-D01 | Implementado; ausência considerada encerrada por PE-D01 | Carregamento e versões de imagens existentes; ensaios rc4 de persistência e PowerPoint |
| RPG-D02 | Implementado e reforçado por PE-D02 | Persistência e aplicação real de títulos/texto confirmadas no navegador |
| RPG-D03 | Parcial — configuração visual final a confirmar | Kit predefinido Samsys mantém Manrope/Inter. Na consulta atual não possui logótipo, ícone ou favicon associados. Não foram substituídas imagens nem presumido qual ficheiro é oficial |
| RPG-D04 | Implementado | Framework e ciclo separados; mesmo framework reutilizado em dois ciclos nos testes |
| RPG-D05 | Implementado; quotas atualizadas por PE-D10 | Gestão visível de campanhas. Nas novas campanhas as quotas são por participante/contexto, substituindo a regra anterior por quadrante |
| RPG-D06 | Implementado | Demonstrações identificadas e filtradas; eliminação sem uso e bloqueio com histórico testados |
| RPG-D07 | Implementado | Uma conta em várias equipas; contexto próprio e equipa destino verificados no servidor |
| RPG-D08 | Implementado | Perfis acumuláveis por módulo, separados das funções; acesso ao módulo continua obrigatório |
| RPG-D09 | Implementado | Terminar uma atribuição mantém conta/restantes relações; eliminação apenas sem utilização |
| RPG-D10 | Implementado | Originais preservados, sugestões por semelhança e área, revisão humana e ligação ao item oficial |
| RPG-D11 | Implementado; aceitação funcional pela Samsys pendente | Guia de preparação e configuração pela interface. A execução integral pela equipa Samsys fica documentada no guia de testes |
| RPG-D12 | Implementado; avaliação de descoberta pelo utilizador pendente | Administração geral, Administração da Estratégia e identificação da identidade visual partilhada. Navegação verificada no navegador |

## Verificações executadas

- **121 verificações de integração**, incluindo regressões da Qualidade, com reversão dos dados de teste.
- **8 testes unitários do servidor e 8 da interface**, todos aprovados.
- **6 verificações no navegador**: participação incompleta, submissão 3+3, validação/consolidação/publicação e persistência, largura móvel, fontes efetivamente aplicadas e histórico legível.
- **4 verificações de utilizadores no navegador**: criar, editar, terminar uma associação e eliminar conta sem uso.
- **14 verificações de leitura e acessos** no ambiente local e no funil, abrangendo os três módulos; todas aprovadas.
- Compilação rc5 concluída. Permanecem avisos anteriores de tamanho de ficheiros e importações, sem erro de compilação.
- Cópia de segurança efetuada antes da migração 0062. Comparação confirmou os campos originais preservados em 24 perfis, 66 atribuições, 3 campanhas, 6 itens SWOT, 3 kits, 3 frameworks, 3 ciclos e 18 equipas. Não existiam contributos brutos nessa base antes da migração.
- Guia Word com 12 testes não técnicos, 7 páginas renderizadas e verificadas visualmente.

## Regras de transição e limites explícitos

As campanhas anteriores conservam as regras originais, com aviso no ecrã. **Cria uma nova campanha para usar áreas obrigatórias e quotas por participante.** Não se atribuiu uma área fictícia a dados antigos nem se alteraram campanhas históricas automaticamente.

As novas campanhas recolhem contributos diretamente de cada participante autenticado. A importação por colagem permanece no percurso anterior; não permite contornar quotas ou atribuir automaticamente respostas a pessoas nas novas campanhas.

Os responsáveis pela validação da organização e das equipas são configurados em cada campanha. Uma função organizacional escrita como “Líder” não concede automaticamente autorização para validar. Após submissão, originais e decisões ficam preservados; uma revisão do texto final ocorre na consolidação.

O agrupamento usa igualdade normalizada e semelhança de vocabulário, separadas por área. É uma sugestão sujeita a revisão humana; não se apresenta como interpretação semântica por IA.

As oito áreas foram preparadas como dados editáveis da Samsys. As ligações reais entre áreas e equipas devem ser configuradas pela organização; não foi inventado um mapa de responsabilidades.

O PDF de 06/10 confirma o carregamento de imagens como funcional. Isso não confirma, por si só, que os ativos tenham sido associados ao kit predefinido da empresa selecionada. A verificação do kit Samsys encontrou os três campos de imagem sem associação; este é um ponto de configuração a confirmar, não uma ausência da funcionalidade.

Os resultados PASS correspondem aos testes descritos, não substituem a aceitação funcional pela Samsys. O guia Word permite registar essa verificação.
