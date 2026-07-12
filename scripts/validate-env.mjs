const errors = [];
const databaseUrl = String(process.env.DATABASE_URL || "").trim();
const jwtSecret = String(process.env.JWT_SECRET || "").trim();

if (!databaseUrl) {
  errors.push("DATABASE_URL não foi definida");
} else if (!/^postgres(?:ql)?:\/\//i.test(databaseUrl)) {
  errors.push("DATABASE_URL deve começar com postgres:// ou postgresql://");
}

if (!jwtSecret) {
  errors.push("JWT_SECRET não foi definida");
} else if (Buffer.byteLength(jwtSecret, "utf8") < 32) {
  errors.push("JWT_SECRET deve ter no mínimo 32 bytes");
}

if (errors.length) {
  console.error("❌ Configuração inválida:");
  errors.forEach((error) => console.error(`   - ${error}`));
  process.exit(1);
}

console.log("✅ Variáveis obrigatórias válidas.");
console.log(`   Banco: ${new URL(databaseUrl).hostname}`);
console.log(`   Domínio: ${process.env.SITE_DOMAIN || "casadf.com.br"}`);
