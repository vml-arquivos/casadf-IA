# Casa DF — relatório de correção do deploy

Data da análise: 14/07/2026

Base analisada: `vml-arquivos/casadf-IA`, branch `main`, commit `3beb72f`

Deploy com erro analisado: commit `7cd86e4`

## Resultado

O bloqueio do deploy foi corrigido no código local. A cadeia completa do banco
aplica o schema base e 78 arquivos efetivos de migração (79 registros no total),
o build de produção termina com sucesso e a suíte existente passa integralmente.

Nenhuma alteração foi enviada ao GitHub ou implantada em produção durante esta
análise.

## Causa raiz observada nos logs

O container novo era criado, porém ficava `unhealthy` porque o entrypoint executa
as migrações antes de iniciar a aplicação. A migration
`003_fix_mover_funil_historico.sql` encerrava com `syntax error at end of input`.
Com a aplicação ainda não iniciada, o endpoint `/api/health` não respondia e o
Coolify restaurava o container anterior.

A troca anterior do trigger de `BEFORE` para `AFTER` não resolvia a falha de
sintaxe. O problema imediato era um bloco PL/pgSQL incompleto. As correções
posteriores em `003` e `005` resolveram apenas os dois primeiros arquivos; a
reprodução completa revelou outros blocos incompletos e incompatibilidades mais
adiante na sequência.

O aviso de healthcheck sobre `curl`/`wget` não era a causa raiz: a imagem instala
`wget`. O healthcheck falhava como consequência da interrupção das migrações.

## Avaliação do trabalho iniciado no Claude

O Claude passou a reproduzir as migrations em um PostgreSQL limpo, encontrou
diversos erros reais e avançou na correção de sintaxe e dependências. O material
fornecido, entretanto, termina durante uma segunda rodada de idempotência,
enquanto eram tratadas as views das migrations `009` e `040`. Esse conjunto
amplo não estava no `main` recuperado; no repositório remoto constavam apenas as
correções pontuais de `003` e `005` posteriores ao deploy que falhou.

Nesta entrega, o trabalho foi reavaliado arquivo a arquivo, ajustado onde a
solução proposta entrava em conflito com o schema real e validado até o fim.
Exemplo: não foi feita a troca indiscriminada de `role` para
`cargo='gestor_credito'` na migration `023`, pois esse valor viola a constraint
de cargos criada pela migration `004`.

## Alterações realizadas

### Executor de migrations

- `scripts/migrate-all.mjs`
  - adiciona a tabela `public.schema_migrations`;
  - registra nome, SHA-256, duração, data e usuário de cada arquivo aplicado;
  - aplica cada arquivo e seu registro na mesma transação;
  - retoma somente migrations pendentes após uma falha;
  - recusa silenciosamente alterações em migrations já registradas e exige um
    novo arquivo de migration;
  - usa advisory lock de sessão para impedir dois containers de migrarem o
    mesmo banco simultaneamente;
  - mantém a seleção das variantes `*_SAFE.sql`;
  - remove o frágil fracionamento de SQL por ponto e vírgula, que quebrava
    funções PL/pgSQL;
  - libera conexão e lock mesmo quando há erro e exibe a mensagem causal.

### Sintaxe PL/pgSQL

Foram completados blocos `CASE`, `IF` ou funções sem `END` nos arquivos:

- `007_sync_chatwoot_n8n_ia_caixa.sql`;
- `009_padroniza_funil_enum.sql`;
- `021_chatwoot_crm_atividades_webhook.sql`;
- `022_acompanhamento_bancario.sql`;
- `024_acompanhamento_financeiro_semanal.sql`;
- `032_socios_empresa_completo.sql`;
- `033_fix_socios_empresa_bulk.sql`;
- `040_fix_crm_funil_enum_to_text.sql`;
- `041_leads_dedup_e_organizacao.sql`;
- `042_score_risco_status_cadastro.sql`;
- `055_documentos_arquivos_entidades_regras.sql`;
- `056_dossie_documental_credito_blocos_ia.sql`;
- `058_documentos_credito_ia_rag_checklist.sql`;
- `062_analise_cnpj_receita_cartao.sql`;
- `063_orcamentos_timbrados.sql`;
- `065_empresas_uf_compat_orcamentos_receita.sql`.

### Compatibilidade de schema e integridade

- `008_dashboards_visibilidade_perfil.sql`: corrige a origem do captador para
  `triagem_leads.captador_id`; `leads.captador_id` não existe.
- `009_padroniza_funil_enum.sql`: remove e recria, na ordem correta, todas as
  views dependentes de `leads.etapa_funil`; padroniza `reativacao`; elimina
  multiplicação cartesiana que inflava somas financeiras nos dashboards e no
  ranking de colaboradores.
- `023_permissao_gestor_credito_acompanhamento.sql`: calcula a permissão pelos
  cargos válidos sem gravar um cargo proibido pela constraint.
