// ─── Dados Institucionais Centralizados ───────────────────────────────────────
// Arquivo de referência única para todos os dados de contato e endereço.
// Importe daqui em todos os componentes para garantir consistência.

export const COMPANY = {
  // Casa DF branding
  nome: "Casa DF",
  nomeCompleto: "Casa DF — Gestão Imobiliária",
  instagram: "@casadf.imoveis",
  instagramUrl: "https://instagram.com/casadf.imoveis",
  linkedinUrl: "https://linkedin.com/company/casadfimoveis",

  // ── Contato ──────────────────────────────────────────────────────────────────
  telefone: "(61) 3526-8355",
  telefoneLink: "tel:+556135268355",
  whatsapp: "(61) 3526-8355",
  whatsappLink: "https://wa.me/556135268355",
  whatsappLinkMsg: (msg: string) =>
    `https://wa.me/556135268355?text=${encodeURIComponent(msg)}`,
  email: "contato@casadf.com.br",
  emailLink: "mailto:contato@casadf.com.br",

  // ── Endereços ────────────────────────────────────────────────────────────────
  sede: {
    label: "Sede — Brasília / DF",
    endereco: "QND 25 Lote 40 - Taguatinga Norte",
    cidade: "Brasília - DF",
    enderecoCompleto: "QND 25 Lote 40 - Taguatinga Norte, Brasília - DF",
    mapUrl:
      "https://www.google.com/maps/search/?api=1&query=QND+25+Lote+40+Taguatinga+Norte+Brasilia+DF",
  },
  filialGoiania: {
    label: "Filial — Goiânia / GO",
    endereco: "Praça Cel Vicente Sanches de Almeida, LT 07 Sala 03 - Crimeia Leste",
    cidade: "Goiânia - GO",
    enderecoCompleto:
      "Praça Cel Vicente Sanches de Almeida, LT 07 Sala 03 - Crimeia Leste, Goiânia - GO",
    mapUrl:
      "https://www.google.com/maps/search/?api=1&query=Pra%C3%A7a+Cel+Vicente+Sanches+de+Almeida+LT+07+Sala+03+Crimeia+Leste+Goiania+GO",
  },

  // ── Horários ─────────────────────────────────────────────────────────────────
  horario: {
    semana: "Segunda a Sexta: 8h às 18h",
    sabado: "Sábado: 8h às 12h",
  },
} as const;
