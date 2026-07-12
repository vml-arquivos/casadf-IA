// ============================================================================
// server/services/ia-imobiliaria.ts
// Serviços de IA Imobiliária — Casa DF Gestão Imobiliária Inteligente
// ============================================================================

import { GoogleGenerativeAI, GenerativeModel } from "@google/generative-ai";

function getGemModel(): GenerativeModel {
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
  return genAI.getGenerativeModel({
    model: "gemini-2.0-flash",
    generationConfig: { responseMimeType: "application/json", temperature: 0.3 } as any,
  });
}

function getGemModelChat(): GenerativeModel {
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
  return genAI.getGenerativeModel({
    model: "gemini-2.0-flash",
    generationConfig: { temperature: 0.7 } as any,
  });
}

// ─── Helper para chamar Gemini com fallback para OpenAI ─────────────────────
async function callGeminiJson(prompt: string, temperature = 0.3): Promise<any> {
  try {
    const model = getGemModel();
    const result = await model.generateContent(prompt);
    const text = result.response.text();
    return JSON.parse(text || "{}");
  } catch (err: any) {
    console.error("[IA] Gemini falhou, tentando OpenAI fallback:", err.message);
    return callOpenAIJson(prompt, temperature);
  }
}

async function callGeminiText(prompt: string, temperature = 0.7): Promise<string> {
  try {
    const model = getGemModelChat();
    const result = await model.generateContent(prompt);
    return result.response.text() || "";
  } catch (err: any) {
    console.error("[IA] Gemini falhou, tentando OpenAI fallback:", err.message);
    return callOpenAIText(prompt, temperature);
  }
}

async function callOpenAIJson(prompt: string, temperature = 0.3): Promise<any> {
  try {
    const { OpenAI } = await import("openai");
    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    const res = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [{ role: "system", content: "Responda sempre em JSON válido." }, { role: "user", content: prompt }],
      temperature,
      response_format: { type: "json_object" } as any,
    });
    return JSON.parse(res.choices[0].message.content || "{}");
  } catch (err: any) {
    console.error("[IA] OpenAI fallback também falhou:", err.message);
    throw new Error("Serviço de IA indisponível — Gemini e OpenAI não responderam.");
  }
}

async function callOpenAIText(prompt: string, temperature = 0.7): Promise<string> {
  try {
    const { OpenAI } = await import("openai");
    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    const res = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
      temperature,
    });
    return res.choices[0].message.content || "";
  } catch (err: any) {
    console.error("[IA] OpenAI fallback também falhou:", err.message);
    throw new Error("Serviço de IA indisponível — Gemini e OpenAI não responderam.");
  }
}