- `029_acompanhamento_bancario_logica_alertas_relatorio.sql`: remove `ALTER`
  duplicado, conclui `UPDATE` incompleto, corrige `alerta_aderencia` para
  boolean, inclui campos ausentes e usa as referências bancárias corretas.
- `032_socios_empresa_completo.sql`: remove comandos `\echo`, que só existem
  no cliente `psql` e falhavam quando enviados pelo driver Node.
- `036_crm_clientes_origem_layout.sql`: cria `clientes_pf` antes dos `ALTER`,
  índices e migrations que dependem dela; antes a tabela só era criada mais
  tarde pelo bootstrap da aplicação.
- `040_fix_acompanhamento_bancario_salvar_atualizacao.sql`: acrescenta campos
  de alertas usados pelas funções, mas ausentes na tabela existente.
- `040_fix_crm_funil_enum_to_text.sql`: preserva as definições das views,
  remove apenas dependências da coluna, converte enum para texto, restaura as
  views e recria o trigger bloqueador.
- `041_leads_dedup_e_organizacao.sql`: cria colunas usadas pela própria
  migration, alinha checks de status/prioridade e trata `tags` como `TEXT[]`;
  a deduplicação foi exercitada em teste.
- `043_audit_logs.sql`: alinha `usuario_id` e `entidade_id` aos UUIDs reais.
- `055_documentos_arquivos_entidades_regras.sql`: cria `cliente_pf_id` antes
  de utilizá-lo.
- `070_ia_imobiliaria_completo.sql`: troca a referência à tabela inexistente
  `documentos_leads` pelo repositório documental central
  `documentos_arquivos`.

### Portabilidade e backend

- Migrations `032`, `037`, `063`, `064`, `065` e `067`: substituem papéis de
  banco fixos por `CURRENT_USER`, evitando falhas fora de uma instalação com
  aquele nome específico.
- `server/middleware/auditoria.ts`: mantém IDs de usuário e entidade como UUID,
  sem conversão numérica destrutiva.
- `server/index.ts`: registra o UUID real do lead na auditoria.

### Contratos

Não foi alterado texto, cláusula, template, copy ou regra comercial de contrato.
Arquivos de migrations com “contratos” no nome receberam somente correções de
portabilidade do proprietário de objetos, sintaxe ou criação de chave necessária
ao schema. O gerador de contratos e seus conteúdos não foram editados.

## Validações executadas

| Verificação | Resultado |
|---|---:|
| TypeScript (`pnpm run check`) | aprovado |
| Testes Vitest | 26/26 aprovados |
| Build Vite + servidor (`pnpm run build`) | aprovado |
| Diff/whitespace (`git diff --check`) | aprovado |
| Banco limpo: schema + cadeia completa | 79/79 registros |
| Segunda execução pelo ledger | 79/79 ignorados corretamente |
| Recuperação do estado parcial observado no deploy | aprovada |
| Views críticas restauradas | 9/9 |
| Trigger de histórico e atividade | aprovado |
| Deduplicação de leads | aprovada |
| Auditoria com UUID | aprovada |

O build ainda informa um bundle principal grande (aproximadamente 2,85 MB
minificado). Isso não bloqueia o deploy corrigido, mas deve ser tratado em uma
otimização de frontend separada com divisão por rota e imports dinâmicos.

## Procedimento de deploy

1. Fazer backup ou snapshot verificável do PostgreSQL.
2. Substituir imediatamente o `JWT_SECRET` exposto no log analisado.
3. No Coolify, manter `DATABASE_URL` e `JWT_SECRET` apenas como segredos de
   runtime. Desativar sua disponibilidade durante o build; o Dockerfile não
   precisa desses valores para compilar.
4. Configurar `RUN_MIGRATIONS_ON_START=true` no runtime para este primeiro
   deploy corrigido.
5. Implantar a imagem. O `docker-entrypoint.sh` executará as migrations antes
   da aplicação; não é necessário executar comandos manualmente via SSH.
6. Confirmar no log a mensagem de conclusão da migração e, em seguida, a saúde
   de `/api/health`.
7. Conferir `public.schema_migrations`: o resultado esperado nesta versão é 79
   registros.

Nas implantações seguintes, o entrypoint pode continuar habilitado: arquivos já
registrados e com o mesmo checksum são ignorados. A partir desta entrega,
migrations históricas não devem ser editadas; toda mudança futura deve receber
um novo arquivo numerado.

## Segurança: ação obrigatória

O log fornecido contém um segredo JWT passado pelo ambiente do Coolify como
argumento de build. Mesmo sem aparecer no código-fonte, ele deve ser considerado
comprometido. O valor não foi reproduzido neste relatório nem adicionado ao ZIP.
A rotação do segredo invalidará sessões existentes, o que é esperado e
preferível ao risco de manter uma credencial exposta.

## Observações de entrega

O ZIP originalmente anexado estava truncado e sem diretório central válido. A
base completa foi recuperada do repositório GitHub indicado, usando o `main`
atual (`3beb72f`) como ponto de partida. Esta entrega é local: não houve push,
merge, alteração no Coolify ou acesso ao banco de produção.
