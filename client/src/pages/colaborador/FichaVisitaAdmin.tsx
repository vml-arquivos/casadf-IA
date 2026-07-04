import { useEffect, useState } from "react";
import Layout from "./Layout";
import { toast } from "sonner";
import { FileDown, Phone, Mail, Calendar } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  listarVisitas, atualizarVisita, urlPdfVisita, ImovelVisita,
} from "@/lib/api-imoveis";
import { getToken } from "@/lib/api";

const STATUS_LABEL: Record<string, string> = {
  agendada: "Agendada",
  realizada: "Realizada",
  cancelada: "Cancelada",
  nao_compareceu: "Não compareceu",
};

const STATUS_COR: Record<string, string> = {
  agendada: "bg-blue-100 text-blue-800 border-blue-200",
  realizada: "bg-emerald-100 text-emerald-800 border-emerald-200",
  cancelada: "bg-red-100 text-red-800 border-red-200",
  nao_compareceu: "bg-slate-200 text-slate-700 border-slate-300",
};

function formatarData(d: string) {
  const dt = new Date(d);
  if (Number.isNaN(dt.getTime())) return "—";
  return dt.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}

export default function FichaVisitaAdmin() {
  const [visitas, setVisitas] = useState<ImovelVisita[]>([]);
  const [loading, setLoading] = useState(true);
  const [filtroStatus, setFiltroStatus] = useState("");
  const [feedbackEditando, setFeedbackEditando] = useState<Record<string, string>>({});

  async function carregar() {
    setLoading(true);
    try {
      const res = await listarVisitas({ status: filtroStatus || undefined, pageSize: 50 });
      setVisitas(res.items);
    } catch (e: any) {
      toast.error(e?.message || "Erro ao carregar visitas");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { carregar(); }, [filtroStatus]);

  async function mudarStatus(id: string, status: string) {
    try {
      await atualizarVisita(id, { status });
      setVisitas((v) => v.map((item) => (item.id === id ? { ...item, status } : item)));
      toast.success("Status atualizado");
    } catch (e: any) {
      toast.error(e?.message || "Erro ao atualizar status");
    }
  }

  async function salvarFeedback(id: string) {
    const feedback = feedbackEditando[id];
    if (feedback === undefined) return;
    try {
      await atualizarVisita(id, { feedback_visitante: feedback });
      toast.success("Feedback salvo");
    } catch (e: any) {
      toast.error(e?.message || "Erro ao salvar feedback");
    }
  }

  async function baixarPdf(id: string) {
    try {
      const res = await fetch(urlPdfVisita(id), {
        headers: { Authorization: `Bearer ${getToken()}` },
      });
      if (!res.ok) throw new Error("Erro ao gerar PDF");
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      window.open(url, "_blank");
    } catch (e: any) {
      toast.error(e?.message || "Erro ao gerar PDF da ficha de visita");
    }
  }

  return (
    <Layout>
      <div className="p-6 max-w-5xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold">Fichas de Visita</h1>
            <p className="text-muted-foreground text-sm">
              Visitas agendadas ou realizadas — feedback e geração de PDF para assinatura.
            </p>
          </div>
          <Select value={filtroStatus || "todas"} onValueChange={(v) => setFiltroStatus(v === "todas" ? "" : v)}>
            <SelectTrigger className="w-48"><SelectValue placeholder="Status" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="todas">Todas</SelectItem>
              {Object.entries(STATUS_LABEL).map(([v, l]) => <SelectItem key={v} value={v}>{l}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>

        {loading && <p className="text-center text-muted-foreground py-10">Carregando...</p>}
        {!loading && visitas.length === 0 && (
          <p className="text-center text-muted-foreground py-10">
            Nenhuma visita registrada. As solicitações feitas pelo site aparecem aqui automaticamente.
          </p>
        )}

        <div className="flex flex-col gap-4">
          {visitas.map((v) => (
            <Card key={v.id}>
              <CardContent className="pt-6">
                <div className="flex flex-wrap items-start justify-between gap-2 mb-3">
                  <div>
                    <p className="text-xs text-muted-foreground">{v.imovel_codigo} — {v.imovel_titulo}</p>
                    <h3 className="font-semibold text-lg">{v.visitante_nome}</h3>
                    <div className="flex flex-wrap gap-3 text-sm text-muted-foreground mt-1">
                      {v.visitante_telefone && <span className="flex items-center gap-1"><Phone className="size-3.5" />{v.visitante_telefone}</span>}
                      {v.visitante_email && <span className="flex items-center gap-1"><Mail className="size-3.5" />{v.visitante_email}</span>}
                      <span className="flex items-center gap-1"><Calendar className="size-3.5" />{formatarData(v.data_visita)}</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge className={`border ${STATUS_COR[v.status] || ""}`}>{STATUS_LABEL[v.status] || v.status}</Badge>
                    <Select value={v.status} onValueChange={(s) => mudarStatus(v.id, s)}>
                      <SelectTrigger className="w-40 h-8 text-xs"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {Object.entries(STATUS_LABEL).map(([val, l]) => <SelectItem key={val} value={val}>{l}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                {v.observacoes && (
                  <p className="text-sm text-muted-foreground mb-2"><strong>Observações:</strong> {v.observacoes}</p>
                )}

                <div className="mb-3">
                  <Textarea
                    placeholder="Feedback do visitante após a visita..."
                    rows={2}
                    value={feedbackEditando[v.id] ?? v.feedback_visitante ?? ""}
                    onChange={(e) => setFeedbackEditando((f) => ({ ...f, [v.id]: e.target.value }))}
                  />
                </div>

                <div className="flex gap-2">
                  <Button size="sm" variant="outline" onClick={() => salvarFeedback(v.id)}>Salvar feedback</Button>
                  <Button size="sm" variant="outline" className="gap-1" onClick={() => baixarPdf(v.id)}>
                    <FileDown className="size-3.5" /> Gerar ficha em PDF
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
