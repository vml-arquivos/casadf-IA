import { apiFetch } from "./api";

// ─── API — Módulo Imobiliário (Casa DF) ─────────────────────────────────────

export type Imovel = {
  id: string;
  codigo: string;
  slug: string;
  titulo: string;
  descricao?: string;
  tipo: string;
  finalidade: string;
  status: string;
  valor_venda?: number | null;
  valor_locacao?: number | null;
  valor_condominio?: number | null;
  valor_iptu?: number | null;
  aceita_permuta?: boolean;
  aceita_financiamento?: boolean;
  endereco?: string;
  numero?: string;
  complemento?: string;
  bairro?: string;
  cidade?: string;
  uf?: string;
  cep?: string;
  area_privativa?: number | null;
  area_total?: number | null;
  quartos?: number;
  suites?: number;
  banheiros?: number;
  vagas_garagem?: number;
  andar?: string;
  ano_construcao?: number | null;
  mobiliado?: boolean;
  comodidades?: string[];
  proprietario_nome?: string;
  proprietario_telefone?: string;
  proprietario_email?: string;
  proprietario_cpf_cnpj?: string;
  matricula_imovel?: string;
  observacoes_internas?: string;
  destaque?: boolean;
  foto_capa_url?: string;
  meta_titulo?: string;
  meta_descricao?: string;
  responsavel_id?: string;
  imobiliaria_id?: string;
  corretor_id?: string;
  video_url?: string;
  tour_virtual_url?: string;
  visualizacoes?: number;
  criado_em?: string;
  atualizado_em?: string;
  fotos?: ImovelFoto[];
};

export type ImovelFoto = {
  id: string;
  url: string;
  legenda?: string;
  ordem: number;
  capa: boolean;
};

export type ImovelListParams = {
  finalidade?: string;
  tipo?: string;
  bairro?: string;
  cidade?: string;
  preco_min?: number;
  preco_max?: number;
  quartos_min?: number;
  vagas_min?: number;
  destaque?: boolean;
  busca?: string;
  status?: string;
  admin?: boolean;
  page?: number;
  pageSize?: number;
};

export type ImovelListResponse = {
  items: Imovel[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
};

function buildQuery(params: Record<string, any>): string {
  const usp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null || v === "") continue;
    usp.set(k, String(v === true ? "1" : v));
  }
  const qs = usp.toString();
  return qs ? `?${qs}` : "";
}

export async function buscarOpcoesFiltro(): Promise<{ bairros: string[]; cidades: string[]; precoMin: number; precoMax: number }> {
  return apiFetch(`/api/imoveis/filtros/opcoes`);
}

export async function listarImoveis(params: ImovelListParams = {}): Promise<ImovelListResponse> {
  return apiFetch(`/api/imoveis${buildQuery(params)}`);
}

export async function buscarImovel(idOrSlug: string, admin = false): Promise<Imovel> {
  return apiFetch(`/api/imoveis/${idOrSlug}${admin ? "?admin=1" : ""}`);
}

export async function criarImovel(dados: Partial<Imovel>): Promise<Imovel> {
  return apiFetch(`/api/imoveis`, { method: "POST", body: JSON.stringify(dados) });
}

export async function atualizarImovel(id: string, dados: Partial<Imovel>): Promise<Imovel> {
  return apiFetch(`/api/imoveis/${id}`, { method: "PUT", body: JSON.stringify(dados) });
}

export async function excluirImovel(id: string): Promise<void> {
  await apiFetch(`/api/imoveis/${id}`, { method: "DELETE" });
}

export async function enviarFotosImovel(id: string, files: File[]): Promise<ImovelFoto[]> {
  const fd = new FormData();
  files.forEach((f) => fd.append("fotos", f));
  return apiFetch(`/api/imoveis/${id}/fotos`, { method: "POST", body: fd });
}

export async function excluirFotoImovel(imovelId: string, fotoId: string): Promise<void> {
  await apiFetch(`/api/imoveis/${imovelId}/fotos/${fotoId}`, { method: "DELETE" });
}

