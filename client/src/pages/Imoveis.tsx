import { useEffect, useState } from "react";
import { Link } from "wouter";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Card, CardContent } from "@/components/ui/card";
import { BedDouble, Bath, Car, Ruler, MapPin, Search, Star, SlidersHorizontal, X } from "lucide-react";
import {
  listarImoveis, buscarOpcoesFiltro, Imovel, TIPOS_IMOVEL, FINALIDADES, formatarMoeda,
} from "@/lib/api-imoveis";

function CardImovel({ imovel }: { imovel: Imovel }) {
  const preco =
    imovel.finalidade === "locacao"
      ? `${formatarMoeda(imovel.valor_locacao)}/mês`
      : formatarMoeda(imovel.valor_venda ?? imovel.valor_locacao);

  return (
    <Link href={`/imoveis/${imovel.slug || imovel.id}`}>
      <Card className="overflow-hidden cursor-pointer group hover:shadow-lg transition-shadow h-full flex flex-col">
        <div className="relative aspect-[4/3] bg-muted overflow-hidden">
          {imovel.foto_capa_url ? (
            <img
              src={imovel.foto_capa_url}
              alt={imovel.titulo}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-muted-foreground text-sm">
              Sem foto
            </div>
          )}
          {imovel.destaque && (
            <Badge className="absolute top-2 left-2 bg-amber-600 text-white border-transparent gap-1">
              <Star className="size-3" /> Destaque
            </Badge>
          )}
          <Badge variant="secondary" className="absolute top-2 right-2">
            {imovel.codigo}
          </Badge>
        </div>
        <CardContent className="flex flex-col gap-2 flex-1 pt-4">
          <p className="text-xs text-muted-foreground flex items-center gap-1">
            <MapPin className="size-3" /> {imovel.bairro}
            {imovel.cidade ? `, ${imovel.cidade}` : ""}
          </p>
          <h3 className="font-semibold text-base leading-snug line-clamp-2">{imovel.titulo}</h3>
          <div className="flex items-center gap-3 text-sm text-muted-foreground mt-1">
            {!!imovel.quartos && (
              <span className="flex items-center gap-1"><BedDouble className="size-4" />{imovel.quartos}</span>
            )}
            {!!imovel.banheiros && (
              <span className="flex items-center gap-1"><Bath className="size-4" />{imovel.banheiros}</span>
            )}
            {!!imovel.vagas_garagem && (
              <span className="flex items-center gap-1"><Car className="size-4" />{imovel.vagas_garagem}</span>
            )}
            {!!imovel.area_privativa && (
              <span className="flex items-center gap-1"><Ruler className="size-4" />{imovel.area_privativa}m²</span>
            )}
          </div>
          <p className="font-bold text-primary text-lg mt-auto pt-2">{preco}</p>
        </CardContent>
      </Card>
    </Link>
  );
}

const QUARTOS_OPCOES = ["", "1", "2", "3", "4"];

