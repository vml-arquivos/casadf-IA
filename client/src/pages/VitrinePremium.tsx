import { useState, useEffect } from "react";
import { Link } from "wouter";
import { Star, MapPin, Bed, Maximize2, Bath, Car, Building2, ArrowRight, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import { listarImoveis, formatarMoeda } from "@/lib/api-imoveis";
import { motion } from "framer-motion";

export default function VitrinePremium() {
  const [imoveis, setImoveis] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    listarImoveis({ destaque: true, page: 1, pageSize: 12, status: "disponivel" })
      .then((d) => { setImoveis(d.items || []); setLoading(false); })
      .catch(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <>
        <Header />
        <div className="min-h-[50vh] flex items-center justify-center">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-blue-600 border-t-transparent" />
        </div>
        <Footer />
      </>
    );
  }

  return (
    <>
      <Header />

      {/* Hero */}
      <section className="bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 text-white">
        <div className="container py-16">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="text-center"
          >
            <div className="flex items-center justify-center gap-2 mb-4">
              <Sparkles className="h-6 w-6 text-yellow-400" />
              <span className="text-yellow-400 text-sm font-semibold uppercase tracking-widest">Exclusivo</span>
              <Sparkles className="h-6 w-6 text-yellow-400" />
            </div>
            <h1 className="text-4xl md:text-5xl font-bold mb-4">
              Vitrine Premium
            </h1>
            <p className="text-slate-300 max-w-2xl mx-auto text-lg">
              Imóveis selecionados com os melhores padrões de localização, acabamento e potencial de valorização.
              Cada propriedade passa por avaliação IA para garantir excelência.
            </p>
          </motion.div>
        </div>
      </section>

      {/* Stats */}
      <section className="bg-white border-b">
        <div className="container py-6">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
            {[
              { label: "Imóveis Premium", value: imoveis.length.toString(), color: "text-blue-600" },
              { label: "Valor médio", value: formatarMoeda(imoveis.reduce((acc, im) => acc + (im.valor_venda || im.valor_locacao || 0), 0) / Math.max(imoveis.length, 1)), color: "text-emerald-600" },
              { label: "Valor máximo", value: formatarMoeda(Math.max(...imoveis.map((im) => im.valor_venda || im.valor_locacao || 0))), color: "text-purple-600" },
              { label: "Bairros", value: [...new Set(imoveis.map((im) => im.bairro).filter(Boolean))].length.toString(), color: "text-amber-600" },
            ].map((s) => (
              <div key={s.label}>
                <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
                <p className="text-xs text-gray-500">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Imóveis */}
      <section className="bg-gray-50/80 py-12">
        <div className="container">
          {imoveis.length === 0 ? (
            <div className="text-center py-16 text-gray-400">
              <Star className="h-16 w-16 mx-auto mb-4 opacity-30" />
              <p className="text-lg">Nenhum imóvel premium disponível no momento.</p>
              <Link href="/imoveis">
                <Button className="mt-4 bg-blue-600 hover:bg-blue-700">
                  Ver todos os imóveis
                </Button>
              </Link>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {imoveis.map((im, i) => (
                <motion.div
                  key={im.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.05 }}
                >
                  <Link href={`/imoveis/${im.id}`}>
                    <Card className="group overflow-hidden hover:shadow-xl transition-all duration-300 border-gray-200">
                      <div className="relative">
                        {im.foto_capa_url ? (
                          <img
                            src={im.foto_capa_url}
                            alt={im.titulo}
                            className="w-full h-56 object-cover group-hover:scale-105 transition-transform duration-500"
                          />
                        ) : (
                          <div className="w-full h-56 bg-gradient-to-br from-gray-200 to-gray-300 flex items-center justify-center">
                            <Building2 className="h-16 w-16 text-gray-400" />
                          </div>
                        )}
                        {/* Badge Premium */}
                        <div className="absolute top-3 left-3 flex gap-2">
                          <span className="bg-yellow-400 text-yellow-900 text-xs font-bold px-2.5 py-1 rounded-lg flex items-center gap-1 shadow-sm">
                            <Star className="h-3 w-3" /> Premium
                          </span>
                          <span className="bg-white/90 text-gray-700 text-xs px-2.5 py-1 rounded-lg">
                            {im.tipo}
                          </span>
                        </div>
                        {/* Destaque badge */}
                        {im.destaque && (
                          <div className="absolute top-3 right-3 bg-blue-600 text-white text-xs font-bold px-2.5 py-1 rounded-lg shadow-sm">
                            Destaque
                          </div>
                        )}
                      </div>
                      <CardContent className="pt-4">
                        <h3 className="font-bold text-gray-900 group-hover:text-blue-600 transition-colors line-clamp-2">
                          {im.titulo}
                        </h3>
                        <p className="flex items-center gap-1 text-sm text-gray-500 mt-1">
                          <MapPin className="h-3.5 w-3.5" /> {im.bairro}, {im.cidade}
                        </p>
                        <p className="text-2xl font-bold text-gray-900 mt-3">
                          {formatarMoeda(im.valor_venda || im.valor_locacao)}
                        </p>
                        <div className="flex flex-wrap gap-3 mt-3 text-xs text-gray-500 border-t pt-3">
                          {im.area_privativa && (
                            <span className="flex items-center gap-1">
                              <Maximize2 className="h-3.5 w-3.5" /> {im.area_privativa}m²
                            </span>
                          )}
                          {im.quartos && (
                            <span className="flex items-center gap-1">
                              <Bed className="h-3.5 w-3.5" /> {im.quartos}
                            </span>
                          )}
                          {im.banheiros && (
                            <span className="flex items-center gap-1">
                              <Bath className="h-3.5 w-3.5" /> {im.banheiros}
                            </span>
                          )}
                          {im.vagas_garagem && (
                            <span className="flex items-center gap-1">
                              <Car className="h-3.5 w-3.5" /> {im.vagas_garagem}
                            </span>
                          )}
                        </div>
                        <div className="mt-3 flex items-center text-blue-600 text-sm opacity-0 group-hover:opacity-100 transition-opacity">
                          Ver detalhes
                          <ArrowRight className="h-4 w-4 ml-1" />
                        </div>
                      </CardContent>
                    </Card>
                  </Link>
                </motion.div>
              ))}
            </div>
          )}

          {/* CTA */}
          <div className="mt-12 text-center">
            <p className="text-gray-500 mb-4">Não encontrou o que procura?</p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
              <Link href="/imoveis">
                <Button variant="outline" className="border-gray-300">
                  Ver catálogo completo
                </Button>
              </Link>
              <Link href="/contato">
                <Button className="bg-blue-600 hover:bg-blue-700">
                  Fale com um especialista
                </Button>
              </Link>
              <Link href="/simulador">
                <Button variant="outline" className="border-blue-300 text-blue-700 hover:bg-blue-50">
                  Simule seu crédito
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Seção Assistente IA */}
      <section className="bg-white py-12">
        <div className="container">
          <div className="max-w-2xl mx-auto text-center">
            <Sparkles className="h-8 w-8 text-purple-500 mx-auto mb-3" />
            <h2 className="text-2xl font-bold text-gray-900 mb-3">
              Precisa de ajuda para encontrar o imóvel ideal?
            </h2>
            <p className="text-gray-500 mb-6">
              Nosso assistente de IA pode ajudá-lo a encontrar o imóvel perfeito baseado no seu perfil, orçamento e preferências.
            </p>
            <Link href="/simulador">
              <Button size="lg" className="bg-purple-600 hover:bg-purple-700">
                <Sparkles className="h-4 w-4 mr-2" />
                Conversar com Assistente IA
              </Button>
            </Link>
          </div>
        </div>
      </section>

      <Footer />
    </>
  );
}