export async function definirFotoCapa(imovelId: string, fotoId: string): Promise<void> {
  await apiFetch(`/api/imoveis/${imovelId}/fotos/${fotoId}/capa`, { method: "PUT" });
}

// ── Fichas de visita ─────────────────────────────────────────────────────────

export type ImovelVisita = {
  id: string;
  imovel_id: string;
  imovel_titulo?: string;
  imovel_codigo?: string;
  visitante_nome: string;
  visitante_telefone?: string;
  visitante_email?: string;
  visitante_cpf?: string;
  corretor_id?: string;
  corretor_nome?: string;
  data_visita: string;
  origem_lead?: string;
  interesse_nivel?: string;
  observacoes?: string;
  feedback_visitante?: string;
  proximos_passos?: string;
  status: string;
};

export async function listarVisitas(params: { imovel_id?: string; status?: string; page?: number; pageSize?: number } = {}) {
  return apiFetch(`/api/imovel-visitas${buildQuery(params)}`) as Promise<{ items: ImovelVisita[]; total: number }>;
}

export async function criarVisita(dados: Partial<ImovelVisita>): Promise<ImovelVisita> {
  return apiFetch(`/api/imovel-visitas`, { method: "POST", body: JSON.stringify(dados) });
}

export async function atualizarVisita(id: string, dados: Partial<ImovelVisita>): Promise<ImovelVisita> {
  return apiFetch(`/api/imovel-visitas/${id}`, { method: "PUT", body: JSON.stringify(dados) });
}

export function urlPdfVisita(id: string): string {
  return `/api/imovel-visitas/${id}/pdf`;
}

// ── Contratos imobiliários ───────────────────────────────────────────────────

export type ContratoImobiliario = {
  id: string;
  numero: string;
  tipo: "compra_venda" | "promessa_compra_venda" | "prestacao_servico" | "assessoria_venda_exclusiva"
    | "assessoria_venda_sem_exclusiva" | "avaliacao_imovel" | "aluguel" | "cessao_direitos";
  status: string;
  imovel_id?: string;
  imovel_titulo?: string;
  imovel_codigo?: string;
  imobiliaria_id?: string;
  corretor_id?: string;
  parte1_nome: string;
  parte1_cpf_cnpj?: string;
  parte1_endereco?: string;
  parte1_email?: string;
  parte1_telefone?: string;
  parte1_estado_civil?: string;
  parte2_nome: string;
  parte2_cpf_cnpj?: string;
  parte2_endereco?: string;
  parte2_email?: string;
  parte2_telefone?: string;
  parte2_estado_civil?: string;
  valor_total?: number;
  valor_entrada?: number;
  forma_pagamento?: string;
  numero_parcelas?: number;
  valor_parcela?: number;
  vencimento_dia?: number;
  percentual_comissao?: number;
  objeto_descricao?: string;
  clausulas_extra?: string;
  data_assinatura?: string;
  cidade_foro?: string;
  testemunha_1_nome?: string;
  testemunha_1_cpf?: string;
  testemunha_2_nome?: string;
  testemunha_2_cpf?: string;
  prazo_vigencia_meses?: number;
  garantia_locaticia?: string;
  valor_caucao?: number;
  indice_reajuste?: string;
  metodologia_avaliacao?: string;
  valor_avaliacao?: number;
};

export async function listarContratos(params: { tipo?: string; status?: string; imovel_id?: string; page?: number; pageSize?: number } = {}) {
  return apiFetch(`/api/contratos-imobiliarios${buildQuery(params)}`) as Promise<{ items: ContratoImobiliario[]; total: number }>;
}

export async function buscarContrato(id: string): Promise<ContratoImobiliario> {
  return apiFetch(`/api/contratos-imobiliarios/${id}`);
}

export async function criarContrato(dados: Partial<ContratoImobiliario>): Promise<ContratoImobiliario> {
  return apiFetch(`/api/contratos-imobiliarios`, { method: "POST", body: JSON.stringify(dados) });
}

export async function atualizarContrato(id: string, dados: Partial<ContratoImobiliario>): Promise<ContratoImobiliario> {
  return apiFetch(`/api/contratos-imobiliarios/${id}`, { method: "PUT", body: JSON.stringify(dados) });
}