// ─── 1. Lead Score IA ────────────────────────────────────────────────────────
export async function calcularLeadScore(pool: any, leadId: string, dadosExtras: any = {}): Promise<any> {
  const leadResult = await pool.query(
    `SELECT l.*, e.razao_social, e.cnpj, e.score_interno, e.risco_classificacao
     FROM leads l
     LEFT JOIN empresas e ON l.empresa_id = e.id
     WHERE l.id = $1`,
    [leadId]
  );
  if (leadResult.rows.length === 0) throw new Error("Lead não encontrado");
  const lead = leadResult.rows[0];

  // Buscar imóveis de interesse e dados financeiros do lead
  const imoveisInteresse = await pool.query(
    `SELECT i.id, i.valor_venda, i.valor_locacao, i.bairro, i.cidade, i.quartos, i.area_privativa, i.tipo
     FROM imoveis i
     WHERE i.status = 'disponivel'
     ORDER BY i.criado_em DESC LIMIT 10`,
    []
  ).catch(() => ({ rows: [] }));

  const prompt = `Você é um especialista em lead scoring imobiliário.
Analise os dados abaixo e gere um score de 0 a 100 considerando os seguintes fatores:
- Renda estimada (se disponível)
- Bairro/cidade de interesse
- Tipo de imóvel desejado
- Valor desejado vs disponibilidade
- Entrada disponível
- Urgência (etapa do funil, temperatura)
- Engajamento (visualizações, interações, follow-ups)

Dados do lead:
- Nome: ${lead.nome_completo || lead.nome || "N/A"}
- Telefone: ${lead.telefone || "N/A"}
- Email: ${lead.email || "N/A"}
- Etapa funil: ${lead.etapa_funil || "N/A"}
- Temperatura: ${lead.temperatura || "N/A"}
- Valor solicitado: R$ ${lead.valor_solicitado || "N/A"}
- Score interno: ${lead.score_interno || "N/A"}
- Risco: ${lead.risco_classificacao || "N/A"}
- Empresa: ${lead.razao_social || "PF"}

Dados extras fornecidos:
${JSON.stringify(dadosExtras, null, 2)}

Imóveis disponíveis (top 10):
${JSON.stringify(imoveisInteresse.rows.map(r => ({ codigo: r.codigo, tipo: r.tipo, bairro: r.bairro, cidade: r.cidade, valor: r.valor_venda || r.valor_locacao })), null, 2)}

Responda em JSON com:
{
  "score": numero 0-100,
  "classificacao": "frio"|"morno"|"quente"|"urgente"|"vip",
  "fatores": {"renda": peso, "bairro": peso, "tipo_imovel": peso, "valor": peso, "entrada": peso, "urgencia": peso, "engajamento": peso},
  "detalhes": {"renda_anual": valor, "capacidade_compra": valor, "urgencia": "baixa"|"media"|"alta"|"urgente", "perfil": descricao},
  "observacoes": texto explicativo
}`;

  const resposta = await callGeminiJson(prompt);

  // Salvar no banco
  const { rows } = await pool.query(
    `INSERT INTO lead_scores (lead_id, score, classificacao, fatores, detalhes, observacoes_ia)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (lead_id) DO UPDATE SET score = EXCLUDED.score, classificacao = EXCLUDED.classificacao,
       fatores = EXCLUDED.fatores, detalhes = EXCLUDED.detalhes, observacoes_ia = EXCLUDED.observacoes_ia,
       atualizado_em = NOW()
     RETURNING *`,
    [leadId, Number(resposta.score) || 50, resposta.classificacao || "morno",
     JSON.stringify(resposta.fatores || {}), JSON.stringify(resposta.detalhes || {}), resposta.observacoes || ""]
  );

  return rows[0];
}

// ─── 2. Match Inteligente Imóvel x Cliente ──────────────────────────────────
export async function encontrarMatchesImovel(pool: any, leadId: string, limit = 10): Promise<any[]> {
  // Buscar dados do lead
  const leadResult = await pool.query(
    `SELECT l.*, e.razao_social FROM leads l LEFT JOIN empresas e ON l.empresa_id = e.id WHERE l.id = $1`,
    [leadId]
  );
  if (leadResult.rows.length === 0) throw new Error("Lead não encontrado");
  const lead = leadResult.rows[0];

  // Buscar imóveis disponíveis com dados completos
  const imoveisResult = await pool.query(
    `SELECT id, codigo, titulo, tipo, finalidade, status, valor_venda, valor_locacao,
            bairro, cidade, uf, area_privativa, area_total, quartos, suites, banheiros,
            vagas_garagem, destaque, foto_capa_url, latitude, longitude
     FROM imoveis WHERE status = 'disponivel' ORDER BY destaque DESC, criado_em DESC LIMIT 50`,
    []
  );

  // Buscar lead score existente
  const scoreResult = await pool.query(
    `SELECT * FROM lead_scores WHERE lead_id = $1 ORDER BY atualizado_em DESC LIMIT 1`,
    [leadId]
  ).catch(() => ({ rows: [] }));

  const prompt = `Você é um matcher imobiliário inteligente. Com base nos dados do lead e na lista de imóveis disponíveis,
gere um ranking dos 1 a ${limit} imóveis mais compatíveis com o perfil do lead.

Considerar:
- Faixa de preço (valor_venda ou valor_locacao vs capacidade do lead)
- Tipo de imóvel desejado
- Localização (bairro/cidade preferida)
- Metragem e quartos compatíveis
- Valor total compatível com score financeiro

Lead: ${JSON.stringify({
    nome: lead.nome_completo || lead.nome,
    telefone: lead.telefone,
    etapa_funil: lead.etapa_funil,
    temperatura: lead.temperatura,
    valor_solicitado: lead.valor_solicitado,
    score: scoreResult.rows[0] ? scoreResult.rows[0].score : 50,
    classificacao: scoreResult.rows[0] ? scoreResult.rows[0].classificacao : "morno",
    detalhes: scoreResult.rows[0] ? JSON.parse(scoreResult.rows[0].detalhes || "{}") : {},
  }, null, 2)}

Imóveis disponíveis:
${JSON.stringify(imoveisResult.rows, null, 2)}

Responda em JSON com um array de objetos:
[{
  "imovel_id": "UUID do imóvel",
  "score_compatibilidade": numero 0-100,
  "razoes": ["razao 1", "razao 2", ...],
  "fatores_match": {"preco": peso, "localizacao": peso, "tipo": peso, "metragem": peso},
  "posicao_ranking": numero
}]`
    .slice(0, 12000);

  const resposta = await callGeminiJson(prompt);
  const matches = Array.isArray(resposta) ? resposta : (resposta.matches || []);

  // Salvar matches no banco
  for (let i = 0; i < Math.min(matches.length, limit); i++) {
    const m = matches[i];
    if (!m.imovel_id) continue;
    await pool.query(
      `INSERT INTO imovel_matches (lead_id, imovel_id, score_compatibilidade, razoes, fatores_match, posicao_ranking)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT DO NOTHING`,
      [leadId, m.imovel_id, Number(m.score_compatibilidade) || 0,
       JSON.stringify(m.razoes || []), JSON.stringify(m.fatores_match || {}), i + 1]
    ).catch(() => {});
  }

  // Buscar matches salvos com dados do imóvel
  const savedMatches = await pool.query(
    `SELECT m.*, i.codigo, i.titulo, i.tipo, i.valor_venda, i.valor_locacao,
            i.bairro, i.cidade, i.area_privativa, i.quartos, i.foto_capa_url
     FROM imovel_matches m
     JOIN imoveis i ON m.imovel_id = i.id
     WHERE m.lead_id = $1
     ORDER BY m.score_compatibilidade DESC
     LIMIT $2`,
    [leadId, limit]
  );

  return savedMatches.rows;
}

