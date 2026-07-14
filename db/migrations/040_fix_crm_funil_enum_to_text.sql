-- 040_fix_crm_funil_enum_to_text.sql
-- Corrige definitivamente o erro 500 em POST /api/crm/mover-funil.
--
-- Problema: migration 009 converteu leads.etapa_funil para o tipo enum
-- etapa_funil_enum. O Node/pg envia strings via $1 e o PostgreSQL rejeita
-- a atribuição direta de TEXT a ENUM sem cast explícito, causando erro 500.
--
-- Solução: converter etapa_funil de volta para TEXT com CHECK constraint
-- equivalente, preservando todos os dados existentes.
--
-- Idempotente: seguro para reexecutar.
-- ============================================================


-- ─── 0. Views e trigger dependentes de leads.etapa_funil precisam ser ───────
-- removidas antes de qualquer ALTER COLUMN TYPE na coluna. O trigger é
-- recriado no passo 6 e as views no passo 11.
DROP TRIGGER IF EXISTS trg_leads_movimentacao_funil ON public.leads;
DROP VIEW IF EXISTS public.vw_leads_para_ia CASCADE;
DROP VIEW IF EXISTS public.vw_performance_colaboradores CASCADE;
DROP VIEW IF EXISTS public.vw_crm_pipeline CASCADE;
DROP VIEW IF EXISTS public.vw_crm_metricas CASCADE;
DROP VIEW IF EXISTS public.vw_pipeline_por_etapa CASCADE;
DROP VIEW IF EXISTS public.vw_funil_conversao CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_gestor CASCADE;
DROP VIEW IF EXISTS public.vw_leads_por_responsavel CASCADE;

-- ─── 1. Verificar se etapa_funil ainda é enum e converter para TEXT ─────────
DO $$
DECLARE
  v_col_type TEXT;
BEGIN
  SELECT data_type INTO v_col_type
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name   = 'leads'
     AND column_name  = 'etapa_funil';

  IF v_col_type = 'USER-DEFINED' THEN
    -- Remover default antes de alterar tipo
    ALTER TABLE public.leads ALTER COLUMN etapa_funil DROP DEFAULT;

    -- Converter enum para TEXT preservando todos os valores
    ALTER TABLE public.leads
      ALTER COLUMN etapa_funil TYPE TEXT
      USING etapa_funil::TEXT;

    -- Restaurar default como TEXT
    ALTER TABLE public.leads
      ALTER COLUMN etapa_funil SET DEFAULT 'entrada';

    RAISE NOTICE 'etapa_funil convertida de ENUM para TEXT com sucesso.';
  ELSE
    RAISE NOTICE 'etapa_funil já é TEXT (tipo: %). Nenhuma alteração necessária.', v_col_type;
  END IF;
END $$;

-- ─── 2. Garantir NOT NULL e DEFAULT ─────────────────────────────────────────
UPDATE public.leads
   SET etapa_funil = 'entrada'
 WHERE etapa_funil IS NULL OR BTRIM(etapa_funil) = '';

ALTER TABLE public.leads
  ALTER COLUMN etapa_funil SET NOT NULL,
  ALTER COLUMN etapa_funil SET DEFAULT 'entrada';

-- ─── 3. Remover qualquer CHECK antigo sobre etapa_funil em leads ─────────────
DO $$
DECLARE
  c RECORD;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.leads'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%etapa_funil%'
  LOOP
    EXECUTE format('ALTER TABLE public.leads DROP CONSTRAINT %I', c.conname);
    RAISE NOTICE 'Constraint removida: %', c.conname;
  END LOOP;
END $$;

-- ─── 4. Adicionar CHECK constraint compatível com todas as etapas ────────────
-- Inclui tanto os valores da taxonomia legada (migration 009) quanto os novos
ALTER TABLE public.leads
  ADD CONSTRAINT leads_etapa_funil_check
  CHECK (etapa_funil IN (
    -- Taxonomia migration 009 (usada para persistência)
    'entrada', 'triagem', 'contato', 'qualificacao', 'documentos',
    'analise', 'proposta', 'negociacao', 'ganho', 'perdido',
    'reativacao', 'carteira',
    -- Taxonomia nova do frontend (caso algum valor novo seja gravado diretamente)
    'novo_lead', 'tentando_contato', 'em_atendimento', 'qualificado',
    'proposta_enviada', 'documentos_pendentes', 'contrato_gerado',
    'aguardando_pagamento', 'fechado', 'em_execucao', 'pos_venda',
    -- Taxonomia schema_crm antigo
    'novo', 'contato_feito', 'documentacao', 'aprovacao', 'inativo'
  ));

