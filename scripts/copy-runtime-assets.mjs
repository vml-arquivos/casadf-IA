import { cpSync, existsSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";

const source = resolve("server", "assets");
const destination = resolve("dist", "assets");

if (!existsSync(source)) {
  throw new Error(`Diretório de assets de runtime não encontrado: ${source}`);
}

mkdirSync(destination, { recursive: true });
cpSync(source, destination, { recursive: true });
console.log("Assets de runtime copiados para dist/assets.");
