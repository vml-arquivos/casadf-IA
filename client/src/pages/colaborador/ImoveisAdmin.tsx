import { useEffect, useState } from "react";
import { Link } from "wouter";
import Layout from "./Layout";
import { toast } from "sonner";
import {
  Plus, Search, MapPin, BedDouble, Bath, Car, Ruler, Star, Trash2, Pencil, Eye,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  listarImoveis, excluirImovel, Imovel, TIPOS_IMOVEL, FINALIDADES, STATUS_IMOVEL, formatarMoeda,
} from "@/lib/api-imoveis";

const STATUS_COR: Record<string, string> = {
  disponivel: "bg-emerald-100 text-emerald-800 border-emerald-200",
  reservado: "bg-amber-100 text-amber-800 border-amber-200",
  vendido: "bg-slate-200 text-slate-700 border-slate-300",
  locado: "bg-blue-100 text-blue-800 border-blue-200",
  inativo: "bg-red-100 text-red-800 border-red-200",
};

export default function ImoveisAdmin() {
  const [items, setItems] = useState<Imovel[]>([]);
  const [loading, setLoading] = useState(true);
  const [busca, setBusca] = useState("");
  const [status, setStatus] = useState("");
  const [finalidade, setFinalidade] = useState("");
  const [tipo, setTipo] = useState("");
  const [total, setTotal] = useState(0);

  async function carregar() {
    setLoading(true);
    try {
      const res = await listarImoveis({
        admin: true,
        busca: busca || undefined,
        status: status || undefined,
        finalidade: finalidade || undefined,
        tipo: tipo || undefined,
        pageSize: 60,
      });
      setItems(res.items);
      setTotal(res.total);
    } catch (e: any) {
      toast.error(e?.message || "Erro ao carregar imóveis");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { carregar(); }, []);

  async function handleExcluir(id: string, titulo: string) {
    if (!confirm(`Excluir o imóvel "${titulo}"? Esta ação não pode ser desfeita.`)) return;
    try {
      await excluirImovel(id);
      toast.success("Imóvel excluído");
      carregar();
    } catch (e: any) {
      toast.error(e?.message || "Erro ao excluir imóvel");
    }
  }

  return (
    <Layout>
      <div className="p-6 max-w-7xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold">Imóveis</h1>
            <p className="text-muted-foreground text-sm">{total} imóvel(is) cadastrado(s)</p>
          </div>
          <Link href="/colaborador/imoveis/novo">
            <Button className="gap-2"><Plus className="size-4" /> Cadastrar imóvel</Button>
          </Link>
        </div>

        <Card className="mb-6">
          <CardContent className="pt-6 flex flex-col md:flex-row gap-2">
            <div className="flex-1 flex items-center gap-2 border rounded-md px-3">
              <Search className="size-4 text-muted-foreground" />
              <Input
                placeholder="Buscar por título, bairro ou código..."
                value={busca}
                onChange={(e) => setBusca(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && carregar()}
                className="border-0 shadow-none focus-visible:ring-0 px-0"
              />
            </div>
            <Select value={status || "todos"} onValueChange={(v) => setStatus(v === "todos" ? "" : v)}>
              <SelectTrigger className="w-full md:w-40"><SelectValue placeholder="Status" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="todos">Todos status</SelectItem>
                {STATUS_IMOVEL.map((s) => <SelectItem key={s.value} value={s.value}>{s.label}</SelectItem>)}
              </SelectContent>
            </Select>
            <Select value={finalidade || "todas"} onValueChange={(v) => setFinalidade(v === "todas" ? "" : v)}>
              <SelectTrigger className="w-full md:w-40"><SelectValue placeholder="Finalidade" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="todas">Todas</SelectItem>
                {FINALIDADES.map((f) => <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>)}
              </SelectContent>
            </Select>
            <Select value={tipo || "todos"} onValueChange={(v) => setTipo(v === "todos" ? "" : v)}>
              <SelectTrigger className="w-full md:w-40"><SelectValue placeholder="Tipo" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="todos">Todos</SelectItem>
                {TIPOS_IMOVEL.map((t) => <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button onClick={carregar}>Filtrar</Button>
          </CardContent>
        </Card>

        {loading && <p className="text-center text-muted-foreground py-10">Carregando...</p>}

        {!loading && items.length === 0 && (
          <p className="text-center text-muted-foreground py-10">Nenhum imóvel encontrado.</p>
        )}

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {items.map((imovel) => (
            <Card key={imovel.id} className="overflow-hidden">
              <div className="relative aspect-[4/3] bg-muted">
                {imovel.foto_capa_url ? (
                  <img src={imovel.foto_capa_url} alt={imovel.titulo} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-muted-foreground text-sm">Sem foto</div>
                )}
                <Badge className={`absolute top-2 right-2 border ${STATUS_COR[imovel.status] || ""}`}>
                  {STATUS_IMOVEL.find((s) => s.value === imovel.status)?.label || imovel.status}
                </Badge>
                {imovel.destaque && (
                  <Badge className="absolute top-2 left-2 bg-amber-600 text-white border-transparent gap-1">
                    <Star className="size-3" /> Destaque
                  </Badge>
                )}
              </div>
              <CardContent className="pt-4">
                <p className="text-xs text-muted-foreground mb-1">{imovel.codigo}</p>
                <h3 className="font-semibold leading-snug line-clamp-2 mb-1">{imovel.titulo}</h3>
                <p className="text-xs text-muted-foreground flex items-center gap-1 mb-2">
                  <MapPin className="size-3" /> {imovel.bairro}, {imovel.cidade}
                </p>
                <div className="flex items-center gap-3 text-xs text-muted-foreground mb-3">
                  {!!imovel.quartos && <span className="flex items-center gap-1"><BedDouble className="size-3.5" />{imovel.quartos}</span>}
                  {!!imovel.banheiros && <span className="flex items-center gap-1"><Bath className="size-3.5" />{imovel.banheiros}</span>}
                  {!!imovel.vagas_garagem && <span className="flex items-center gap-1"><Car className="size-3.5" />{imovel.vagas_garagem}</span>}
                  {!!imovel.area_privativa && <span className="flex items-center gap-1"><Ruler className="size-3.5" />{imovel.area_privativa}m²</span>}
                </div>
                <p className="font-bold text-primary mb-3">
                  {formatarMoeda(imovel.valor_venda ?? imovel.valor_locacao)}
                </p>
                <div className="flex gap-2">
                  <Link href={`/imoveis/${imovel.slug || imovel.id}`} target="_blank" className="flex-1">
                    <Button variant="outline" size="sm" className="w-full gap-1"><Eye className="size-3.5" /> Ver</Button>
                  </Link>
                  <Link href={`/colaborador/imoveis/${imovel.id}/editar`} className="flex-1">
                    <Button variant="outline" size="sm" className="w-full gap-1"><Pencil className="size-3.5" /> Editar</Button>
                  </Link>
                  <Button variant="outline" size="sm" className="text-destructive" onClick={() => handleExcluir(imovel.id, imovel.titulo)}>
                    <Trash2 className="size-3.5" />
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </Layout>
  );
}