-- ─── 5. Garantir que o tipo enum ainda exista (não remover para compatibilidade) ─
-- O enum etapa_funil_enum pode ser usado por outras tabelas/funções;
-- não o removemos para evitar quebrar dependências.

-- ─── 6. Recriar trigger de movimentação de funil (compatível com TEXT) ───────
DROP TRIGGER IF EXISTS trg_leads_movimentacao_funil ON public.leads;

CREATE OR REPLACE FUNCTION public.fn_registrar_movimentacao_funil()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.etapa_funil IS DISTINCT FROM NEW.etapa_funil THEN
    -- Garantir que crm_historico_funil existe com as colunas necessárias
    INSERT INTO public.crm_historico_funil (
      lead_id,
      colaborador_id,
      etapa_de,
      etapa_para,
      etapa_anterior,
      etapa_nova,
      motivo,
      origem_ia,
      created_at
    ) VALUES (
      NEW.id,
      NEW.responsavel_id,
      OLD.etapa_funil::TEXT,
      NEW.etapa_funil::TEXT,
      OLD.etapa_funil::TEXT,
      NEW.etapa_funil::TEXT,
      'Movimentação via sistema',
      FALSE,
      NOW()
    );

    -- Registrar atividade automática
    INSERT INTO public.crm_atividades (
      lead_id,
      colaborador_id,
      tipo,
      titulo,
      descricao,
      origem_ia,
      concluido,
      created_at
    ) VALUES (
      NEW.id,
      NEW.responsavel_id,
      'status_change',
      'Funil: ' || COALESCE(OLD.etapa_funil::TEXT, '—') || ' → ' || NEW.etapa_funil::TEXT,
      'Movimentação automática registrada pelo sistema',
      FALSE,
      TRUE,
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_leads_movimentacao_funil
  AFTER UPDATE OF etapa_funil ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_registrar_movimentacao_funil();

-- ─── 7. Garantir crm_historico_funil com todas as colunas necessárias ────────
CREATE TABLE IF NOT EXISTS public.crm_historico_funil (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id       UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID       REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  etapa_de      TEXT,
  etapa_para    TEXT,
  etapa_anterior TEXT,
  etapa_nova    TEXT,
  motivo        TEXT,
  origem_ia     BOOLEAN     DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_de       TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_para     TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_anterior TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS etapa_nova     TEXT;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS origem_ia      BOOLEAN DEFAULT FALSE;
ALTER TABLE public.crm_historico_funil ADD COLUMN IF NOT EXISTS motivo         TEXT;

-- ─── 8. Garantir crm_atividades com tipo status_change permitido ──────────────
CREATE TABLE IF NOT EXISTS public.crm_atividades (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id        UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  colaborador_id UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  tipo           TEXT        NOT NULL DEFAULT 'nota',
  titulo         TEXT        NOT NULL DEFAULT 'Atividade',
  descricao      TEXT,
  resultado      TEXT,
  origem_ia      BOOLEAN     DEFAULT FALSE,
  concluido      BOOLEAN     DEFAULT TRUE,
  agendado_para  TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS titulo       TEXT;
ALTER TABLE public.crm_atividades ALTER COLUMN titulo SET DEFAULT 'Atividade';
UPDATE public.crm_atividades SET titulo = COALESCE(titulo, descricao, tipo, 'Atividade') WHERE titulo IS NULL;
ALTER TABLE public.crm_atividades ALTER COLUMN titulo SET NOT NULL;

ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS origem_ia    BOOLEAN DEFAULT FALSE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS concluido    BOOLEAN DEFAULT TRUE;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS descricao    TEXT;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS resultado    TEXT;
ALTER TABLE public.crm_atividades ADD COLUMN IF NOT EXISTS agendado_para TIMESTAMPTZ;

-- Remover constraints antigas de tipo/resultado que possam bloquear status_change
DO $$
DECLARE
  c RECORD;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.crm_atividades'::regclass
       AND contype = 'c'
       AND (
         pg_get_constraintdef(oid) ILIKE '%tipo%'
         OR pg_get_constraintdef(oid) ILIKE '%resultado%'
       )
  LOOP
    EXECUTE format('ALTER TABLE public.crm_atividades DROP CONSTRAINT IF EXISTS %I', c.conname);
    RAISE NOTICE 'Constraint removida de crm_atividades: %', c.conname;
  END LOOP;
END $$;

-- Recriar constraints abrangentes
ALTER TABLE public.crm_atividades
  ADD CONSTRAINT crm_atividades_tipo_check
  CHECK (tipo IN (
    'nota','ligacao','whatsapp','email','reuniao','proposta','documento',
    'status_change','ia_acao','followup','outro','chatwoot_message',
    'chatwoot_status','chatwoot_assignment'
  ));

ALTER TABLE public.crm_atividades
  ADD CONSTRAINT crm_atividades_resultado_check
  CHECK (resultado IS NULL OR resultado IN ('positivo','neutro','negativo','sem_resposta'));

-- ─── 9. Índices de performance ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_leads_etapa_funil
  ON public.leads (etapa_funil);

CREATE INDEX IF NOT EXISTS idx_crm_historico_funil_lead_data
  ON public.crm_historico_funil (lead_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crm_atividades_lead_data
  ON public.crm_atividades (lead_id, created_at DESC);

-- ─── 10. Garantir crm_logs existe ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_logs (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id    UUID        REFERENCES public.leads(id) ON DELETE CASCADE,
  usuario_id UUID        REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  acao       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crm_logs_lead_id
  ON public.crm_logs (lead_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crm_logs_usuario_id
  ON public.crm_logs (usuario_id, created_at DESC);

-- ─── 11. Recriar views removidas no passo 0 ─────────────────────────────────
CREATE OR REPLACE VIEW public.vw_crm_pipeline AS
SELECT
  l.id,
  l.nome,
  l.telefone,
  l.email,
  l.empresa,
  l.tipo_pessoa,
  l.cpf_cnpj,
  l.cargo,
  l.cidade,
  l.estado,
  l.canal_origem,
  l.produto_interesse,
  l.valor_solicitado,
  l.prazo_meses,
  l.etapa_funil,
  l.temperatura,
  l.score_ia,
  l.score_manual,
  l.score_efetivo,
  l.tags,
  l.proximo_followup,
  l.ultimo_contato_em,
  l.resumo_ia,
  l.observacoes_ia,
  l.chatwoot_conv_id,
  l.responsavel_id,
  c.nome AS responsavel_nome,
  l.origem,
  l.status,
  l.created_at,
  l.updated_at,
  COALESCE(d.total_docs, 0) AS total_docs,
  COALESCE(d.docs_recebidos, 0) AS docs_recebidos,
  COALESCE(d.docs_pendentes_obrig, 0) AS docs_pendentes_obrig,
  a.titulo AS ultima_atividade,
  a.created_at AS ultima_atividade_em,
  EXTRACT(DAY FROM NOW() - COALESCE(l.ultimo_contato_em, l.created_at))::INTEGER AS dias_sem_contato
FROM public.leads l
LEFT JOIN public.colaboradores c ON c.id = l.responsavel_id
LEFT JOIN LATERAL (
  SELECT
    COUNT(*) AS total_docs,
    COUNT(*) FILTER (WHERE status IN ('recebido','aprovado')) AS docs_recebidos,
    COUNT(*) FILTER (WHERE obrigatorio AND status = 'pendente') AS docs_pendentes_obrig
  FROM public.crm_documentos
  WHERE lead_id = l.id
) d ON TRUE
LEFT JOIN LATERAL (
  SELECT titulo, created_at
  FROM public.crm_atividades
  WHERE lead_id = l.id
  ORDER BY created_at DESC
  LIMIT 1
) a ON TRUE;

CREATE OR REPLACE VIEW public.vw_crm_metricas AS
SELECT
  etapa_funil,
  temperatura,
  COUNT(*) AS total_leads,
  SUM(valor_solicitado) AS valor_total_pipeline,
  AVG(score_efetivo)::INTEGER AS score_medio,
  COUNT(*) FILTER (WHERE proximo_followup <= NOW()) AS followups_atrasados,
  COUNT(*) FILTER (WHERE dias_sem_contato > 7) AS sem_contato_7d
FROM public.vw_crm_pipeline
GROUP BY etapa_funil, temperatura;

CREATE OR REPLACE VIEW public.vw_pipeline_por_etapa AS
SELECT
  etapa_funil,
  COUNT(*) AS total_leads,
  COALESCE(SUM(valor_solicitado), 0) AS valor_total,
  COUNT(*) FILTER (WHERE temperatura = 'urgente') AS urgentes,
  COUNT(*) FILTER (WHERE temperatura = 'quente') AS quentes,
  COUNT(*) FILTER (WHERE proximo_followup < NOW()) AS followups_atrasados,
  AVG(score_efetivo)::INTEGER AS score_medio,
  COUNT(*) FILTER (WHERE responsavel_id IS NULL) AS sem_responsavel
FROM public.leads
GROUP BY etapa_funil
ORDER BY
  CASE etapa_funil
    WHEN 'entrada' THEN 1
    WHEN 'triagem' THEN 2
    WHEN 'contato' THEN 3
    WHEN 'qualificacao' THEN 4
    WHEN 'documentos' THEN 5
    WHEN 'analise' THEN 6
    WHEN 'proposta' THEN 7
    WHEN 'negociacao' THEN 8
    WHEN 'ganho' THEN 9
    WHEN 'perdido' THEN 10
    WHEN 'reativacao' THEN 11
    WHEN 'carteira' THEN 12
    ELSE 99
  END;

CREATE OR REPLACE VIEW public.vw_funil_conversao AS
WITH etapas AS (
  SELECT unnest(ARRAY[
    'entrada','triagem','contato','qualificacao','documentos','analise',
    'proposta','negociacao','ganho','perdido','reativacao','carteira'
  ]::TEXT[]) AS etapa,
  generate_series(1, 12) AS ordem
),
contagens AS (
  SELECT etapa_funil::TEXT AS etapa_funil, COUNT(*) AS total
  FROM public.leads
  WHERE etapa_funil IS NOT NULL
  GROUP BY etapa_funil
)
SELECT
  e.etapa,
  e.ordem,
  COALESCE(c.total, 0) AS total_leads,
  LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) AS total_etapa_anterior,
  CASE
    WHEN LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) > 0
    THEN ROUND(
      COALESCE(c.total, 0)::NUMERIC
      / LAG(COALESCE(c.total, 0)) OVER (ORDER BY e.ordem) * 100, 1
    )
    ELSE NULL
  END AS taxa_retencao_pct
FROM etapas e
LEFT JOIN contagens c ON c.etapa_funil = e.etapa
ORDER BY e.ordem;

-- ─── 7. Recriar views removidas no passo 5 ────────────────────
CREATE OR REPLACE VIEW public.vw_leads_para_ia AS
SELECT
  l.id,
  l.nome,
  l.empresa,
  l.tipo_pessoa,
  l.produto_interesse,
  l.valor_solicitado,
  l.prazo_meses,
  l.origem,
  l.etapa_funil,
  l.temperatura,
  l.score_ia,
  l.score_efetivo,
  l.created_at,
  l.updated_at,
  (l.score_ia = 0 OR l.score_ia IS NULL)                        AS precisa_score,
  EXTRACT(DAY FROM NOW() - l.created_at)::INTEGER               AS dias_desde_criacao
FROM public.leads l
WHERE l.etapa_funil NOT IN ('ganho','perdido','reativacao');

CREATE OR REPLACE VIEW public.vw_performance_colaboradores AS
SELECT
  col.id                                                        AS colaborador_id,
  col.nome,
  col.cargo,
  col.ativo,
  COUNT(DISTINCT l.id)                                          AS total_leads,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'ganho')  AS leads_ganhos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'perdido') AS leads_perdidos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil NOT IN ('ganho','perdido','reativacao')) AS leads_ativos,
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil = 'ganho'
  ), 0)                                                         AS valor_ganho,
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil NOT IN ('perdido','reativacao')
  ), 0)                                                         AS valor_pipeline,
  CASE
    WHEN COUNT(DISTINCT l.id) > 0
    THEN ROUND(
      COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'ganho')::NUMERIC
      / COUNT(DISTINCT l.id) * 100, 1
    )
    ELSE 0
  END                                                           AS taxa_conversao_pct,
  COUNT(DISTINCT f.id) FILTER (
    WHERE f.status = 'pendente' AND f.agendado_para < NOW()
  )                                                             AS followups_atrasados,
  COUNT(DISTINCT a.id) FILTER (
    WHERE a.created_at >= NOW() - INTERVAL '7 days'
  )                                                             AS atividades_7d,
  COUNT(DISTINCT lc.id)                                         AS leads_captados