// ─── 3. Simulador Multi-Banco ───────────────────────────────────────────────
export async function simularMultiBanco(pool: any, dados: {
  valor_imovel: number;
  entrada: number;
  prazo_meses: number;
  lead_id?: string;
  imovel_id?: string;
  colaborador_id?: string;
}): Promise<any> {
  const { valor_imovel, entrada, prazo_meses, lead_id, imovel_id, colaborador_id } = dados;
  const valor_financiamento = valor_imovel - (entrada || 0);

  if (valor_financiamento <= 0) throw new Error("Entrada deve ser menor que o valor do imóvel");

  // Taxas aproximadas por banco (SAC / Price)
  const bancos: Record<string, any> = {
    caixa: { nome: "Caixa Econômica Federal", taxa: 0.0073, seg: 0.000036, sf: 0.00005, tipo: "Price", cor: "#005CA9" },
    itau: { nome: "Itaú Unibanco", taxa: 0.0075, seg: 0.000040, sf: 0.00004, tipo: "SAC", cor: "#FF6600" },
    santander: { nome: "Santander", taxa: 0.0078, seg: 0.000038, sf: 0.000045, tipo: "SAC", cor: "#CC0000" },
    bradesco: { nome: "Bradesco", taxa: 0.0076, seg: 0.000042, sf: 0.00005, tipo: "Price", cor: "#C9131B" },
    banco_brasil: { nome: "Banco do Brasil", taxa: 0.0074, seg: 0.000035, sf: 0.00004, tipo: "SAC", cor: "#F4D03F" },
    brb: { nome: "BRB", taxa: 0.0080, seg: 0.000050, sf: 0.000055, tipo: "Price", cor: "#003DA5" },
  };

  const resultados: Record<string, any> = {};

  for (const [key, banco] of Object.entries(bancos)) {
    const parcela = calcularParcela(valor_financiamento, banco.taxa, prazo_meses, banco.tipo);
    const totalJuros = parcela * prazo_meses - valor_financiamento;
    const totalPago = parcela * prazo_meses + (valor_financiamento * banco.seg * prazo_meses);

    resultados[key] = {
      banco: banco.nome,
      chave: key,
      cor: banco.cor,
      sistema: banco.tipo,
      taxa_juros_mensal: banco.taxa * 100,
      taxa_seguro: banco.seg * 100,
      taxa_sf: banco.sf * 100,
      valor_financiamento,
      parcela_mensal: Math.round(parcela * 100) / 100,
      total_juros: Math.round(totalJuros * 100) / 100,
      total_seguro: Math.round(valor_financiamento * banco.seg * prazo_meses * 100) / 100,
      total_pago: Math.round(totalPago * 100) / 100,
      parcela_minima: Math.round(parcela * 100) / 100,
      parcela_maxima: Math.round(parcela * 1.1 * 100) / 100,
    };
  }

  // IA para recomendação
  const promptRec = `Com base nos resultados de simulação imobiliária abaixo, gere uma recomendação.
Valor do imóvel: R$ ${valor_imovel.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
Entrada: R$ ${(entrada || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
Prazo: ${prazo_meses} meses

Resultados:
${JSON.stringify(resultados, null, 2)}

Responda em JSON com:
{"recomendacao": texto, "melhor_custo": "chave_banco", "melhor_parcela": "chave_banco", "observacoes": texto}`;

  let recomendacaoIA: any = {};
  try {
    recomendacaoIA = await callGeminiJson(promptRec, 0.3);
  } catch (e) {
    recomendacaoIA = {
      recomendacao: "Recomendamos comparar os bancos Caixa e Banco do Brasil que apresentam as menores taxas.",
      melhor_custo: "caixa",
      melhor_parcela: "caixa",
      observacoes: "Considere também a entrada: quanto maior a entrada, menor o comprometimento.",
    };
  }

  // Salvar simulação
  const insertQuery = `
    INSERT INTO simulacoes_multi_banco (lead_id, imovel_id, colaborador_id, valor_imovel, valor_entrada,
      prazo_meses, resultado_caixa, resultado_itau, resultado_santander, resultado_bradesco,
      resultado_banco_brasil, resultado_brb, recomendacao, comparacao_resumo)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
    RETURNING *`;

  const { rows } = await pool.query(insertQuery, [
    lead_id || null, imovel_id || null, colaborador_id || null,
    valor_imovel, entrada || 0, prazo_meses,
    JSON.stringify(resultados.caixa), JSON.stringify(resultados.itau),
    JSON.stringify(resultados.santander), JSON.stringify(resultados.bradesco),
    JSON.stringify(resultados.banco_brasil), JSON.stringify(resultados.brb),
    recomendacaoIA.recomendacao || "", JSON.stringify(resultados)
  ]);

  return {
    simulacao: rows[0],
    resultados,
    recomendacao: recomendacaoIA,
  };
}

