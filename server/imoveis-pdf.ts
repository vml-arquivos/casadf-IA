// ─── PDF do módulo imobiliário (Casa DF) ────────────────────────────────────
// Wrapper de timbrado próprio da Casa DF (não usa o logo/marca da Destrava
// Crédito) + geração de PDF via puppeteer-core, seguindo o mesmo padrão de
// Chromium (@sparticuz/chromium) já usado no restante do sistema.

export function gerarHtmlTimbradoImobiliario(body: string, titulo?: string): string {
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8"/>
  <title>Casa DF${titulo ? ' — ' + titulo : ''}</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: Arial, Helvetica, sans-serif;
      color: #1e293b;
      margin: 0;
      padding: 0;
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }
    .page-header {
      width: 100%;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 16px 2cm;
      border-bottom: 3px solid #b45309;
      background: #ffffff;
    }
    .page-header .brand { font-size: 18pt; font-weight: 800; color: #1e293b; letter-spacing: 0.02em; }
    .page-header .brand span { color: #b45309; }
    .page-header .tagline { font-size: 8pt; color: #64748b; }
    .page-content { flex-grow: 1; padding: 1.2cm 2cm; }
    .page-footer {
      width: 100%;
      padding: 10px 2cm 14px 2cm;
      border-top: 1px solid #e2e8f0;
      font-size: 8.5px;
      line-height: 1.4;
      color: #64748b;
      background: #ffffff;
      margin-top: auto;
      text-align: center;
    }
    h1, h2 { color: #1e293b; }
    table { border-collapse: collapse; }
  </style>
</head>
<body>
  <div class="page-header">
    <div>
      <div class="brand">Casa <span>DF</span></div>
      <div class="tagline">Gestão Imobiliária</div>
    </div>
    <div class="tagline" style="text-align:right;">contato@casadf.com.br<br/>(61) 3526-8355</div>
  </div>
  <div class="page-content">
    ${body}
  </div>
  <div class="page-footer">
    Casa DF — Gestão Imobiliária · QND 25 Lote 40, Taguatinga Norte, Brasília - DF · casadf.com.br
  </div>
</body>
</html>`;
}

export async function gerarPdfDeHtmlImobiliario(html: string): Promise<Buffer> {
  const puppeteer = await import('puppeteer-core');
  let executablePath: string;
  if (process.env.CHROMIUM_PATH) {
    executablePath = process.env.CHROMIUM_PATH;
  } else {
    try {
      const chromium = await import('@sparticuz/chromium');
      executablePath = await chromium.default.executablePath();
    } catch {
      executablePath = '/usr/bin/chromium-browser';
    }
  }

  let browser: any;
  try {
    browser = await puppeteer.default.launch({
      executablePath,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process'],
      headless: true,
    });
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const pdf = await page.pdf({
      format: 'A4',
      printBackground: true,
      margin: { top: '0', bottom: '0', left: '0', right: '0' },
    });
    return Buffer.from(pdf);
  } finally {
    if (browser) await browser.close();
  }
}