export function urlPdfContrato(id: string): string {
  return `/api/contratos-imobiliarios/${id}/pdf`;
}

// ── Constantes de UI ─────────────────────────────────────────────────────────

export const TIPOS_IMOVEL = [
  { value: "casa", label: "Casa" },
  { value: "apartamento", label: "Apartamento" },
  { value: "cobertura", label: "Cobertura" },
  { value: "sobrado", label: "Sobrado" },
  { value: "kitnet", label: "Kitnet" },
  { value: "terreno", label: "Terreno" },
  { value: "sala_comercial", label: "Sala Comercial" },
  { value: "loja", label: "Loja" },
  { value: "galpao", label: "Galpão" },
  { value: "rural", label: "Rural" },
  { value: "outro", label: "Outro" },
];

export const FINALIDADES = [
  { value: "venda", label: "Venda" },
  { value: "locacao", label: "Locação" },
  { value: "venda_locacao", label: "Venda ou Locação" },
];

export const STATUS_IMOVEL = [
  { value: "disponivel", label: "Disponível" },
  { value: "reservado", label: "Reservado" },
  { value: "vendido", label: "Vendido" },
  { value: "locado", label: "Locado" },
  { value: "inativo", label: "Inativo" },
];

export const TIPOS_CONTRATO = [
  { value: "compra_venda", label: "Compra e Venda" },
  { value: "promessa_compra_venda", label: "Promessa de Compra e Venda" },
  { value: "prestacao_servico", label: "Prestação de Serviço (Corretagem)" },
  { value: "assessoria_venda_exclusiva", label: "Assessoria de Venda — Com Exclusividade" },
  { value: "assessoria_venda_sem_exclusiva", label: "Assessoria de Venda — Sem Exclusividade" },
  { value: "avaliacao_imovel", label: "Avaliação de Imóveis" },
  { value: "aluguel", label: "Aluguel (Locação)" },
  { value: "cessao_direitos", label: "Cessão de Direitos" },
];

export const GARANTIAS_LOCATICIAS = [
  { value: "caucao", label: "Caução em dinheiro" },
  { value: "fianca", label: "Fiança pessoal" },
  { value: "seguro_fianca", label: "Seguro-fiança" },
  { value: "titulo_capitalizacao", label: "Título de capitalização" },
];