function calcularParcela(valor: number, taxa: number, prazo: number, sistema: string): number {
  if (sistema === "Price") {
    // Parcela fixa (Price)
    return valor * (taxa * Math.pow(1 + taxa, prazo)) / (Math.pow(1 + taxa, prazo) - 1);
  } else {
    // SAC: primeira parcela (maior)
    return (valor / prazo) + (valor * taxa);
  }
}

// ─── 4. Assistente Gemini Conversacional ────────────────────────────────────
export async function assistenteConversar(pool: any, sessionId: string, mensagem: string, contexto: any = {}): Promise<any> {
  const sessionResult = await pool.query(
    `SELECT * FROM assistente_sessions WHERE id = $1`,
    [sessionId]
  );

  let session: any;
  if (sessionResult.rows.length === 0) {
    // Criar nova sessão
    const createRes = await pool.query(
      `INSERT INTO assistente_sessions (is_publica, contexto_ia)
       VALUES ($1, $2) RETURNING *`,
      [contexto.is_publica || false, JSON.stringify(contexto)]
    );
    session = createRes.rows[0];
  } else {
    session = sessionResult.rows[0];
  }

  // Buscar últimas mensagens da sessão
  const messagesResult = await pool.query(
    `SELECT role, content FROM assistente_messages
     WHERE session_id = $1 ORDER BY criado_em DESC LIMIT 10`,
    [session.id]
  );
  const historico = messagesResult.rows.reverse();

  // Montar contexto imobiliário
  const imoveisRelevantes = await pool.query(
    `SELECT id, codigo, titulo, tipo, valor_venda, valor_locacao, bairro, cidade, area_privativa, quartos
     FROM imoveis WHERE status = 'disponivel' ORDER BY destaque DESC, criado_em DESC LIMIT 20`
  ).catch(() => ({ rows: [] }));

  const systemPrompt = `Você é o Assistente Imobiliário da Casa DF — uma plataforma de gestão imobiliária inteligente.
Seu papel é ajudar compradores, vendedores e corretores com:
- Informações sobre imóveis disponíveis
- Simulação de financiamento imobiliário (Caixa, Itaú, Santander, Bradesco, BB, BRB)
- Análise de capacidade de compra
- Orientações sobre compra, venda e locação
- Suporte sobre documentos e contratos imobiliários

Responda de forma profissional, clara e útil. Para valores monetários use o formato R$ X.XXX,XX (pt-BR).

Imóveis disponíveis (top 20):
${JSON.stringify(imoveisRelevantes.rows.map(r => ({
    codigo: r.codigo, titulo: r.titulo, tipo: r.tipo,
    valor: r.valor_venda || r.valor_locacao, bairro: r.bairro, cidade: r.cidade
  })), null, 2)}

Histórico recente da conversa:
${historico.map(m => `${m.role}: ${m.content}`).join("\n")}

Agora, responda à mensagem do usuário.`;

  const gemAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
  const model = gemAI.getGenerativeModel({
    model: "gemini-2.0-flash",
    generationConfig: { temperature: 0.7 } as any,
  });

  const chat = model.startChat({
    history: historico.map(m => ({ role: m.role === "user" ? "user" : "model", parts: [{ text: m.content }] })),
  });

  const result = await chat.sendMessage(mensagem);
  const resposta = result.response.text();

  // Salvar mensagens
  await pool.query(
    `INSERT INTO assistente_messages (session_id, role, content) VALUES ($1, 'user', $2)`,
    [session.id, mensagem]
  );
  await pool.query(
    `INSERT INTO assistente_messages (session_id, role, content) VALUES ($1, 'assistant', $2)`,
    [session.id, resposta]
  );

  return {
    session_id: session.id,
    resposta,
    historico_len: historico.length + 2,
  };
}