export default function Imoveis() {
  const [items, setItems] = useState<Imovel[]>([]);
  const [destaques, setDestaques] = useState<Imovel[]>([]);
  const [loading, setLoading] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);

  const [busca, setBusca] = useState("");
  const [finalidade, setFinalidade] = useState<string>("");
  const [tipo, setTipo] = useState<string>("");
  const [bairro, setBairro] = useState<string>("");
  const [quartosMin, setQuartosMin] = useState<string>("");
  const [precoMax, setPrecoMax] = useState<string>("");
  const [mostrarFiltros, setMostrarFiltros] = useState(false);

  const [opcoes, setOpcoes] = useState<{ bairros: string[]; precoMin: number; precoMax: number }>({
    bairros: [], precoMin: 0, precoMax: 0,
  });

  // Opções de filtro dinâmicas — carregadas uma vez a partir dos imóveis reais cadastrados
  useEffect(() => {
    buscarOpcoesFiltro().then(setOpcoes).catch(() => {});
  }, []);

  // Destaques — carregados uma vez para a vitrine de topo
  useEffect(() => {
    listarImoveis({ destaque: true, pageSize: 8 }).then((r) => setDestaques(r.items)).catch(() => {});
  }, []);

  async function carregar(paginaAlvo = page) {
    setLoading(true);
    setErro(null);
    try {
      const res = await listarImoveis({
        busca: busca || undefined,
        finalidade: finalidade || undefined,
        tipo: tipo || undefined,
        bairro: bairro || undefined,
        quartos_min: quartosMin ? Number(quartosMin) : undefined,
        preco_max: precoMax ? Number(precoMax) : undefined,
        page: paginaAlvo,
        pageSize: 12,
      });
      setItems(res.items);
      setTotalPages(res.totalPages);
      setTotal(res.total);
    } catch (e: any) {
      setErro(e?.message || "Erro ao carregar imóveis");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    carregar(page);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  function aplicarFiltros(e: React.FormEvent) {
    e.preventDefault();
    setPage(1);
    carregar(1);
  }

  function limparFiltros() {
    setBusca(""); setFinalidade(""); setTipo(""); setBairro(""); setQuartosMin(""); setPrecoMax("");
    setPage(1);
    setTimeout(() => carregar(1), 0);
  }

  const filtrosAtivos = [finalidade, tipo, bairro, quartosMin, precoMax].filter(Boolean).length;

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1">
        <section className="bg-gradient-to-br from-slate-900 to-slate-700 text-white py-12">
          <div className="container mx-auto px-4">
            <h1 className="text-3xl md:text-4xl font-bold mb-2">Encontre o seu próximo imóvel</h1>
            <p className="text-slate-300 mb-6">
              Casas, apartamentos, salas comerciais e terrenos em Brasília e região.
            </p>

            <form onSubmit={aplicarFiltros} className="bg-white rounded-lg p-3 flex flex-col md:flex-row gap-2 shadow-lg">
              <div className="flex-1 flex items-center gap-2 px-2">
                <Search className="size-4 text-muted-foreground shrink-0" />
                <Input
                  placeholder="Busque por bairro, título ou código..."
                  value={busca}
                  onChange={(e) => setBusca(e.target.value)}
                  className="border-0 shadow-none focus-visible:ring-0 text-slate-900"
                />
              </div>
              <Select value={finalidade || "todas"} onValueChange={(v) => setFinalidade(v === "todas" ? "" : v)}>
                <SelectTrigger className="w-full md:w-40 text-slate-900"><SelectValue placeholder="Comprar/Alugar" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="todas">Comprar ou alugar</SelectItem>
                  {FINALIDADES.map((f) => <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>)}
                </SelectContent>
              </Select>
              <Button
                type="button"
                variant="outline"
                className="text-slate-900 gap-1"
                onClick={() => setMostrarFiltros((v) => !v)}
              >
                <SlidersHorizontal className="size-4" /> Filtros {filtrosAtivos > 0 && `(${filtrosAtivos})`}
              </Button>
              <Button type="submit" className="bg-amber-600 hover:bg-amber-700">Buscar</Button>
            </form>

            {mostrarFiltros && (
              <div className="bg-white rounded-lg p-4 mt-2 shadow-lg grid sm:grid-cols-2 md:grid-cols-4 gap-2">
                <Select value={tipo || "todos"} onValueChange={(v) => setTipo(v === "todos" ? "" : v)}>
                  <SelectTrigger className="text-slate-900"><SelectValue placeholder="Tipo de imóvel" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="todos">Todos os tipos</SelectItem>
                    {TIPOS_IMOVEL.map((t) => <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>)}
                  </SelectContent>
                </Select>

                <Select value={bairro || "todos"} onValueChange={(v) => setBairro(v === "todos" ? "" : v)}>
                  <SelectTrigger className="text-slate-900"><SelectValue placeholder="Bairro" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="todos">Todos os bairros</SelectItem>
                    {opcoes.bairros.map((b) => <SelectItem key={b} value={b}>{b}</SelectItem>)}
                  </SelectContent>
                </Select>

                <Select value={quartosMin || "qualquer"} onValueChange={(v) => setQuartosMin(v === "qualquer" ? "" : v)}>
                  <SelectTrigger className="text-slate-900"><SelectValue placeholder="Quartos" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="qualquer">Quantidade de quartos</SelectItem>
                    {QUARTOS_OPCOES.filter(Boolean).map((q) => (
                      <SelectItem key={q} value={q}>{q}+ quarto(s)</SelectItem>
                    ))}
                  </SelectContent>
                </Select>

                <Input
                  type="number"
                  placeholder={opcoes.precoMax ? `Valor até (máx. ${formatarMoeda(opcoes.precoMax)})` : "Valor máximo (R$)"}
                  value={precoMax}
                  onChange={(e) => setPrecoMax(e.target.value)}
                  className="text-slate-900"
                />

                <div className="sm:col-span-2 md:col-span-4 flex justify-end gap-2 pt-1">
                  {filtrosAtivos > 0 && (
                    <Button type="button" variant="ghost" size="sm" className="text-slate-600 gap-1" onClick={limparFiltros}>
                      <X className="size-3.5" /> Limpar filtros
                    </Button>
                  )}
                  <Button type="submit" size="sm" onClick={aplicarFiltros}>Aplicar filtros</Button>
                </div>
              </div>
            )}
          </div>
        </section>

        {destaques.length > 0 && (
          <section className="container mx-auto px-4 py-10 border-b">
            <h2 className="text-xl font-bold mb-4 flex items-center gap-2">
              <Star className="size-5 text-amber-600" /> Imóveis em destaque
            </h2>
            <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
              {destaques.slice(0, 4).map((imovel) => <CardImovel key={imovel.id} imovel={imovel} />)}
            </div>
          </section>
        )}

        <section className="container mx-auto px-4 py-10">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold">Todos os imóveis</h2>
            {!loading && !erro && <p className="text-sm text-muted-foreground">{total} imóvel(is) encontrado(s)</p>}
          </div>

          {loading && <p className="text-center text-muted-foreground py-10">Carregando imóveis...</p>}
          {erro && <p className="text-center text-destructive py-10">{erro}</p>}
          {!loading && !erro && items.length === 0 && (
            <p className="text-center text-muted-foreground py-10">
              Nenhum imóvel encontrado com esses filtros.
            </p>
          )}

          {!loading && !erro && items.length > 0 && (
            <>
              <div className="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                {items.map((imovel) => <CardImovel key={imovel.id} imovel={imovel} />)}
              </div>

              {totalPages > 1 && (
                <div className="flex justify-center gap-2 mt-8">
                  <Button variant="outline" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
                    Anterior
                  </Button>
                  <span className="flex items-center px-3 text-sm text-muted-foreground">
                    Página {page} de {totalPages}
                  </span>
                  <Button variant="outline" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
                    Próxima
                  </Button>
                </div>
              )}
            </>
          )}
        </section>
      </main>
      <Footer />
    </div>
  );
}