export function formatarMoeda(v: number | null | undefined): string {
  if (v === null || v === undefined || Number.isNaN(Number(v))) return "Consulte";
  return Number(v).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

// ── Imobiliárias e Corretores (Configurações) ────────────────────────────────

export type Imobiliaria = {
  id: string;
  nome: string;
  cnpj?: string;
  creci_juridico?: string;
  logo_url?: string;
  endereco?: string;
  cidade?: string;
  uf?: string;
  telefone?: string;
  whatsapp?: string;
  email?: string;
  site_url?: string;
  instagram_url?: string;
  cor_primaria?: string;
  rodape_texto?: string;
  padrao: boolean;
  ativa: boolean;
};

export type Corretor = {
  id: string;
  imobiliaria_id?: string;
  imobiliaria_nome?: string;
  nome: string;
  creci?: string;
  telefone?: string;
  whatsapp?: string;
  email?: string;
  foto_url?: string;
  ativo: boolean;
};

export async function listarImobiliarias(): Promise<Imobiliaria[]> {
  return apiFetch(`/api/imobiliarias`);
}

export async function criarImobiliaria(dados: Partial<Imobiliaria>): Promise<Imobiliaria> {
  return apiFetch(`/api/imobiliarias`, { method: "POST", body: JSON.stringify(dados) });
}

export async function atualizarImobiliaria(id: string, dados: Partial<Imobiliaria>): Promise<Imobiliaria> {
  return apiFetch(`/api/imobiliarias/${id}`, { method: "PUT", body: JSON.stringify(dados) });
}

export async function definirImobiliariaPadrao(id: string): Promise<Imobiliaria> {
  return apiFetch(`/api/imobiliarias/${id}/padrao`, { method: "PUT" });
}

export async function excluirImobiliaria(id: string): Promise<void> {
  await apiFetch(`/api/imobiliarias/${id}`, { method: "DELETE" });
}

export async function enviarLogoImobiliaria(id: string, file: File): Promise<Imobiliaria> {
  const fd = new FormData();
  fd.append("logo", file);
  return apiFetch(`/api/imobiliarias/${id}/logo`, { method: "POST", body: fd });
}

export async function listarCorretores(imobiliariaId?: string): Promise<Corretor[]> {
  return apiFetch(`/api/corretores${imobiliariaId ? `?imobiliaria_id=${imobiliariaId}` : ""}`);
}

export async function criarCorretor(dados: Partial<Corretor>): Promise<Corretor> {
  return apiFetch(`/api/corretores`, { method: "POST", body: JSON.stringify(dados) });
}

export async function atualizarCorretor(id: string, dados: Partial<Corretor>): Promise<Corretor> {
  return apiFetch(`/api/corretores/${id}`, { method: "PUT", body: JSON.stringify(dados) });
}

export async function excluirCorretor(id: string): Promise<void> {
  await apiFetch(`/api/corretores/${id}`, { method: "DELETE" });
}

export async function enviarFotoCorretor(id: string, file: File): Promise<Corretor> {
  const fd = new FormData();
  fd.append("foto", file);
  return apiFetch(`/api/corretores/${id}/foto`, { method: "POST", body: fd });
}
// ═══════════════════════════════════════════════════════════════════════════════
// API — IA Imobiliária (Casa DF Gestão Imobiliária Inteligente)
// ═══════════════════════════════════════════════════════════════════════════════

export type LeadScore = {
  id: string;
  lead_id: string;
  score: number;
  classificacao: string;
  fatores: Record<string, number>;
  detalhes: Record<string, any>;
  observacoes_ia?: string;
  criado_em: string;
  atualizado_em: string;
};

export type MatchImovel = {
  id: string;
  lead_id: string;
  imovel_id: string;
  score_compatibilidade: number;
  razoes: string[];
  fatores_match: Record<string, number>;
  posicao_ranking: number;
  criado_em: string;
  codigo?: string;
  titulo?: string;
  tipo?: string;
  valor_venda?: number;
  valor_locacao?: number;
  bairro?: string;
  cidade?: string;
  foto_capa_url?: string;
};

export type SimulacaoBanco = {
  banco: string;
  chave: string;
  cor: string;
  sistema: string;
  taxa_juros_mensal: number;
  taxa_seguro: number;
  taxa_sf: number;
  valor_financiamento: number;
  parcela_mensal: number;
  total_juros: number;
  total_seguro: number;
  total_pago: number;
};

export type SimulacaoMultiBanco = {
  id: string;
  valor_imovel: number;
  valor_entrada: number;
  prazo_meses: number;
  resultado_caixa?: Record<string, any>;
  resultado_itau?: Record<string, any>;
  resultado_santander?: Record<string, any>;
  resultado_bradesco?: Record<string, any>;
  resultado_banco_brasil?: Record<string, any>;
  resultado_brb?: Record<string, any>;
  recomendacao?: string;
  criado_em: string;
};

export type AnaliseJuridica = {
  id: string;
  documento_id?: string;
  imovel_id?: string;
  lead_id?: string;
  tipo_documento?: string;
  riscos_identificados: { tipo: string; descricao: string; nivel: string }[];
  pendencias: { descricao: string; acao_requerida: string }[];
  recomendacoes: { descricao: string; prioridade: string }[];
  necessidade_revisao: boolean;
  analise_ia?: string;
  resumo_executivo?: string;
  criado_em: string;
};

export type AnaliseFinanceira = {
  id: string;
  lead_id: string;
  renda_mensal?: number;
  capacidade_compra: number;
  comprometimento_renda: number;
  entrada_necessaria: number;
  prazo_ideal_meses: number;
  risco_aprovacao: string;
  perfil_financeiro: Record<string, any>;
  recomendacao_ia?: string;
  criado_em: string;
};

export type AvaliacaoImovel = {
  id: string;
  imovel_id: string;
  valor_estimado: number;
  valor_minimo?: number;
  valor_maximo?: number;
  metodo?: string;
  fatores_avaliacao: Record<string, number>;
  imoveis_comparaveis: any[];
  metodologia_descricao?: string;
  margem_confianca?: number;
  criado_em: string;
};

export type AssistenteResponse = {
  session_id: string;
  resposta: string;
  historico_len: number;
};

// ── IA Imobiliária: endpoints ─────────────────────────────────────────────────

export async function calcularLeadScore(leadId: string, extras?: any): Promise<LeadScore> {
  return apiFetch(`/api/ia/lead-score`, {
    method: "POST",
    body: JSON.stringify({ lead_id: leadId, ...extras }),
  });
}

export async function buscarLeadScore(leadId: string): Promise<LeadScore> {
  return apiFetch(`/api/ia/lead-score/${leadId}`);
}

export async function encontrarMatches(leadId: string, limit?: number): Promise<{ matches: MatchImovel[]; total: number }> {
  return apiFetch(`/api/ia/match-imovel`, {
    method: "POST",
    body: JSON.stringify({ lead_id: leadId, limit }),
  });
}

export async function buscarMatches(leadId: string): Promise<{ matches: MatchImovel[] }> {
  return apiFetch(`/api/ia/match-imovel/${leadId}`);
}

export async function simularMultiBanco(dados: {
  valor_imovel: number;
  entrada: number;
  prazo_meses: number;
  lead_id?: string;
  imovel_id?: string;
}): Promise<any> {
  return apiFetch(`/api/ia/simulador-multi-banco`, {
    method: "POST",
    body: JSON.stringify(dados),
  });
}

export async function assistenteEnviar(sessionId: string, mensagem: string, contexto?: any): Promise<AssistenteResponse> {
  return apiFetch(`/api/ia/assistente`, {
    method: "POST",
    body: JSON.stringify({ session_id: sessionId, mensagem, contexto }),
  });
}

export async function buscarSessaoAssistente(sessionId: string): Promise<any> {
  return apiFetch(`/api/ia/assistente/${sessionId}`);
}

export async function analisarJuridico(dados: {
  documento_id?: string;
  imovel_id?: string;
  lead_id?: string;
  tipo_documento?: string;
  conteudo?: string;
}): Promise<AnaliseJuridica> {
  return apiFetch(`/api/ia/analise-juridica`, {
    method: "POST",
    body: JSON.stringify(dados),
  });
}

export async function buscarAnalisesJuridicasImovel(imovelId: string): Promise<{ analises: AnaliseJuridica[] }> {
  return apiFetch(`/api/ia/analise-juridica/imovel/${imovelId}`);
}

export async function analisarFinanceiro(dados: {
  lead_id: string;
  imovel_id?: string;
  renda_mensal?: number;
  compromissos_mensais?: number;
}): Promise<AnaliseFinanceira> {
  return apiFetch(`/api/ia/analise-financeira`, {
    method: "POST",
    body: JSON.stringify(dados),
  });
}

export async function buscarAnalisesFinanceiras(leadId: string): Promise<{ analises: AnaliseFinanceira[] }> {
  return apiFetch(`/api/ia/analise-financeira/${leadId}`);
}

export async function avaliarImovelApi(imovelId: string): Promise<AvaliacaoImovel> {
  return apiFetch(`/api/ia/avaliacao-imovel`, {
    method: "POST",
    body: JSON.stringify({ imovel_id: imovelId }),
  });
}

export async function buscarAvaliacoesImovel(imovelId: string): Promise<{ avaliacoes: AvaliacaoImovel[] }> {
  return apiFetch(`/api/ia/avaliacao-imovel/${imovelId}`);
}

export async function gerarRelatorioInteligente(tipo: string, periodo_inicio?: string, periodo_fim?: string): Promise<any> {
  return apiFetch(`/api/ia/relatorio-inteligente`, {
    method: "POST",
    body: JSON.stringify({ tipo, periodo_inicio, periodo_fim }),
  });
}

export async function buscarIADashboard(): Promise<any> {
  return apiFetch(`/api/ia/dashboard`);
}
