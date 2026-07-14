-- 023_permissao_gestor_credito_acompanhamento.sql
-- Permissão de acesso ao módulo Acompanhamento Bancário para Gestor de Crédito ou superior.

ALTER TABLE colaboradores
ADD COLUMN IF NOT EXISTS acesso_acompanhamento_bancario BOOLEAN NOT NULL DEFAULT false;

UPDATE colaboradores
SET acesso_acompanhamento_bancario = LOWER(TRIM(COALESCE(cargo, ''))) IN (
  'administrador',
  'admin',
  'diretor',
  'gerente comercial',
  'gestor_credito',
  'gestor de credito',
  'gestor de crédito'
);

CREATE INDEX IF NOT EXISTS idx_colaboradores_acesso_acompanhamento_bancario
ON colaboradores (acesso_acompanhamento_bancario);

CREATE INDEX IF NOT EXISTS idx_colaboradores_cargo
ON colaboradores (cargo);
