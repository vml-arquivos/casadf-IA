import { useEffect, useState } from "react";
import { useRoute, useLocation, Link } from "wouter";
import Layout from "./Layout";
import { toast } from "sonner";
import { ArrowLeft, Save, Upload, Trash2, Star, ImageIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  buscarImovel, criarImovel, atualizarImovel, enviarFotosImovel, excluirFotoImovel,
  definirFotoCapa, Imovel, ImovelFoto, TIPOS_IMOVEL, FINALIDADES, STATUS_IMOVEL,
} from "@/lib/api-imoveis";

const CAMPO_INICIAL: Partial<Imovel> = {
  titulo: "", descricao: "", tipo: "apartamento", finalidade: "venda", status: "disponivel",
  cidade: "Brasília", uf: "DF", quartos: 0, suites: 0, banheiros: 0, vagas_garagem: 0,
  aceita_financiamento: true, aceita_permuta: false, mobiliado: false, destaque: false,
  comodidades: [],
};

export default function ImovelForm() {
  const [, params] = useRoute("/colaborador/imoveis/:id/editar");
  const [, navigate] = useLocation();
  const id = params?.id;
  const isEdit = !!id;

  const [dados, setDados] = useState<Partial<Imovel>>(CAMPO_INICIAL);
  const [fotos, setFotos] = useState<ImovelFoto[]>([]);
  const [comodidadesTexto, setComodidadesTexto] = useState("");
  const [loading, setLoading] = useState(isEdit);
  const [salvando, setSalvando] = useState(false);
  const [enviandoFotos, setEnviandoFotos] = useState(false);

  useEffect(() => {
    if (!isEdit || !id) return;
    buscarImovel(id, true)
      .then((imovel) => {
        setDados(imovel);
        setFotos(imovel.fotos || []);
        setComodidadesTexto((imovel.comodidades || []).join(", "));
      })
      .catch((e) => toast.error(e?.message || "Erro ao carregar imóvel"))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  function set<K extends keyof Imovel>(campo: K, valor: Imovel[K]) {
    setDados((d) => ({ ...d, [campo]: valor }));
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault();
    if (!dados.titulo) {
      toast.error("O título do imóvel é obrigatório.");
      return;
    }
    setSalvando(true);
    try {
      const payload: Partial<Imovel> = {
        ...dados,
        comodidades: comodidadesTexto
          .split(",")
          .map((c) => c.trim())
          .filter(Boolean),
      };
      if (isEdit && id) {
        await atualizarImovel(id, payload);
        toast.success("Imóvel atualizado com sucesso");
      } else {
        const criado = await criarImovel(payload);
        toast.success("Imóvel cadastrado com sucesso");
        navigate(`/colaborador/imoveis/${criado.id}/editar`);
        return;
      }
    } catch (e: any) {
      toast.error(e?.message || "Erro ao salvar imóvel");
    } finally {
      setSalvando(false);
    }
  }

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    if (!id) {
      toast.error("Salve o imóvel antes de enviar fotos.");
      return;
    }
    const files = Array.from(e.target.files || []);
    if (files.length === 0) return;
    setEnviandoFotos(true);
    try {
      const novas = await enviarFotosImovel(id, files);
      setFotos((f) => [...f, ...novas]);
      toast.success(`${novas.length} foto(s) enviada(s)`);
    } catch (err: any) {
      toast.error(err?.message || "Erro ao enviar fotos");
    } finally {
      setEnviandoFotos(false);
      e.target.value = "";
    }
  }

  async function handleExcluirFoto(fotoId: string) {
    if (!id) return;
    try {
      await excluirFotoImovel(id, fotoId);
      setFotos((f) => f.filter((foto) => foto.id !== fotoId));
    } catch (e: any) {
      toast.error(e?.message || "Erro ao excluir foto");
    }
  }

  async function handleDefinirCapa(fotoId: string) {
    if (!id) return;
    try {
      await definirFotoCapa(id, fotoId);
      setFotos((f) => f.map((foto) => ({ ...foto, capa: foto.id === fotoId })));
      toast.success("Foto de capa atualizada");
    } catch (e: any) {
      toast.error(e?.message || "Erro ao definir capa");
    }
  }

  if (loading) {
    return <Layout><div className="p-6 text-center text-muted-foreground">Carregando imóvel...</div></Layout>;
  }

  return (
    <Layout>
      <div className="p-6 max-w-4xl mx-auto">
        <Link href="/colaborador/imoveis" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-4">
          <ArrowLeft className="size-4" /> Voltar para imóveis
        </Link>
        <h1 className="text-2xl font-bold mb-6">{isEdit ? `Editar imóvel ${dados.codigo || ""}` : "Cadastrar novo imóvel"}</h1>

        <form onSubmit={salvar} className="flex flex-col gap-6">
          <Card>
            <CardHeader><CardTitle>Informações principais</CardTitle></CardHeader>
            <CardContent className="grid md:grid-cols-2 gap-4">
              <div className="md:col-span-2">
                <Label>Título do anúncio *</Label>
                <Input value={dados.titulo || ""} onChange={(e) => set("titulo", e.target.value)} required />
              </div>
              <div className="md:col-span-2">
                <Label>Descrição</Label>
                <Textarea rows={4} value={dados.descricao || ""} onChange={(e) => set("descricao", e.target.value)} />
              </div>
              <div>
                <Label>Tipo</Label>
                <Select value={dados.tipo || "apartamento"} onValueChange={(v) => set("tipo", v as any)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{TIPOS_IMOVEL.map((t) => <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div>
                <Label>Finalidade</Label>
                <Select value={dados.finalidade || "venda"} onValueChange={(v) => set("finalidade", v as any)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{FINALIDADES.map((f) => <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div>
                <Label>Status</Label>
                <Select value={dados.status || "disponivel"} onValueChange={(v) => set("status", v as any)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{STATUS_IMOVEL.map((s) => <SelectItem key={s.value} value={s.value}>{s.label}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="flex items-center gap-2 pt-6">
                <Switch checked={!!dados.destaque} onCheckedChange={(v) => set("destaque", v)} />
                <Label>Destacar na vitrine</Label>
              </div>
              <div className="md:col-span-2">
                <Label>Vídeo do imóvel (link YouTube/Vimeo, opcional)</Label>
                <Input placeholder="https://www.youtube.com/watch?v=..." value={dados.video_url || ""} onChange={(e) => set("video_url", e.target.value)} />
              </div>
              <div className="md:col-span-2">
                <Label>Tour virtual 360° (link, opcional)</Label>
                <Input placeholder="https://..." value={dados.tour_virtual_url || ""} onChange={(e) => set("tour_virtual_url", e.target.value)} />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle>Valores</CardTitle></CardHeader>
            <CardContent className="grid md:grid-cols-2 gap-4">
              <div>
                <Label>Valor de venda (R$)</Label>
                <Input type="number" step="0.01" value={dados.valor_venda ?? ""} onChange={(e) => set("valor_venda", e.target.value ? Number(e.target.value) : null as any)} />
              </div>
              <div>
                <Label>Valor de locação (R$/mês)</Label>
                <Input type="number" step="0.01" value={dados.valor_locacao ?? ""} onChange={(e) => set("valor_locacao", e.target.value ? Number(e.target.value) : null as any)} />
              </div>
              <div>
                <Label>Condomínio (R$)</Label>
                <Input type="number" step="0.01" value={dados.valor_condominio ?? ""} onChange={(e) => set("valor_condominio", e.target.value ? Number(e.target.value) : null as any)} />
              </div>
              <div>
                <Label>IPTU (R$)</Label>
                <Input type="number" step="0.01" value={dados.valor_iptu ?? ""} onChange={(e) => set("valor_iptu", e.target.value ? Number(e.target.value) : null as any)} />
              </div>
              <div className="flex items-center gap-2">
                <Switch checked={!!dados.aceita_financiamento} onCheckedChange={(v) => set("aceita_financiamento", v)} />
                <Label>Aceita financiamento</Label>
              </div>
              <div className="flex items-center gap-2">
                <Switch checked={!!dados.aceita_permuta} onCheckedChange={(v) => set("aceita_permuta", v)} />
                <Label>Aceita permuta</Label>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle>Localização</CardTitle></CardHeader>
            <CardContent className="grid md:grid-cols-3 gap-4">
              <div className="md:col-span-2">
                <Label>Endereço</Label>
                <Input value={dados.endereco || ""} onChange={(e) => set("endereco", e.target.value)} />
              </div>
              <div>
                <Label>Número</Label>
                <Input value={dados.numero || ""} onChange={(e) => set("numero", e.target.value)} />
              </div>
              <div>
                <Label>Complemento</Label>
                <Input value={dados.complemento || ""} onChange={(e) => set("complemento", e.target.value)} />
              </div>
              <div>
                <Label>Bairro</Label>
                <Input value={dados.bairro || ""} onChange={(e) => set("bairro", e.target.value)} />
              </div>
              <div>
                <Label>CEP</Label>
                <Input value={dados.cep || ""} onChange={(e) => set("cep", e.target.value)} />
              </div>
              <div>
                <Label>Cidade</Label>
                <Input value={dados.cidade || ""} onChange={(e) => set("cidade", e.target.value)} />
              </div>
              <div>
                <Label>UF</Label>
                <Input maxLength={2} value={dados.uf || ""} onChange={(e) => set("uf", e.target.value.toUpperCase())} />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle>Características</CardTitle></CardHeader>
            <CardContent className="grid md:grid-cols-4 gap-4">
              <div>
                <Label>Área privativa (m²)</Label>
                <Input type="number" step="0.01" value={dados.area_privativa ?? ""} onChange={(e) => set("area_privativa", e.target.value ? Number(e.target.value) : null as any)} />
              </div>
              <div>
                <Label>Área total (m²)</Label>
                <Input type="number" step="0.01" value={dados.area_total ?? ""} onChange={(e) => set("area_total", e.target.value ? Number(e.target.value) : null as any)} />
              </div>
              <div>
                <Label>Quartos</Label>
                <Input type="number" value={dados.quartos ?? 0} onChange={(e) => set("quartos", Number(e.target.value))} />
              </div>
              <div>
                <Label>Suítes</Label>
                <Input type="number" value={dados.suites ?? 0} onChange={(e) => set("suites", Number(e.target.value))} />
              </div>
              <div>
                <Label>Banheiros</Label>
                <Input type="number" value={dados.banheiros ?? 0} onChange={(e) => set("banheiros", Number(e.target.value))} />
              </div>
              <div>
                <Label>Vagas de garagem</Label>
                <Input type="number" value={dados.vagas_garagem ?? 0} onChange={(e) => set("vagas_garagem", Number(e.target.value))} />
              </div>
              <div>
                <Label>Andar</Label>
                <Input value={dados.andar || ""} onChange={(e) => set("andar", e.target.value)} />
              </div>
              <div>
                <Label>Ano de construção</Label>
                <Input type="number" value={dados.ano_construcao ?? ""} onChange={(e) => set("ano_construcao", e.target.value ? Number(e.target.value) : null as any)} />
              </div>
              <div className="flex items-center gap-2">
                <Switch checked={!!dados.mobiliado} onCheckedChange={(v) => set("mobiliado", v)} />
                <Label>Mobiliado</Label>
              </div>
              <div className="md:col-span-4">
                <Label>Comodidades (separadas por vírgula)</Label>
                <Input
                  placeholder="piscina, academia, churrasqueira, portaria 24h..."
                  value={comodidadesTexto}
                  onChange={(e) => setComodidadesTexto(e.target.value)}
                />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle>Proprietário e uso interno</CardTitle></CardHeader>
            <CardContent className="grid md:grid-cols-2 gap-4">
              <div>
                <Label>Nome do proprietário</Label>
                <Input value={dados.proprietario_nome || ""} onChange={(e) => set("proprietario_nome", e.target.value)} />
              </div>
              <div>
                <Label>Telefone do proprietário</Label>
                <Input value={dados.proprietario_telefone || ""} onChange={(e) => set("proprietario_telefone", e.target.value)} />
              </div>
              <div>
                <Label>E-mail do proprietário</Label>
                <Input value={dados.proprietario_email || ""} onChange={(e) => set("proprietario_email", e.target.value)} />
              </div>
              <div>
                <Label>CPF/CNPJ do proprietário</Label>
                <Input value={dados.proprietario_cpf_cnpj || ""} onChange={(e) => set("proprietario_cpf_cnpj", e.target.value)} />
              </div>
              <div>
                <Label>Matrícula do imóvel</Label>
                <Input value={dados.matricula_imovel || ""} onChange={(e) => set("matricula_imovel", e.target.value)} />
              </div>
              <div className="md:col-span-2">
                <Label>Observações internas (não aparece no site)</Label>
                <Textarea rows={3} value={dados.observacoes_internas || ""} onChange={(e) => set("observacoes_internas", e.target.value)} />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle>Fotos</CardTitle></CardHeader>
            <CardContent>
              {!isEdit && (
                <p className="text-sm text-muted-foreground mb-3">Salve o imóvel primeiro para poder enviar fotos.</p>
              )}
              {isEdit && (
                <>
                  <label className="inline-flex items-center gap-2 border rounded-md px-4 py-2 cursor-pointer hover:bg-muted mb-4 text-sm">
                    <Upload className="size-4" />
                    {enviandoFotos ? "Enviando..." : "Enviar fotos"}
                    <input type="file" accept="image/*" multiple hidden onChange={handleUpload} disabled={enviandoFotos} />
                  </label>
                  {fotos.length === 0 ? (
                    <p className="text-sm text-muted-foreground flex items-center gap-2"><ImageIcon className="size-4" /> Nenhuma foto enviada ainda.</p>
                  ) : (
                    <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3">
                      {fotos.map((foto) => (
                        <div key={foto.id} className="relative group">
                          <img src={foto.url} alt="" className="w-full aspect-square object-cover rounded border" />
                          {foto.capa && <Badge className="absolute top-1 left-1 bg-amber-600 text-white border-transparent text-[10px] px-1">Capa</Badge>}
                          <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex items-center justify-center gap-1 rounded transition-opacity">
                            {!foto.capa && (
                              <button type="button" onClick={() => handleDefinirCapa(foto.id)} title="Definir como capa" className="bg-white rounded-full p-1.5">
                                <Star className="size-3.5 text-amber-600" />
                              </button>
                            )}
                            <button type="button" onClick={() => handleExcluirFoto(foto.id)} title="Excluir" className="bg-white rounded-full p-1.5">
                              <Trash2 className="size-3.5 text-destructive" />
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </>
              )}
            </CardContent>
          </Card>

          <div className="flex justify-end gap-2">
            <Link href="/colaborador/imoveis"><Button type="button" variant="outline">Cancelar</Button></Link>
            <Button type="submit" disabled={salvando} className="gap-2">
              <Save className="size-4" /> {salvando ? "Salvando..." : "Salvar imóvel"}
            </Button>
          </div>
        </form>
      </div>
    </Layout>
  );
}
