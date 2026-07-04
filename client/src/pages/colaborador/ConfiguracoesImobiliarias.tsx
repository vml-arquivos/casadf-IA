import { useEffect, useState } from "react";
import Layout from "./Layout";
import { toast } from "sonner";
import { Plus, Upload, Star, Trash2, Building2, UserRound } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  listarImobiliarias, criarImobiliaria, atualizarImobiliaria, excluirImobiliaria,
  definirImobiliariaPadrao, enviarLogoImobiliaria, Imobiliaria,
  listarCorretores, criarCorretor, atualizarCorretor, excluirCorretor, enviarFotoCorretor, Corretor,
} from "@/lib/api-imoveis";

const IMOBILIARIA_VAZIA: Partial<Imobiliaria> = { nome: "", cidade: "Brasília", uf: "DF", cor_primaria: "#b45309", ativa: true };
const CORRETOR_VAZIO: Partial<Corretor> = { nome: "", ativo: true };

function AbaImobiliarias() {
  const [lista, setLista] = useState<Imobiliaria[]>([]);
  const [loading, setLoading] = useState(true);
  const [mostrarForm, setMostrarForm] = useState(false);
  const [dados, setDados] = useState<Partial<Imobiliaria>>(IMOBILIARIA_VAZIA);
  const [salvando, setSalvando] = useState(false);

  async function carregar() {
    setLoading(true);
    try { setLista(await listarImobiliarias()); }
    catch (e: any) { toast.error(e?.message || "Erro ao carregar imobiliárias"); }
    finally { setLoading(false); }
  }
  useEffect(() => { carregar(); }, []);

  async function salvar(e: React.FormEvent) {
    e.preventDefault();
    if (!dados.nome) { toast.error("Nome é obrigatório"); return; }
    setSalvando(true);
    try {
      await criarImobiliaria(dados);
      toast.success("Imobiliária cadastrada");
      setMostrarForm(false);
      setDados(IMOBILIARIA_VAZIA);
      carregar();
    } catch (e: any) {
      toast.error(e?.message || "Erro ao cadastrar imobiliária");
    } finally {
      setSalvando(false);
    }
  }

  async function handleLogo(id: string, file: File) {
    try {
      await enviarLogoImobiliaria(id, file);
      toast.success("Logo atualizada");
      carregar();
    } catch (e: any) {
      toast.error(e?.message || "Erro ao enviar logo");
    }
  }

  async function handlePadrao(id: string) {
    try { await definirImobiliariaPadrao(id); toast.success("Imobiliária padrão definida"); carregar(); }
    catch (e: any) { toast.error(e?.message || "Erro ao definir padrão"); }
  }

  async function handleRodape(id: string, rodape_texto: string) {
    try { await atualizarImobiliaria(id, { rodape_texto }); toast.success("Rodapé salvo"); }
    catch (e: any) { toast.error(e?.message || "Erro ao salvar rodapé"); }
  }

  async function handleExcluir(id: string) {
    if (!confirm("Excluir esta imobiliária?")) return;
    try { await excluirImobiliaria(id); carregar(); }
    catch (e: any) { toast.error(e?.message || "Não é possível excluir esta imobiliária"); }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex justify-between items-center">
        <p className="text-sm text-muted-foreground max-w-2xl">
          Cadastre aqui outras imobiliárias parceiras. Por enquanto, os contratos e fichas em PDF são sempre
          gerados no papel timbrado da Casa DF — o logo e rodapé configurados aqui servem para identificação
          interna e para uso futuro em documentos por imobiliária.
        </p>
        {!mostrarForm && <Button size="sm" className="gap-1" onClick={() => setMostrarForm(true)}><Plus className="size-4" /> Nova imobiliária</Button>}
      </div>

      {mostrarForm && (
        <Card>
          <CardHeader><CardTitle>Nova imobiliária</CardTitle></CardHeader>
          <CardContent>
            <form onSubmit={salvar} className="grid md:grid-cols-2 gap-3">
              <Input placeholder="Nome *" value={dados.nome || ""} onChange={(e) => setDados((d) => ({ ...d, nome: e.target.value }))} required />
              <Input placeholder="CNPJ" value={dados.cnpj || ""} onChange={(e) => setDados((d) => ({ ...d, cnpj: e.target.value }))} />
              <Input placeholder="CRECI Jurídico" value={dados.creci_juridico || ""} onChange={(e) => setDados((d) => ({ ...d, creci_juridico: e.target.value }))} />
              <Input placeholder="Telefone" value={dados.telefone || ""} onChange={(e) => setDados((d) => ({ ...d, telefone: e.target.value }))} />
              <Input placeholder="E-mail" value={dados.email || ""} onChange={(e) => setDados((d) => ({ ...d, email: e.target.value }))} />
              <Input placeholder="Site" value={dados.site_url || ""} onChange={(e) => setDados((d) => ({ ...d, site_url: e.target.value }))} />
              <Input className="md:col-span-2" placeholder="Endereço" value={dados.endereco || ""} onChange={(e) => setDados((d) => ({ ...d, endereco: e.target.value }))} />
              <div className="md:col-span-2 flex justify-end gap-2">
                <Button type="button" variant="outline" onClick={() => setMostrarForm(false)}>Cancelar</Button>
                <Button type="submit" disabled={salvando}>{salvando ? "Salvando..." : "Cadastrar"}</Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {loading && <p className="text-center text-muted-foreground py-6">Carregando...</p>}

      <div className="grid md:grid-cols-2 gap-4">
        {lista.map((im) => (
          <Card key={im.id}>
            <CardContent className="pt-6 flex flex-col gap-3">
              <div className="flex items-center gap-3">
                <div className="w-16 h-16 rounded border bg-muted flex items-center justify-center overflow-hidden shrink-0">
                  {im.logo_url ? <img src={im.logo_url} alt={im.nome} className="w-full h-full object-contain" /> : <Building2 className="size-6 text-muted-foreground" />}
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h3 className="font-semibold">{im.nome}</h3>
                    {im.padrao && <Badge className="bg-amber-600 text-white border-transparent text-[10px]">Padrão</Badge>}
                  </div>
                  <p className="text-xs text-muted-foreground">{im.cnpj || "CNPJ não informado"}</p>
                </div>
                <Button variant="outline" size="sm" className="text-destructive" onClick={() => handleExcluir(im.id)} disabled={im.padrao}>
                  <Trash2 className="size-3.5" />
                </Button>
              </div>

              <label className="inline-flex items-center gap-2 border rounded-md px-3 py-1.5 cursor-pointer hover:bg-muted text-xs w-fit">
                <Upload className="size-3.5" /> Enviar logo
                <input type="file" accept="image/*" hidden onChange={(e) => e.target.files?.[0] && handleLogo(im.id, e.target.files[0])} />
              </label>

              <div>
                <Label className="text-xs">Texto de rodapé (documentos)</Label>
                <Textarea
                  rows={2}
                  defaultValue={im.rodape_texto || ""}
                  onBlur={(e) => handleRodape(im.id, e.target.value)}
                  placeholder="Ex: Casa DF — Gestão Imobiliária · CRECI-DF 00000-J · casadf.com.br"
                />
              </div>

              {!im.padrao && (
                <Button size="sm" variant="outline" className="gap-1 w-fit" onClick={() => handlePadrao(im.id)}>
                  <Star className="size-3.5" /> Definir como padrão
                </Button>
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

function AbaCorretores() {
  const [lista, setLista] = useState<Corretor[]>([]);
  const [loading, setLoading] = useState(true);
  const [mostrarForm, setMostrarForm] = useState(false);
  const [dados, setDados] = useState<Partial<Corretor>>(CORRETOR_VAZIO);
  const [salvando, setSalvando] = useState(false);

  async function carregar() {
    setLoading(true);
    try { setLista(await listarCorretores()); }
    catch (e: any) { toast.error(e?.message || "Erro ao carregar corretores"); }
    finally { setLoading(false); }
  }
  useEffect(() => { carregar(); }, []);

  async function salvar(e: React.FormEvent) {
    e.preventDefault();
    if (!dados.nome) { toast.error("Nome é obrigatório"); return; }
    setSalvando(true);
    try {
      await criarCorretor(dados);
      toast.success("Corretor(a) cadastrado(a)");
      setMostrarForm(false);
      setDados(CORRETOR_VAZIO);
      carregar();
    } catch (e: any) {
      toast.error(e?.message || "Erro ao cadastrar corretor(a)");
    } finally {
      setSalvando(false);
    }
  }

  async function handleFoto(id: string, file: File) {
    try { await enviarFotoCorretor(id, file); toast.success("Foto atualizada"); carregar(); }
    catch (e: any) { toast.error(e?.message || "Erro ao enviar foto"); }
  }

  async function handleAtivo(id: string, ativo: boolean) {
    try { await atualizarCorretor(id, { ativo }); carregar(); }
    catch (e: any) { toast.error(e?.message || "Erro ao atualizar"); }
  }

  async function handleExcluir(id: string) {
    if (!confirm("Excluir este(a) corretor(a)?")) return;
    try { await excluirCorretor(id); carregar(); }
    catch (e: any) { toast.error(e?.message || "Erro ao excluir"); }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex justify-between items-center">
        <p className="text-sm text-muted-foreground">Cadastre corretores para vincular aos imóveis e contratos.</p>
        {!mostrarForm && <Button size="sm" className="gap-1" onClick={() => setMostrarForm(true)}><Plus className="size-4" /> Novo(a) corretor(a)</Button>}
      </div>

      {mostrarForm && (
        <Card>
          <CardHeader><CardTitle>Novo(a) corretor(a)</CardTitle></CardHeader>
          <CardContent>
            <form onSubmit={salvar} className="grid md:grid-cols-2 gap-3">
              <Input placeholder="Nome completo *" value={dados.nome || ""} onChange={(e) => setDados((d) => ({ ...d, nome: e.target.value }))} required />
              <Input placeholder="CRECI" value={dados.creci || ""} onChange={(e) => setDados((d) => ({ ...d, creci: e.target.value }))} />
              <Input placeholder="Telefone/WhatsApp" value={dados.whatsapp || ""} onChange={(e) => setDados((d) => ({ ...d, whatsapp: e.target.value }))} />
              <Input placeholder="E-mail" value={dados.email || ""} onChange={(e) => setDados((d) => ({ ...d, email: e.target.value }))} />
              <div className="md:col-span-2 flex justify-end gap-2">
                <Button type="button" variant="outline" onClick={() => setMostrarForm(false)}>Cancelar</Button>
                <Button type="submit" disabled={salvando}>{salvando ? "Salvando..." : "Cadastrar"}</Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {loading && <p className="text-center text-muted-foreground py-6">Carregando...</p>}

      <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-4">
        {lista.map((c) => (
          <Card key={c.id}>
            <CardContent className="pt-6 flex flex-col items-center gap-2 text-center">
              <div className="w-16 h-16 rounded-full border bg-muted flex items-center justify-center overflow-hidden">
                {c.foto_url ? <img src={c.foto_url} alt={c.nome} className="w-full h-full object-cover" /> : <UserRound className="size-6 text-muted-foreground" />}
              </div>
              <h3 className="font-semibold">{c.nome}</h3>
              {c.creci && <p className="text-xs text-muted-foreground">CRECI {c.creci}</p>}
              <label className="inline-flex items-center gap-1 border rounded-md px-2 py-1 cursor-pointer hover:bg-muted text-xs">
                <Upload className="size-3" /> Foto
                <input type="file" accept="image/*" hidden onChange={(e) => e.target.files?.[0] && handleFoto(c.id, e.target.files[0])} />
              </label>
              <div className="flex gap-2 mt-1">
                <Button size="sm" variant="outline" onClick={() => handleAtivo(c.id, !c.ativo)}>{c.ativo ? "Desativar" : "Ativar"}</Button>
                <Button size="sm" variant="outline" className="text-destructive" onClick={() => handleExcluir(c.id)}><Trash2 className="size-3.5" /></Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

export default function ConfiguracoesImobiliarias() {
  return (
    <Layout>
      <div className="p-6 max-w-5xl mx-auto">
        <h1 className="text-2xl font-bold mb-1">Configurações — Imobiliárias e Corretores</h1>
        <p className="text-muted-foreground text-sm mb-6">
          Gerencie imobiliárias parceiras, logos, rodapés de documentos e a equipe de corretores.
        </p>
        <Tabs defaultValue="imobiliarias">
          <TabsList>
            <TabsTrigger value="imobiliarias">Imobiliárias</TabsTrigger>
            <TabsTrigger value="corretores">Corretores</TabsTrigger>
          </TabsList>
          <TabsContent value="imobiliarias" className="pt-4"><AbaImobiliarias /></TabsContent>
          <TabsContent value="corretores" className="pt-4"><AbaCorretores /></TabsContent>
        </Tabs>
      </div>
    </Layout>
  );
}