// ─── 5. IA Jurídica ─────────────────────────────────────────────────────────
export async function analisarDocumentoJuridico(pool: any, dados: {
  documento_id?: string;
  imovel_id?: string;
  lead_id?: string;
  tipo_documento?: string;
  conteudo?: string;
  colaborador_id?: string;
}): Promise<any> {
  const { documento_id, imovel_id, lead_id, tipo_documento, conteudo, colaborador_id } = dados;

  // Buscar dados do imóvel se disponível
  let imovelData: any = null;
  if (imovel_id) {
    const r = await pool.query("SELECT * FROM imoveis WHERE id = $1", [imovel_id]);
    imovelData = r.rows[0];
  }

  // Buscar dados do lead se disponível
  let leadData: any = null;
  if (lead_id) {
    const r = await pool.query(
      `SELECT l.*, e.razao_social FROM leads l LEFT JOIN empresas e ON l.empresa_id = e.id WHERE l.id = $1`,
      [lead_id]
    );
    leadData = r.rows[0];
  }

  const prompt = `Você é um advogado imobiliário sênior. Analise o documento/tipo abaixo e identifique:
1. Riscos jurídicos (matrícula, escritura, contratos, certidões, ônus, gravames)
2. Pendências que precisam ser resolvidas
3. Recomendações de ação
4. Se é necessária revisão humana por advogado

Tipo do documento: ${tipo_documento || "Não especificado"}
Conteúdo fornecido: ${conteudo || "Documento não fornecido textualmente"}

${imovelData ? `
Dados do imóvel:
- Título: ${imovelData.titulo}
- Endereço: ${imovelData.endereco}, ${imovelData.bairro}, ${imovelData.cidade}/${imovelData.uf}
- Matrícula: ${imovelData.matricula_imovel || "N/A"}
- Valor: R$ ${imovelData.valor_venda || imovelData.valor_locacao || "N/A"}
` : ""}

Responda em JSON com:
{
  "riscos_identificados": [{"tipo": "descricao do tipo", "descricao": "descricao detalhada", "nivel": "baixo"|"medio"|"alto"|"critico"}],
  "pendencias": [{"descricao": "o que falta", "acao_requerida": "o que fazer"}],
  "recomendacoes": [{"descricao": "recomendação", "prioridade": "alta"|"media"|"baixa"}],
  "necessidade_revisao": true|false,
  "analise_ia": "texto completo da análise",
  "resumo_executivo": "resumo de 2-3 frases"
}`;

  const resposta = await callGeminiJson(prompt);

  // Salvar análise
  const { rows } = await pool.query(
    `INSERT INTO analises_juridicas (documento_id, imovel_id, lead_id, tipo_documento,
       riscos_identificados, pendencias, recomendacoes, necessidade_revisao, analise_ia, resumo_executivo, colaborador_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING *`,
    [documento_id || null, imovel_id || null, lead_id || null, tipo_documento || null,
     JSON.stringify(resposta.riscos_identificados || []), JSON.stringify(resposta.pendencias || []),
     JSON.stringify(resposta.recomendacoes || []), resposta.necessidade_revisao ?? true,
     resposta.analise_ia || "", resposta.resumo_executivo || "", colaborador_id || null]
  );

  return rows[0];
}

