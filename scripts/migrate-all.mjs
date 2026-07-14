/**
 * CASA DF — Executor de migração completa (banco novo / Supabase)
 * ─────────────────────────────────────────────────────────────────
 * Roda o schema base (db/migrate.sql) seguido de TODAS as migrações
 * numeradas em db/migrations/*.sql, em ordem, em um banco novo/vazio
 * (ex: um projeto Supabase recém-criado).
 *
 * Cada arquivo aplicado é registrado em public.schema_migrations junto com
 * seu checksum SHA-256. Em caso de falha, a transação do arquivo é revertida
 * e a próxima execução retoma somente as migrations pendentes.
 *
 * Uso:
 *   DATABASE_URL="postgresql://..." node scripts/migrate-all.mjs
 *
 * Para pular o schema base (se o banco já tiver as tabelas iniciais):
 *   DATABASE_URL="..." node scripts/migrate-all.mjs --skip-base
 */
import pkg from "pg";
import { readFileSync, readdirSync } from "fs";
import { fileURLToPath, pathToFileURL } from "url";
import { dirname, join } from "path";
import { createHash } from "crypto";

const { Pool } = pkg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const skipBase = process.argv.includes("--skip-base");

export async function rodarArquivo(client, caminho, nome) {
  const sql = readFileSync(caminho, "utf8");
  const checksum = createHash("sha256").update(sql, "utf8").digest("hex");
  const aplicada = await client.query(
    `SELECT checksum
       FROM public.schema_migrations
      WHERE nome = $1`,
    [nome],
  );

  if (aplicada.rows.length) {
    const checksumAnterior = aplicada.rows[0].checksum;
    if (checksumAnterior !== checksum) {
      throw new Error(
        `Migration já aplicada foi alterada: ${nome}. ` +
        `Crie uma nova migration em vez de editar o histórico. ` +
        `Checksum aplicado: ${checksumAnterior}; atual: ${checksum}.`,
      );
    }
    console.log(`⏭️  ${nome} já aplicada`);
    return;
  }

  try {
    const inicio = Date.now();
    await client.query("BEGIN");
    await client.query(sql);
    await client.query(
      `INSERT INTO public.schema_migrations (nome, checksum, duracao_ms)
       VALUES ($1, $2, $3)`,
      [nome, checksum, Date.now() - inicio],
    );
    await client.query("COMMIT");
    console.log(`✅ ${nome}`);
  } catch (err) {
    try { await client.query("ROLLBACK"); } catch {}
    console.error(`❌ Falhou em ${nome}:`);
    console.error(`   ${err.message}`);
    if (err.detail) console.error(`   ${err.detail}`);
    throw err;
  }
}

async function main() {
  const dbUrl = process.env.DATABASE_URL || "";
  if (!dbUrl) {
    console.error("❌ Defina DATABASE_URL antes de rodar este script.");
    process.exit(1);
  }

  const exigeSSL =
    process.env.DATABASE_SSL === "true" ||
    /supabase\.co|amazonaws\.com|render\.com|neon\.tech/i.test(dbUrl);
  const pool = new Pool({
    connectionString: dbUrl,
    ssl: exigeSSL ? { rejectUnauthorized: false } : false,
  });

  console.log("\n🗄️  Casa DF — Migração completa do banco\n");
  let client;
  let lockAdquirido = false;

  try {
    client = await pool.connect();
    await client.query(
      `CREATE TABLE IF NOT EXISTS public.schema_migrations (
         nome TEXT PRIMARY KEY,
         checksum CHAR(64) NOT NULL,
         aplicada_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
         duracao_ms INTEGER NOT NULL DEFAULT 0,
         aplicada_por TEXT NOT NULL DEFAULT CURRENT_USER
       )`,
    );

    // Impede dois containers de uma atualização concorrente de migrarem o
    // mesmo banco ao mesmo tempo. O lock é liberado junto com esta conexão.
    await client.query("SELECT pg_advisory_lock(hashtext('casadf:migrate-all'))");
    lockAdquirido = true;

    if (!skipBase) {
      await rodarArquivo(client, join(__dirname, "..", "db", "migrate.sql"), "db/migrate.sql (schema base)");
    } else {
      console.log("⏭️  Pulando db/migrate.sql (--skip-base)");
    }

    const migDir = join(__dirname, "..", "db", "migrations");
    const candidatos = readdirSync(migDir)
      .filter((f) => f.endsWith(".sql") && !/rollback/i.test(f))
      .sort();

    // Quando existe uma variante *_SAFE.sql, ela substitui o arquivo legado
    // de mesmo nome. Executar os dois repetiria saneamentos destrutivos e pode
    // reintroduzir exatamente o problema que a variante SAFE corrige.
    const substituidosPorSafe = new Set(
      candidatos
        .filter((f) => /_SAFE\.sql$/i.test(f))
        .map((f) => f.replace(/_SAFE\.sql$/i, ".sql")),
    );
    const arquivos = candidatos.filter(
      (f) => /_SAFE\.sql$/i.test(f) || !substituidosPorSafe.has(f),
    );

    for (const ignorado of substituidosPorSafe) {
      console.log(`⏭️  ${ignorado} substituída pela variante SAFE`);
    }

    for (const arquivo of arquivos) {
      await rodarArquivo(client, join(migDir, arquivo), arquivo);
    }

    console.log("\n🎉 Migração completa concluída com sucesso!\n");
  } catch (err) {
    console.error(`\n🛑 Migração interrompida: ${err.message}\n`);
    process.exitCode = 1;
  } finally {
    if (client && lockAdquirido) {
      try {
        await client.query("SELECT pg_advisory_unlock(hashtext('casadf:migrate-all'))");
      } catch {}
    }
    if (client) client.release();
    await pool.end();
  }
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  main();
}
