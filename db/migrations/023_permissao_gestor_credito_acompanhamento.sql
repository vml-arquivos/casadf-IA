-- 023_permissao_gestor_credito_acompanhamento.sql
-- Permissão de acesso ao módulo Acompanhamento Bancário para Gestor de Crédito ou superior.

ALTER TABLE colaboradores
ADD COLUMN IF NOT EXISTS acesso_acompanhamento_bancario BOOLEAN NOT NULL DEFAULT false;

UPDATE colaboradores
SET cargo = 'gestor_credito'
WHERE LOWER(COALESCE(cargo, '')) IN ('gerente', 'gerente_credito', 'gestor de credito', 'gestor de crédito');

UPDATE colaboradores
SET acesso_acompanhamento_bancario = true
WHERE LOWER(COALESCE(cargo, '')) IN ('admin', 'super_admin', 'superadmin', 'gestor_credito');

UPDATE colaboradores
SET acesso_acompanhamento_bancario = false
WHERE LOWER(COALESCE(cargo, '')) NOT IN ('admin', 'super_admin', 'superadmin', 'gestor_credito');

CREATE INDEX IF NOT EXISTS idx_colaboradores_acesso_acompanhamento_bancario
ON colaboradores (acesso_acompanhamento_bancario);

CREATE INDEX IF NOT EXISTS idx_colaboradores_cargo
ON colaboradores (cargo);