// ─── 6. IA Financeira ───────────────────────────────────────────────────────
export async function analisarFinanceiro(pool: any, dados: {
  lead_id: string;
  imovel_id?: string;
  renda_mensal?: number;
  compromissos_mensais?: number;
  colaborador_id?: string;
}): Promise<any> {
  const { lead_id, imovel_id, renda_mensal, compromissos_mensais, colaborador_id } = dados;

  // Buscar dados do lead
  const leadResult = await pool.query(
    `SELECT l.*, e.razao_social FROM leads l LEFT JOIN empresas e ON l.empresa_id = e.id WHERE l.id = $1`,
    [lead_id]
  );
  if (leadResult.rows.length === 0) throw new Error("Lead não encontrado");
  const lead = leadResult.rows[0];

  // Buscar imóveis disponíveis
  const imoveisResult = await pool.query(
    `SELECT id, valor_venda, valor_locacao, bairro, cidade FROM imoveis WHERE status = 'disponivel' LIMIT 20`
  ).catch(() => ({ rows: [] }));

  const renda = renda_mensal || Number(lead.valor_solicitado) || 5000;
  const compromissos = compromissos_mensais || 0;
  const rendaLiquida = renda - compromissos;

  const prompt = `Você é um analista financeiro imobiliário. Com base nos dados abaixo, gere uma análise completa:
- Capacidade máxima de compra/financiamento
- Percentual de comprometimento de renda
- Entrada necessária recomendada
- Prazo ideal de financiamento
- Risco de aprovação

Dados:
- Lead: ${lead.nome_completo || lead.nome}
- Renda mensal estimada: R$ ${renda.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
- Compromissos mensais: R$ ${compromissos.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
- Renda líquida: R$ ${rendaLiquida.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}
- Etapa funil: ${lead.etapa_funil || "N/A"}

Imóveis disponíveis (amostra):
${JSON.stringify(imoveisResult.rows.slice(0, 10).map(r => ({
    valor: r.valor_venda || r.valor_locacao, bairro: r.bairro, cidade: r.cidade
  })), null, 2)}

Responda em JSON com:
{
  "capacidade_compra": numero,
  "comprometimento_renda": numero (0-100),
  "entrada_necessaria": numero,
  "prazo_ideal_meses": numero,
  "risco_aprovacao": "baixo"|"medio"|"alto"|"muito_alto",
  "perfil_financeiro": {"estabilidade": "alta"|"media"|"baixa", "historico": "limpo"|"pendencias", "observacao": "texto"},
  "recomendacao_ia": "texto completo com recomendações"
}`;

  const resposta = await callGeminiJson(prompt);

  const { rows } = await pool.query(
    `INSERT INTO analises_financeiras (lead_id, imovel_id, renda_mensal, renda_anual, compromissos_mensais,
       capacidade_compra, comprometimento_renda, entrada_necessaria, prazo_ideal_meses, risco_aprovacao,
       perfil_financeiro, recomendacao_ia, colaborador_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
     RETURNING *`,
    [lead_id, imovel_id || null, renda, renda * 12, compromissos,
     Number(resposta.capacidade_compra) || 0, Number(resposta.comprometimento_renda) || 30,
     Number(resposta.entrada_necessaria) || 0, Number(resposta.prazo_ideal_meses) || 360,
     resposta.risco_aprovacao || "medio",
     JSON.stringify(resposta.perfil_financeiro || {}), resposta.recomendacao_ia || "",
     colaborador_id || null]
  );

  return rows[0];
}

