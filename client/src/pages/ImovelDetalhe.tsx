import { useEffect, useState } from "react";
import { useRoute, Link } from "wouter";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  BedDouble, Bath, Car, Ruler, MapPin, ArrowLeft, Phone, Mail, CheckCircle2,
} from "lucide-react";
import { buscarImovel, criarVisita, Imovel, formatarMoeda } from "@/lib/api-imoveis";
import { COMPANY } from "@/config/company";

function urlEmbedVideo(url?: string): string | null {
  if (!url) return null;
  const yt = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]+)/);
  if (yt) return `https://www.youtube.com/embed/${yt[1]}`;
  const vimeo = url.match(/vimeo\.com\/(\d+)/);
  if (vimeo) return `https://player.vimeo.com/video/${vimeo[1]}`;
  return url;
}

export default function ImovelDetalhe() {
  const [, params] = useRoute("/imoveis/:idOrSlug");
  const idOrSlug = params?.idOrSlug || "";

  const [imovel, setImovel] = useState<Imovel | null>(null);
  const [loading, setLoading] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [fotoAtiva, setFotoAtiva] = useState(0);
  const [lightboxAberto, setLightboxAberto] = useState(false);

  const [nome, setNome] = useState("");
  const [telefone, setTelefone] = useState("");
  const [email, setEmail] = useState("");
  const [mensagem, setMensagem] = useState("");
  const [enviando, setEnviando] = useState(false);
  const [enviado, setEnviado] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);

  useEffect(() => {
    if (!idOrSlug) return;
    setLoading(true);
    buscarImovel(idOrSlug)
      .then(setImovel)
      .catch((e) => setErro(e?.message || "Imóvel não encontrado"))
      .finally(() => setLoading(false));
  }, [idOrSlug]);

  async function agendarVisita(e: React.FormEvent) {
    e.preventDefault();
    if (!imovel) return;
    setErroForm(null);
    if (!nome.trim()) {
      setErroForm("Informe seu nome.");
      return;
    }
    setEnviando(true);
    try {
      await criarVisita({
        imovel_id: imovel.id,
        visitante_nome: nome,
        visitante_telefone: telefone || undefined,
        visitante_email: email || undefined,
        observacoes: mensagem || undefined,
        origem_lead: "site",
        status: "agendada",
      });
      setEnviado(true);
    } catch (err: any) {
      setErroForm(err?.message || "Não foi possível registrar sua solicitação. Tente novamente.");
    } finally {
      setEnviando(false);
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col">
        <Header />
        <main className="flex-1 container mx-auto px-4 py-16 text-center text-muted-foreground">
          Carregando imóvel...
        </main>
        <Footer />
      </div>
    );
  }

  if (erro || !imovel) {
    return (
      <div className="min-h-screen flex flex-col">
        <Header />
        <main className="flex-1 container mx-auto px-4 py-16 text-center">
          <p className="text-muted-foreground mb-4">{erro || "Imóvel não encontrado."}</p>
          <Link href="/imoveis"><Button variant="outline">Voltar para a vitrine</Button></Link>
        </main>
        <Footer />
      </div>
    );
  }

  const fotos = imovel.fotos && imovel.fotos.length > 0
    ? imovel.fotos
    : imovel.foto_capa_url
      ? [{ id: "capa", url: imovel.foto_capa_url, ordem: 0, capa: true }]
      : [];

  const preco = imovel.finalidade === "locacao"
    ? `${formatarMoeda(imovel.valor_locacao)}/mês`
    : formatarMoeda(imovel.valor_venda ?? imovel.valor_locacao);

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 container mx-auto px-4 py-8">
        <Link href="/imoveis" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-4">
          <ArrowLeft className="size-4" /> Voltar para a vitrine
        </Link>

        <div className="grid lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
            {/* Galeria */}
            <div className="rounded-lg overflow-hidden bg-muted aspect-[16/10] mb-2 cursor-zoom-in" onClick={() => fotos.length > 0 && setLightboxAberto(true)}>
              {fotos.length > 0 ? (
                <img src={fotos[fotoAtiva]?.url} alt={imovel.titulo} className="w-full h-full object-cover hover:scale-[1.02] transition-transform duration-300" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-muted-foreground">Sem fotos disponíveis</div>
              )}
            </div>
            {fotos.length > 1 && (
              <div className="flex gap-2 overflow-x-auto pb-2">
                {fotos.map((f, i) => (
                  <button
                    key={f.id}
                    onClick={() => setFotoAtiva(i)}
                    className={`shrink-0 w-20 h-16 rounded overflow-hidden border-2 ${i === fotoAtiva ? "border-amber-600" : "border-transparent"}`}
                  >
                    <img src={f.url} alt="" className="w-full h-full object-cover" />
                  </button>
                ))}
              </div>
            )}

            <div className="mt-6">
              <div className="flex items-center gap-2 mb-1">
                <Badge variant="secondary">{imovel.codigo}</Badge>
                <Badge variant="outline">{imovel.tipo}</Badge>
                {imovel.destaque && <Badge className="bg-amber-600 text-white border-transparent">Destaque</Badge>}
              </div>
              <h1 className="text-2xl md:text-3xl font-bold mb-1">{imovel.titulo}</h1>
              <p className="text-muted-foreground flex items-center gap-1 mb-4">
                <MapPin className="size-4" />
                {[imovel.endereco, imovel.bairro, imovel.cidade, imovel.uf].filter(Boolean).join(", ")}
              </p>

              <div className="flex flex-wrap gap-6 text-sm border-y py-4 mb-6">
                {!!imovel.quartos && <span className="flex items-center gap-2"><BedDouble className="size-5 text-amber-600" />{imovel.quartos} quarto(s){!!imovel.suites && ` · ${imovel.suites} suíte(s)`}</span>}
                {!!imovel.banheiros && <span className="flex items-center gap-2"><Bath className="size-5 text-amber-600" />{imovel.banheiros} banheiro(s)</span>}
                {!!imovel.vagas_garagem && <span className="flex items-center gap-2"><Car className="size-5 text-amber-600" />{imovel.vagas_garagem} vaga(s)</span>}
                {!!imovel.area_privativa && <span className="flex items-center gap-2"><Ruler className="size-5 text-amber-600" />{imovel.area_privativa}m² privativos</span>}
              </div>

              {imovel.descricao && (
                <div className="mb-6">
                  <h2 className="font-semibold text-lg mb-2">Descrição</h2>
                  <p className="text-muted-foreground whitespace-pre-wrap">{imovel.descricao}</p>
                </div>
              )}

              {imovel.comodidades && imovel.comodidades.length > 0 && (
                <div className="mb-6">
                  <h2 className="font-semibold text-lg mb-2">Comodidades</h2>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    {imovel.comodidades.map((c) => (
                      <span key={c} className="flex items-center gap-2 text-sm text-muted-foreground">
                        <CheckCircle2 className="size-4 text-emerald-600" /> {c}
                      </span>
                    ))}
                  </div>
                </div>
              )}
              {imovel.video_url && (
                <div className="mb-6">
                  <h2 className="font-semibold text-lg mb-2">Vídeo do imóvel</h2>
                  <div className="aspect-video rounded-lg overflow-hidden bg-black">
                    <iframe
                      src={urlEmbedVideo(imovel.video_url) || undefined}
                      className="w-full h-full"
                      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                      allowFullScreen
                    />
                  </div>
                </div>
              )}

              {imovel.tour_virtual_url && (
                <div className="mb-6">
                  <h2 className="font-semibold text-lg mb-2">Tour virtual 360°</h2>
                  <div className="aspect-video rounded-lg overflow-hidden bg-black">
                    <iframe src={imovel.tour_virtual_url} className="w-full h-full" allowFullScreen />
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Coluna lateral — preço + contato + agendamento */}
          <div>
            <Card className="sticky top-4">
              <CardContent className="pt-6">
                <p className="text-sm text-muted-foreground mb-1">
                  {imovel.finalidade === "locacao" ? "Aluguel" : "Valor"}
                </p>
                <p className="text-3xl font-bold text-primary mb-1">{preco}</p>
                {!!imovel.valor_condominio && (
                  <p className="text-sm text-muted-foreground">Condomínio: {formatarMoeda(imovel.valor_condominio)}</p>
                )}
                {!!imovel.valor_iptu && (
                  <p className="text-sm text-muted-foreground mb-4">IPTU: {formatarMoeda(imovel.valor_iptu)}</p>
                )}

                <div className="flex flex-col gap-2 mb-6 mt-4">
                  <a href={COMPANY.whatsappLinkMsg(`Olá! Tenho interesse no imóvel ${imovel.codigo} - ${imovel.titulo}`)} target="_blank" rel="noreferrer">
                    <Button className="w-full bg-emerald-600 hover:bg-emerald-700 gap-2"><Phone className="size-4" /> Falar no WhatsApp</Button>
                  </a>
                  <a href={COMPANY.emailLink}>
                    <Button variant="outline" className="w-full gap-2"><Mail className="size-4" /> Enviar e-mail</Button>
                  </a>
                </div>

                <hr className="mb-4" />

                <h3 className="font-semibold mb-3">Agendar visita</h3>
                {enviado ? (
                  <p className="text-sm text-emerald-700 bg-emerald-50 rounded p-3">
                    Solicitação enviada! Nossa equipe entrará em contato para confirmar o melhor horário.
                  </p>
                ) : (
                  <form onSubmit={agendarVisita} className="flex flex-col gap-2">
                    <Input placeholder="Seu nome" value={nome} onChange={(e) => setNome(e.target.value)} required />
                    <Input placeholder="Telefone / WhatsApp" value={telefone} onChange={(e) => setTelefone(e.target.value)} />
                    <Input placeholder="E-mail" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
                    <Textarea placeholder="Mensagem (opcional)" value={mensagem} onChange={(e) => setMensagem(e.target.value)} rows={3} />
                    {erroForm && <p className="text-sm text-destructive">{erroForm}</p>}
                    <Button type="submit" disabled={enviando} className="mt-1">
                      {enviando ? "Enviando..." : "Solicitar visita"}
                    </Button>
                  </form>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </main>

      {lightboxAberto && fotos.length > 0 && (
        <div
          className="fixed inset-0 bg-black/90 z-50 flex flex-col items-center justify-center p-4"
          onClick={() => setLightboxAberto(false)}
        >
          <button
            className="absolute top-4 right-4 text-white text-3xl leading-none"
            onClick={() => setLightboxAberto(false)}
            aria-label="Fechar"
          >
            &times;
          </button>
          <img
            src={fotos[fotoAtiva]?.url}
            alt={imovel.titulo}
            className="max-h-[85vh] max-w-full object-contain"
            onClick={(e) => e.stopPropagation()}
          />
          {fotos.length > 1 && (
            <div className="flex gap-2 mt-4 overflow-x-auto max-w-full px-4" onClick={(e) => e.stopPropagation()}>
              {fotos.map((f, i) => (
                <button
                  key={f.id}
                  onClick={() => setFotoAtiva(i)}
                  className={`shrink-0 w-16 h-12 rounded overflow-hidden border-2 ${i === fotoAtiva ? "border-amber-500" : "border-transparent opacity-70"}`}
                >
                  <img src={f.url} alt="" className="w-full h-full object-cover" />
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      <Footer />
    </div>
  );
}
