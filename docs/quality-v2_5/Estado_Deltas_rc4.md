# Estado das alterações dos dois documentos de revisão

Versão publicada: **0.5.0-rc.4**, em 04/10/2026.

Os fluxos abaixo estão disponíveis no [ambiente de testes](https://progressive-suburban-entity-twelve.trycloudflare.com/). A aceitação pelos utilizadores fica por realizar com o guia Word. A configuração do logótipo oficial Samsys está pendente do ficheiro original.

## Qualidade

| Requisito | Estado | Onde verificar e evidência | Resultado obtido |
|---|---|---|---|
| Q22-D01 | Implementado | Auditorias → adicionar constatação; a NC/OM mantém a relação com a auditoria | PASS — testes de herança, relações e edição |
| Q22-D02 | Implementado | Constatações usam áreas, referenciais e locais do âmbito da auditoria | PASS — âmbito único, múltiplo e sem opções |
| Q22-D03 | Implementado | Gerir Auditores no formulário e na configuração; internos/externos, entidade, contacto, estado | PASS — auditor externo sem conta e criação pelo navegador |
| Q22-D04 | Implementado | Gerir Áreas/Processos e seleção das áreas abrangidas | PASS — catálogo central, inativos e âmbito |
| Q22-D05 | Implementado | Configuração operacional → nova classificação → Descartar | PASS — linha vazia descartada no navegador |
| Q22-D06 | Implementado | Linhas novas vazias não são enviadas para gravação | PASS — descarte sem preencher o nome |
| Q22-D07 | Implementado | Validações de campos e datas em português; mensagens específicas para áreas obrigatórias | PASS — datas e campos nos fluxos verificados; a revisão linguística integral de ecrãs antigos não fez parte dos testes |
| Q22-D08 | Implementado | Gestão de auditores e áreas dentro da auditoria em preenchimento | PASS — título em rascunho preservado e opções atualizadas |
| Q22-D09 | Implementado | Eliminar em áreas, origens, auditores, referenciais e classificações adicionais | PASS — eliminação sem uso, bloqueio com referências/histórico e proteção dos valores de base |
| Q22-D10 | Implementado | Administração geral → Utilizadores → equipas/funções e perfis por módulo | PASS — três equipas, vários perfis e conta única, persistência no navegador |
| Q22-D11 | Implementado | Eliminar utilizador sem utilização; contas com uso mantêm desativação | PASS — conta nova eliminada no navegador; conta referenciada protegida |

## Plataforma Estratégica

| Requisito | Estado | Onde verificar e evidência | Resultado obtido |
|---|---|---|---|
| RPG-D01 | Implementado | Identidade visual → Editar → imagens; logótipo, ícone e favicon PNG, pré-visualização e versões preservadas | PASS — três imagens persistentes e imagem incorporada num PowerPoint gerado |
| RPG-D02 | Implementado | Fontes separadas para títulos/texto, mensagem de carregamento e alternativa Inter | PASS — mudança para Roboto guardada e recuperada após recarregar |
| RPG-D03 | Parcial | Samsys com as nove cores pedidas, Manrope nos títulos e Inter no texto | PASS — configuração guardada; BLOCKED — falta o ficheiro do logótipo oficial; revisão visual final pela Samsys pendente |
| RPG-D04 | Implementado | Frameworks e Ciclos separados; ajuda explicativa; GES-SAMSYS e ciclo 2026 configurados | PASS — dois ciclos associados ao mesmo framework em teste |
| RPG-D05 | Implementado | Menu Campanhas SWOT; rascunho, recolha, validação, fecho, arquivo, reabertura com motivo | PASS — criação, recolha, fecho bloqueante, reabertura e histórico |
| RPG-D06 | Implementado | Identificação de demonstrações, filtro, eliminação sem uso e arquivo com uso | PASS — regras de eliminação e isolamento de empresa |
| RPG-D07 | Implementado | Utilizadores com várias equipas e função própria em cada associação | PASS — três equipas numa conta; participantes de campanha podem ser definidos por equipa |
| RPG-D08 | Implementado | Perfis por módulo separados das funções organizacionais e do acesso ao módulo | PASS — união de responsabilidades e persistência; a autorização continua a exigir acesso ao módulo |
| RPG-D09 | Implementado | Remover atribuição sem uso ou terminar atribuição utilizada; conta mantém restantes associações | PASS — edição e remoção de uma de três associações, sem desativar a conta |
| RPG-D10 | Implementado | Recolha interna/importação por colagem, grupos sugeridos, revisão dos originais e publicação humana | PASS — duplicados preservados, grupo aprovado e originais ligados ao item oficial |
| RPG-D11 | Implementado | Administração geral → Preparar a organização, com sequência e ligações | PASS — sequência visível e entidades configuráveis; percurso integral por um utilizador Samsys por executar |
| RPG-D12 | Implementado | Administração geral, Administração da Estratégia, Campanhas SWOT e identificação dos catálogos partilhados | PASS — navegação presente no navegador; avaliação de facilidade de descoberta pelo utilizador por realizar |

“PASS” identifica o comportamento verificado nos testes executados, não uma aceitação integral pelos utilizadores.

## Verificações realizadas

- 103 verificações de integração, incluindo regressões da Qualidade, executadas com reversão dos dados de teste.
- 8 testes automáticos do servidor e 8 da interface.
- 5 percursos no navegador para auditorias, classificações, campanhas, fontes/imagens e largura em telemóvel.
- 4 verificações no navegador para criação, edição, atribuições e eliminação de utilizador sem uso.
- Geração de PowerPoint com confirmação da imagem incorporada e respetivas dimensões.
- 14 verificações de acesso e leitura, localmente e pelo endereço público, incluindo Qualidade, Estratégia e administração de utilizadores.
- Compilação concluída. Permanecem avisos de dimensão de alguns ficheiros da interface e de importações já existentes, sem impedir a compilação.
- Cópia de segurança antes das migrações; confirmação de preservação dos registos existentes. Não foram eliminadas campanhas ou dados de outras empresas para preparar a Samsys.

## Limites e decisões explícitas

As imagens suportadas nesta versão são PNG. O favicon deve ser quadrado, até 512 píxeis; o limite geral é 2 MB e 4096 × 4096 píxeis. As versões substituídas permanecem guardadas. Os ficheiros PowerPoint já gerados não são reescritos.

A consolidação sugere grupos por igualdade normalizada e semelhança de vocabulário. Mostra os originais e sinaliza diferenças de quadrante; exige revisão humana. Não é um serviço de interpretação semântica por IA. A importação permite colar colunas de uma folha de cálculo; não foi acrescentada uma ligação automática ao Microsoft Forms.

As contas anteriores a esta versão são conservadas, porque não existia um registo completo de todos os acessos passados. A eliminação de uma conta sem utilização aplica-se de forma verificável às novas contas. Os históricos e as referências continuam a impedir a eliminação.

Manrope foi obtida no [repositório oficial Google Fonts](https://github.com/google/fonts/tree/main/ofl/manrope); a licença acompanha a fonte na aplicação. O logótipo oficial Samsys não foi substituído por uma imagem inventada.

## Guia de aceitação

O ficheiro **Guia_Testes_Atualizacoes_Samsys_rc4.docx** contém 16 testes não técnicos, com localização, passos, resultado esperado e espaço para registar a verificação. A avaliação final do logótipo oficial fica pendente do respetivo ficheiro.
