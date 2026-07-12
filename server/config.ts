/*
 * Arquivo de configuração central para o backend
 *
 * Este módulo exporta um objeto de configuração contendo valores de
 * variáveis de ambiente com padrão quando não definidos. Centralizar
 * variáveis aqui facilita testes e evita espalhar `process.env` por todo
 * o código. Para adicionar novos parâmetros, atualize este arquivo.
 */

const DATABASE_URL: string = process.env.DATABASE_URL || '';

// URL do microsserviço de previsão de faturamento. Quando em Docker, utilizar
// IP do host (172.17.0.1) como fallback para contêineres internos.
const PREDICAO_SERVICE_URL: string = process.env.PREDICAO_SERVICE_URL || 'http://172.17.0.1:8001';

// URL do serviço de IA externo (Gemini). Se não definido, utiliza
// localhost:9001. A rota analizar-gemini utiliza este endpoint.
const GEMINI_API_URL: string = process.env.GEMINI_API_URL || 'http://localhost:9001';

/**
 * Interrompe a inicialização com uma mensagem clara quando a configuração
 * mínima do backend não foi fornecida. A validação acontece somente em
 * runtime, portanto não interfere no `vite build`/`esbuild`.
 */
export function validateRuntimeEnv(): void {
  const errors: string[] = [];
  const databaseUrl = String(process.env.DATABASE_URL || '').trim();
  const jwtSecret = String(process.env.JWT_SECRET || '').trim();

  if (!databaseUrl) {
    errors.push('DATABASE_URL não foi definida');
  } else if (!/^postgres(?:ql)?:\/\//i.test(databaseUrl)) {
    errors.push('DATABASE_URL deve começar com postgres:// ou postgresql://');
  }

  if (!jwtSecret) {
    errors.push('JWT_SECRET não foi definida');
  } else if (Buffer.byteLength(jwtSecret, 'utf8') < 32) {
    errors.push('JWT_SECRET deve ter no mínimo 32 bytes');
  }

  if (errors.length > 0) {
    throw new Error(`[config] Configuração inválida:\n- ${errors.join('\n- ')}`);
  }
}

export default {
  DATABASE_URL,
  PREDICAO_SERVICE_URL,
  GEMINI_API_URL,
};
