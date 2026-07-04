-- ============================================================================
-- Migração 069 — Contratos avançados + Imobiliárias + Corretores + Vídeo
--
-- Adiciona os demais tipos de contrato usados no mercado imobiliário
-- (promessa de compra e venda, assessoria com/sem exclusividade, avaliação
-- de imóveis, aluguel) e a estrutura de configuração multi-imobiliária /
-- multi-corretor, preparando o sistema para operar com várias imobiliárias
-- no futuro. Por ora, o papel timbrado dos PDFs continua exclusivamente
-- Casa DF — esta migração cria apenas a base de dados/configuração.
--
-- Idempotente. Rode com: psql "$DATABASE_URL" -f db/migrations/069_contratos_avancados_imobiliarias.sql
-- ============================================================================

-- ── Novos tipos de contrato (ALTER TYPE ADD VALUE não pode rodar dentro de
--    transação em versões antigas do Postgres — statements isolados) ────────
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'promessa_compra_venda';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'assessoria_venda_exclusiva';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'assessoria_venda_sem_exclusiva';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'avaliacao_imovel';
ALTER TYPE contrato_imobiliario_tipo ADD VALUE IF NOT EXISTS 'aluguel';

BEGIN;

-- ── Tabela: imobiliarias (multi-imobiliária, para uso futuro) ──────────────
CREATE TABLE IF NOT EXISTS imobiliarias (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome           VARCHAR(160) NOT NULL,
  cnpj           VARCHAR(20),
  creci_juridico VARCHAR(30),
  logo_url       VARCHAR(400),
  endereco       VARCHAR(220),
  cidade         VARCHAR(120) DEFAULT 'Brasília',
  uf             VARCHAR(2) DEFAULT 'DF',
  telefone       VARCHAR(30),
  whatsapp       VARCHAR(30),
  email          VARCHAR(160),
  site_url       VARCHAR(200),
  instagram_url  VARCHAR(200),
  cor_primaria   VARCHAR(9) DEFAULT '#b45309',
  rodape_texto   TEXT,
  padrao         BOOLEAN NOT NULL DEFAULT FALSE,     -- imobiliária usada como padrão do sistema
  ativa          BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_imobiliarias_unica_padrao ON imobiliarias(padrao) WHERE padrao = TRUE;

-- Seed: garante que a Casa DF exista como imobiliária padrão
INSERT INTO imobiliarias (nome, cnpj, endereco, cidade, uf, telefone, whatsapp, email, site_url, cor_primaria, padrao, ativa)
SELECT 'Casa DF — Gestão Imobiliária', NULL, 'QND 25 Lote 40 - Taguatinga Norte', 'Brasília', 'DF',
       '(61) 3526-8355', '(61) 3526-8355', 'contato@casadf.com.br', 'https://casadf.com.br', '#b45309', TRUE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM imobiliarias WHERE padrao = TRUE);

-- ── Tabela: corretores ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS corretores (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  imobiliaria_id UUID REFERENCES imobiliarias(id) ON DELETE SET NULL,
  usuario_id     UUID,                                 -- vincula a um usuário/colaborador do sistema, se aplicável
  nome           VARCHAR(160) NOT NULL,
  creci          VARCHAR(30),
  telefone       VARCHAR(30),
  whatsapp       VARCHAR(30),
  email          VARCHAR(160),
  foto_url       VARCHAR(400),
  ativo          BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_corretores_imobiliaria ON corretores(imobiliaria_id);

-- ── Vincula imóveis e contratos à imobiliária / corretor ────────────────────
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS imobiliaria_id UUID REFERENCES imobiliarias(id) ON DELETE SET NULL;
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS corretor_id    UUID REFERENCES corretores(id) ON DELETE SET NULL;
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS video_url      VARCHAR(400);
ALTER TABLE imoveis ADD COLUMN IF NOT EXISTS tour_virtual_url VARCHAR(400);

ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS imobiliaria_id UUID REFERENCES imobiliarias(id) ON DELETE SET NULL;
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS corretor_id    UUID REFERENCES corretores(id) ON DELETE SET NULL;

-- Campos específicos para os novos tipos de contrato (aluguel, avaliação, exclusividade)
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS prazo_vigencia_meses SMALLINT;
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS garantia_locaticia   VARCHAR(40); -- caucao, fianca, seguro_fianca, titulo_capitalizacao
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS valor_caucao         NUMERIC(14,2);
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS indice_reajuste      VARCHAR(20); -- IGP-M, IPCA...
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS metodologia_avaliacao TEXT;
ALTER TABLE contratos_imobiliarios ADD COLUMN IF NOT EXISTS valor_avaliacao      NUMERIC(14,2);

-- Preenche a imobiliária padrão nos contratos já existentes sem valor
UPDATE contratos_imobiliarios SET imobiliaria_id = (SELECT id FROM imobiliarias WHERE padrao = TRUE LIMIT 1)
WHERE imobiliaria_id IS NULL;

UPDATE imoveis SET imobiliaria_id = (SELECT id FROM imobiliarias WHERE padrao = TRUE LIMIT 1)
WHERE imobiliaria_id IS NULL;

COMMIT;