// ─── 7. IA de Avaliação Imobiliária ─────────────────────────────────────────
export async function avaliarImovel(pool: any, dados: {
  imovel_id: string;
  colaborador_id?: string;
}): Promise<any> {
  const { imovel_id, colaborador_id } = dados;

  const imovelResult = await pool.query(
    `SELECT * FROM imoveis WHERE id = $1`,
    [imovel_id]
  );
  if (imovelResult.rows.length === 0) throw new Error("Imóvel não encontrado");
  const imovel = imovelResult.rows[0];

  // Buscar imóveis comparáveis na mesma região
  const comparaveisResult = await pool.query(
    `SELECT id, titulo, valor_venda, valor_locacao, area_privativa, quartos,
            bairro, cidade, criado_em
     FROM imoveis WHERE status = 'disponivel'
     AND bairro ILIKE $1
     AND tipo = $2
     AND id != $3
     ORDER BY criado_em DESC LIMIT 10`,
    [`%${imovel.bairro || ''}%`, imovel.tipo, imovel_id]
  ).catch(() => ({ rows: [] }));

  // Se não encontrou comparáveis no mesmo bairro, busca na cidade
  let comparaveis = comparaveisResult.rows;
  if (comparaveis.length < 3 && imovel.cidade) {
    const cidadeResult = await pool.query(
      `SELECT id, titulo, valor_venda, valor_locacao, area_privativa, quartos,
              bairro, cidade, criado_em
       FROM imoveis WHERE status = 'disponivel'
       AND cidade ILIKE $1
       AND tipo = $2
       AND id != $3
       ORDER BY criado_em DESC LIMIT 10`,
      [`%${imovel.cidade}%`, imovel.tipo, imovel_id]
    ).catch(() => ({ rows: [] }));
    comparaveis = cidadeResult.rows;
  }

  const prompt = `Você é um avaliador imobiliário profissional. Com base nos dados do imóvel e nos comparáveis da região,
calcule o valor estimado do imóvel usando método comparativo.

Imóvel avaliado:
- Título: ${imovel.titulo}
- Tipo: ${imovel.tipo}
- Bairro: ${imovel.bairro}, Cidade: ${imovel.cidade}/${imovel.uf}
- Área privativa: ${imovel.area_privativa} m²
- Quartos: ${imovel.quartos}, Suites: ${imovel.suites}
- Banheiros: ${imovel.banheiros}, Vagas: ${imovel.vagas_garagem}
- Ano construção: ${imovel.ano_construcao || "N/A"}
- Valor venda: R$ ${imovel.valor_venda || "N/A"}
- Valor locação: R$ ${imovel.valor_locacao || "N/A"}
- Mobiliado: ${imovel.mobiliado}
- Comodidades: ${JSON.stringify(imovel.comodidades || [])}

Imóveis comparáveis na região:
${JSON.stringify(comparaveis.map(r => ({
    valor: r.valor_venda || r.valor_locacao, area: r.area_privativa, quartos: r.quartos,
    bairro: r.bairro, cidade: r.cidade
  })), null, 2)}

Responda em JSON com:
{
  "valor_estimado": numero,
  "valor_minimo": numero,
  "valor_maximo": numero,
  "metodo": "comparativos"|"custo"|"renda",
  "fatores_avaliacao": {"localizacao": peso, "metragem": peso, "quartos": peso, "padrao": peso, "historico_regiao": peso},
  "imoveis_comparaveis": [{"endereco": "bairro/cidade", "valor": numero, "diferenca_percentual": numero}],
  "metodologia_descricao": "texto explicando o método usado",
  "margem_confianca": numero 0-100
}`;

  const resposta = await callGeminiJson(prompt);

  const { rows } = await pool.query(
    `INSERT INTO avaliacoes_imoveis (imovel_id, valor_estimado, valor_minimo, valor_maximo, metodo,
       fatores_avaliacao, imoveis_comparaveis, metodologia_descricao, margem_confianca, colaborador_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [imovel_id, Number(resposta.valor_estimado) || imovel.valor_venda || 0,
     Number(resposta.valor_minimo) || (Number(resposta.valor_estimado) || 0) * 0.9,
     Number(resposta.valor_maximo) || (Number(resposta.valor_estimado) || 0) * 1.1,
     resposta.metodo || "comparativos",
     JSON.stringify(resposta.fatores_avaliacao || {}),
     JSON.stringify(resposta.imoveis_comparaveis || []),
     resposta.metodologia_descricao || "",
     Number(resposta.margem_confianca) || 70,
     colaborador_id || null]
  );

  return rows[0];
}

// ─── 8. Relatórios Inteligentes ─────────────────────────────────────────────
export async function gerarRelatorioInteligente(pool: any, dados: {
  tipo: string;
  periodo_inicio?: string;
  periodo_fim?: string;
  colaborador_id?: string;
}): Promise<any> {
  const { tipo, periodo_inicio, periodo_fim, colaborador_id } = dados;

  // Coletar dados conforme tipo de relatório
  const wherePeriodo = periodo_inicio && periodo_fim
    ? `WHERE criado_em >= $1 AND criado_em <= $2`
    : "";
  const params = periodo_inicio && periodo_fim ? [periodo_inicio, periodo_fim] : [];

  let dadosRelatorio: any = {};

  if (tipo === "funil" || tipo === "leads") {
    const leadsCount = await pool.query(
      `SELECT COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE etapa_funil = 'novo') as novos,
              COUNT(*) FILTER (WHERE etapa_funil = 'contato') as contato,
              COUNT(*) FILTER (WHERE etapa_funil = 'proposta') as proposta,
              COUNT(*) FILTER (WHERE etapa_funil = 'negociacao') as negociacao,
              COUNT(*) FILTER (WHERE etapa_funil = 'fechado') as fechado
       FROM leads ${wherePeriodo}`,
      params
    );

    const leadsRecentes = await pool.query(
      `SELECT nome_completo as nome, email, telefone, etapa_funil, temperatura, criado_em
       FROM leads ${wherePeriodo} ORDER BY criado_em DESC LIMIT 10`,
      params
    );

    dadosRelatorio = { leads: leadsCount.rows[0], recentes: leadsRecentes.rows };
  }

  if (tipo === "imoveis" || tipo === "vendas") {
    const imoveisCount = await pool.query(
      `SELECT COUNT(*)::int as total,
              COUNT(*) FILTER (WHERE status = 'disponivel') as disponiveis,
              COUNT(*) FILTER (WHERE status = 'vendido') as vendidos,
              COUNT(*) FILTER (WHERE status = 'locado') as locados,
              SUM(valor_venda) FILTER (WHERE status = 'vendido') as total_vendido
       FROM imoveis`
    );

    const imoveisDestaques = await pool.query(
      `SELECT codigo, titulo, tipo, valor_venda, valor_locacao, bairro, cidade, destaque, visualizacoes
       FROM imoveis ORDER BY visualizacoes DESC LIMIT 10`
    );

    dadosRelatorio = { imoveis: imoveisCount.rows[0], destaques: imoveisDestaques.rows };
  }

  if (tipo === "financeiro") {
    const simulacoes = await pool.query(
      `SELECT COUNT(*)::int as total,
              AVG(valor_solicitado)::numeric as media_valor
       FROM simulacoes`
    );

    const contratos = await pool.query(
      `SELECT COUNT(*)::int as total,
              SUM(valor_total)::numeric as total_contratado
       FROM contratos_imobiliarios WHERE status != 'cancelado'`
    );

    dadosRelatorio = { simulacoes: simulacoes.rows[0], contratos: contratos.rows[0] };
  }

  // IA para gerar insights
  const promptInsights = `Você é um analista de negócios imobiliários. Com base nos dados abaixo, gere insights acionáveis.

Tipo de relatório: ${tipo}
${JSON.stringify(dadosRelatorio, null, 2)}

Responda em JSON com:
{
  "insights": [{"titulo": "titulo", "descricao": "descricao detalhada", "impacto": "alto"|"medio"|"baixo"}],
  "recomendacoes": [{"descricao": "recomendação acionável", "prioridade": "alta"|"media"|"baixa"}],
  "relatorio_html": "<html>com HTML completo do relatório</html>"
}`;

  let iaResult: any = {};
  try {
    iaResult = await callGeminiJson(promptInsights);
  } catch (e) {
    iaResult = { insights: [], recomendacoes: [], relatorio_html: "<p>Dados coletados.</p>" };
  }

  const { rows } = await pool.query(
    `INSERT INTO relatorios_inteligentes (tipo, periodo_inicio, periodo_fim, dados, insights_ia,
       recomendacoes_ia, relatorio_html, colaborador_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [tipo, periodo_inicio || null, periodo_fim || null,
     JSON.stringify(dadosRelatorio),
     JSON.stringify(iaResult.insights || []),
     JSON.stringify(iaResult.recomendacoes || []),
     iaResult.relatorio_html || "", colaborador_id || null]
  );

  return {
    relatorio: rows[0],
    dados: dadosRelatorio,
    insights: iaResult.insights || [],
    recomendacoes: iaResult.recomendacoes || [],
  };
}