FROM public.colaboradores col
LEFT JOIN public.leads l  ON l.responsavel_id = col.id
LEFT JOIN public.triagem_leads lc ON lc.captador_id = col.id
LEFT JOIN public.crm_followups f ON f.colaborador_id = col.id
LEFT JOIN public.crm_atividades a ON a.colaborador_id = col.id
GROUP BY col.id, col.nome, col.cargo, col.ativo;

CREATE OR REPLACE VIEW public.vw_dashboard_gestor AS
SELECT
  COUNT(DISTINCT l.id)                                          AS total_leads,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'ganho')  AS leads_ganhos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.etapa_funil = 'perdido') AS leads_perdidos,
  COUNT(DISTINCT l.id) FILTER (WHERE l.created_at >= NOW() - INTERVAL '30 days') AS leads_ultimos_30d,
  COUNT(DISTINCT l.id) FILTER (WHERE l.created_at >= NOW() - INTERVAL '7 days')  AS leads_ultimos_7d,
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil NOT IN ('perdido','reativacao')
  ), 0)                                                         AS valor_pipeline_ativo,
  COALESCE(SUM(l.valor_solicitado) FILTER (
    WHERE l.etapa_funil = 'ganho'
  ), 0)                                                         AS valor_ganho_total,
  COUNT(DISTINCT t.id)                                          AS total_triagem,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'pendente')    AS triagem_pendente,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'convertido')  AS triagem_convertida,
  COUNT(DISTINCT c.id)                                          AS total_conversas,
  COUNT(DISTINCT c.id) FILTER (WHERE c.status NOT IN ('resolvida','arquivada')) AS conversas_ativas,
  COUNT(DISTINCT f.id) FILTER (
    WHERE f.status = 'pendente' AND f.agendado_para < NOW()
  )                                                             AS followups_atrasados,
  COUNT(DISTINCT f.id) FILTER (
    WHERE f.status = 'pendente'
    AND f.agendado_para BETWEEN NOW() AND NOW() + INTERVAL '24 hours'
  )                                                             AS followups_hoje
