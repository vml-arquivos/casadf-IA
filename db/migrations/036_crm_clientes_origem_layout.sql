-- 036_crm_clientes_origem_layout.sql
-- Organização visual/operacional de clientes e origem sem regressão.
-- Todos os campos são opcionais e compatíveis com dados antigos.

-- A tabela clientes_pf historicamente só era criada pelo código de startup
-- do servidor (server/index.ts), não pela cadeia de migrações. Isso quebra
-- "migrate-all.mjs" em bancos novos, pois as migrações rodam antes do
-- servidor subir. Criamos aqui (idempotente) para que a migração não
-- dependa da ordem de boot da aplicação.
CREATE TABLE IF NOT EXISTS public.clientes_pf (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome             TEXT NOT NULL,
  cpf              TEXT NOT NULL,
  rg               TEXT,
  data_nascimento  DATE,
  email            TEXT,
  telefone         TEXT,
  endereco         TEXT,
  cidade           TEXT,
  uf               CHAR(2),
  cep              TEXT,
  profissao        TEXT,
  estado_civil     TEXT,
  observacoes      TEXT,
  origem           TEXT DEFAULT 'painel_interno',
  canal_origem     TEXT,
  fonte_cadastro   TEXT DEFAULT 'Cliente PF cadastrado manualmente',
  cadastrado_por   UUID REFERENCES public.colaboradores(id) ON DELETE SET NULL,
  ativo            BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(cpf)
);

ALTER TABLE IF EXISTS clientes_pf
  ADD COLUMN IF NOT EXISTS origem TEXT DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS canal TEXT,
  ADD COLUMN IF NOT EXISTS campanha TEXT,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS landing_page TEXT,
  ADD COLUMN IF NOT EXISTS produto_interesse TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ativo',
  ADD COLUMN IF NOT EXISTS ultima_interacao TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS proxima_acao TEXT,
  ADD COLUMN IF NOT EXISTS responsavel_id UUID,
  ADD COLUMN IF NOT EXISTS empresa_id UUID,
  ADD COLUMN IF NOT EXISTS tipo_cliente TEXT DEFAULT 'pf';

ALTER TABLE IF EXISTS empresas
  ADD COLUMN IF NOT EXISTS canal TEXT,
  ADD COLUMN IF NOT EXISTS campanha TEXT,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS landing_page TEXT,
  ADD COLUMN IF NOT EXISTS produto_interesse TEXT,
  ADD COLUMN IF NOT EXISTS ultima_interacao TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS proxima_acao TEXT,
  ADD COLUMN IF NOT EXISTS etapa_jornada_cliente TEXT;

ALTER TABLE IF EXISTS leads
  ADD COLUMN IF NOT EXISTS ultima_interacao TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS proxima_acao TEXT,
  ADD COLUMN IF NOT EXISTS produto_interesse TEXT;

CREATE INDEX IF NOT EXISTS idx_clientes_pf_origem ON clientes_pf(origem);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_status ON clientes_pf(status);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_responsavel ON clientes_pf(responsavel_id);
CREATE INDEX IF NOT EXISTS idx_clientes_pf_empresa ON clientes_pf(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresas_origem ON empresas(origem);
CREATE INDEX IF NOT EXISTS idx_empresas_proxima_acao ON empresas(proxima_acao);
CREATE INDEX IF NOT EXISTS idx_leads_proxima_acao ON leads(proxima_acao);
