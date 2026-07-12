import { useEffect, useState } from "react";
import { Link, useLocation } from "wouter";
import {
  Search,
  Brain,
  Target,
  Calculator,
  MessageSquare,
  Scale,
  TrendingUp,
  Home,
  FileText,
  BarChart3,
  ArrowRight,
  Sparkles,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useAuth } from "@/hooks/useAuth";
import ProtectedRoute from "@/components/ProtectedRoute";
import { motion } from "framer-motion";

interface DashboardStats {
  lead_scores: { total: number };
  matches: { total: number };
  simulacoes: { total: number };
  analises_juridicas: { total: number; pendentes: number };
  analises_financeiras: { total: number };
  avaliacoes: { total: number };
}

const modules = [
  {
    id: "lead-score",
    title: "Lead Score IA",
    description: "Qualificação automática de leads com análise de renda, perfil e urgência",
    icon: Search,
    href: "/colaborador/ia/lead-score",
    color: "from-emerald-500 to-teal-600",
  },
  {
    id: "match-imovel",
    title: "Match Imóvel",
    description: "Recomendação inteligente de imóveis compatíveis com o perfil do cliente",
    icon: Target,
    href: "/colaborador/ia/match-imovel",
    color: "from-blue-500 to-indigo-600",
  },
  {
    id: "simulador",
    title: "Simulador Multi-Banco",
    description: "Compare financiamentos em Caixa, Itaú, Santander, Bradesco, BB e BRB",
    icon: Calculator,
    href: "/colaborador/ia/simulador-multi-banco",
    color: "from-amber-500 to-orange-600",
  },
  {
    id: "assistente",
    title: "Assistente IA",
    description: "Chat inteligente para orientar compradores, vendedores e corretores",
    icon: MessageSquare,
    href: "/colaborador/ia/assistente",
    color: "from-purple-500 to-violet-600",
  },
  {
    id: "juridica",
    title: "Análise Jurídica",
    description: "Verificação de matrículas, escrituras, certidões, ônus e gravames",
    icon: Scale,
    href: "/colaborador/ia/analise-juridica",
    color: "from-rose-500 to-red-600",
  },
  {
    id: "financeira",
    title: "Análise Financeira",
    description: "Capacidade de compra, comprometimento de renda e risco de aprovação",
    icon: TrendingUp,
    href: "/colaborador/ia/analise-financeira",
    color: "from-cyan-500 to-sky-600",
  },
  {
    id: "avaliacao",
    title: "Avaliação de Imóveis",
    description: "Valor estimado com base em localização, metragem e imóveis comparáveis",
    icon: Home,
    href: "/colaborador/ia/avaliacao-imovel",
    color: "from-pink-500 to-rose-600",
  },
  {
    id: "relatorios",
    title: "Relatórios Inteligentes",
    description: "Dashboards com insights e recomendações gerados por IA",
    icon: BarChart3,
    href: "/colaborador/ia/relatorios",
    color: "from-lime-500 to-green-600",
  },
];

function CentralIAContent() {
  const { user } = useAuth();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/ia/dashboard", {
      headers: {
        Authorization: `Bearer ${localStorage.getItem("destrava_token") || localStorage.getItem("token")}`,
      },
    })
      .then((r) => r.json())
      .then((d) => { setStats(d); setLoading(false); })
      .catch(() => setLoading(false));
  }, []);

  return (
    <div className="min-h-screen bg-gray-50/80">
      {/* Header */}
      <div className="bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900 text-white">
        <div className="container py-8">
          <div className="flex items-center gap-3 mb-2">
            <Brain className="h-8 w-8 text-blue-400" />
            <h1 className="text-2xl font-bold">Central de IA Imobiliária</h1>
          </div>
          <p className="text-slate-300 max-w-2xl">
            Ecossistema inteligente de análise, qualificação e recomendação para gestão imobiliária.
          </p>
        </div>
      </div>

      {/* Stats Bar */}
      <div className="container -mt-4">
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          {[
            { label: "Lead Scores", value: stats?.lead_scores?.total || 0, color: "bg-emerald-500" },
            { label: "Matches", value: stats?.matches?.total || 0, color: "bg-blue-500" },
            { label: "Simulações", value: stats?.simulacoes?.total || 0, color: "bg-amber-500" },
            { label: "Análises Jurídicas", value: stats?.analises_juridicas?.total || 0, color: "bg-rose-500" },
            { label: "Análises Financeiras", value: stats?.analises_financeiras?.total || 0, color: "bg-cyan-500" },
            { label: "Avaliações", value: stats?.avaliacoes?.total || 0, color: "bg-pink-500" },
          ].map((s, i) => (
            <motion.div
              key={s.label}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              className="bg-white rounded-xl p-4 shadow-sm border border-gray-100"
            >
              <div className="flex items-center gap-2">
                <div className={`w-2 h-8 rounded-full ${s.color}`} />
                <div>
                  <p className="text-2xl font-bold text-gray-900">{loading ? "—" : s.value}</p>
                  <p className="text-xs text-gray-500">{s.label}</p>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Alerta de pendências jurídicas */}
      {(stats?.analises_juridicas?.pendentes ?? 0) > 0 && (
        <div className="container mt-6">
          <Card className="border-rose-200 bg-rose-50/50">
            <CardContent className="pt-4 flex items-center gap-3">
              <Scale className="h-5 w-5 text-rose-600" />
              <p className="text-sm text-rose-700">
                <strong>{stats?.analises_juridicas?.pendentes ?? 0}</strong> análise(s) jurídica(s) com necessidade de revisão humana pendente(s).
              </p>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Modules Grid */}
      <div className="container mt-8 pb-12">
        <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Sparkles className="h-5 w-5 text-yellow-500" />
          Módulos de IA
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {modules.map((mod, i) => (
            <motion.div
              key={mod.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 + i * 0.05 }}
            >
              <Link href={mod.href}>
                <Card className="group hover:shadow-lg transition-all duration-200 cursor-pointer border-gray-200 hover:border-gray-300 h-full">
                  <CardContent className="pt-6">
                    <div className={`w-12 h-12 rounded-xl bg-gradient-to-br ${mod.color} flex items-center justify-center mb-4 shadow-sm`}>
                      <mod.icon className="h-6 w-6 text-white" />
                    </div>
                    <h3 className="font-semibold text-gray-900 mb-1 group-hover:text-blue-600 transition-colors">
                      {mod.title}
                    </h3>
                    <p className="text-sm text-gray-500 leading-relaxed">
                      {mod.description}
                    </p>
                    <div className="mt-4 flex items-center text-sm text-blue-600 opacity-0 group-hover:opacity-100 transition-opacity">
                      Acessar
                      <ArrowRight className="h-4 w-4 ml-1" />
                    </div>
                  </CardContent>
                </Card>
              </Link>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function CentralIA() {
  return (
    <ProtectedRoute>
      <CentralIAContent />
    </ProtectedRoute>
  );
}