FROM public.leads l
LEFT JOIN public.triagem_leads t ON TRUE
LEFT JOIN public.crm_conversas c ON c.lead_id = l.id
LEFT JOIN public.crm_followups f ON f.lead_id = l.id;

CREATE OR REPLACE VIEW public.vw_leads_por_responsavel AS
SELECT
  l.responsavel_id,
  col.nome                                                      AS responsavel_nome,
  col.cargo                                                     AS responsavel_cargo,
  l.id                                                          AS lead_id,
  l.nome                                                        AS lead_nome,
  l.telefone,
  l.empresa,
  l.etapa_funil,
  l.temperatura,
  l.score_efetivo,
  l.prioridade,
  l.valor_solicitado,
  l.proximo_followup,
  l.ultimo_contato_em,
  l.caixa_id,
  cx.nome                                                       AS caixa_nome,
  l.created_at,
  l.updated_at,
  EXTRACT(DAY FROM NOW() - COALESCE(l.ultimo_contato_em, l.created_at))::INTEGER AS dias_sem_contato
FROM public.leads l
LEFT JOIN public.colaboradores col ON col.id = l.responsavel_id
LEFT JOIN public.crm_caixas cx     ON cx.id = l.caixa_id
WHERE l.etapa_funil NOT IN ('reativacao');


