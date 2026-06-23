import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import '../core/date_utils.dart';
import 'detalhe_desafios.dart'; 

class TelaMinhasApostas extends StatefulWidget {
  final VoidCallback onIrParaNovaAposta;

  const TelaMinhasApostas({super.key, required this.onIrParaNovaAposta});

  @override
  State<TelaMinhasApostas> createState() => _TelaMinhasApostasState();
}

class _TelaMinhasApostasState extends State<TelaMinhasApostas> {
  List<dynamic> _minhasInscricoes = [];
  Map<String, int> _atletasConfirmadosPorDesafio = {}; 
  bool _carregando = true;
  String _filtroSelecionado = 'Todos';

  @override
  void initState() {
    super.initState();
    _buscarInscricoesDoSupabase();
  }

  Future<void> _buscarInscricoesDoSupabase() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _carregando = true);

    try {
      final dadosInscricoes = await supabase
          .from('participantes_apostas')
          .select('*, apostas_disponiveis(*)') 
          .eq('usuario_id', uid)
          .order('created_at', ascending: false);

      final dadosContagem = await supabase
          .from('v_apostas_com_participantes')
          .select('*');

      final Map<String, int> contagemMap = {};
      for (var item in dadosContagem) {
        contagemMap[item['aposta_id'].toString()] = int.tryParse(item['atletas_confirmados'].toString()) ?? 0;
      }

      if (mounted) {
        setState(() {
          _minhasInscricoes = dadosInscricoes;
          _atletasConfirmadosPorDesafio = contagemMap;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar seus desafios: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Color _obterCorEstagio(String estagio) {
    switch (estagio) {
      case 'Em Andamento': return Colors.blueAccent;
      case 'A iniciar': return Colors.greenAccent;
      default: return Colors.white38; 
    }
  }

  Widget _buildStatusBadge(String texto, Color cor, IconData icone) {
    return Container(
      margin: const EdgeInsets.only(top: 8, right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool selecionado = _filtroSelecionado == label;
    return ChoiceChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _filtroSelecionado = label);
        }
      },
      selectedColor: Colors.greenAccent.shade400,
      backgroundColor: const Color(0xFF1A1A1A),
      labelStyle: TextStyle(
        color: selecionado ? Colors.black : Colors.white60,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      checkmarkColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selecionado ? Colors.greenAccent : Colors.white10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    }

    if (_minhasInscricoes.isEmpty) {
      return _buildTelaVaziaGeral();
    }

    final agora = DateTime.now();

    final inscricoesValidas = _minhasInscricoes.where((inscricao) {
      final desafio = inscricao['apostas_disponiveis'] ?? {};

      if (desafio.isEmpty) {
        return true; 
      }

      if (desafio['is_deleted'] == true) {
        return false; 
      }

      final dataLimite = DateTime.tryParse(desafio['data_limite_inscricao'] ?? '') ?? agora;
      
      final String statusPagamento = inscricao['status_pagamento'] ?? 'pendente';
      final String statusVideo = inscricao['status_video'] ?? 'nao_enviado';

      final bool irregular = (statusPagamento == 'pendente' || statusVideo == 'nao_enviado' || statusVideo == 'reprovado');
      final bool prazoEncerrado = agora.isAfter(dataLimite);

      if (irregular && prazoEncerrado) {
        final dataInicio = DateTime.tryParse(desafio['data_inicio'] ?? '') ?? agora;
        final diferencaDiasDoInicio = agora.difference(dataInicio).inDays;

        if (diferencaDiasDoInicio <= 5) {
          return true;
        }

        return false; 
      }
      return true;
    }).toList();

    String obterEstagioDesafio(Map<String, dynamic> desafio) {
      final dataInicio = DateTime.tryParse(desafio['data_inicio'] ?? '') ?? agora;
      final dataFim = DateTime.tryParse(desafio['data_fim'] ?? '') ?? agora;

      if (agora.isAfter(dataInicio) && agora.isBefore(dataFim)) {
        return 'Em Andamento';
      } else if (agora.isBefore(dataInicio)) {
        return 'A iniciar'; 
      } else {
        return 'Concluídos';
      }
    }

    List<dynamic> inscricoesFiltradas = inscricoesValidas.where((inscricao) {
      if (_filtroSelecionado == 'Todos') return true;
      final desafio = inscricao['apostas_disponiveis'] ?? {};
      return obterEstagioDesafio(desafio) == _filtroSelecionado;
    }).toList();

    if (_filtroSelecionado == 'Todos') {
      inscricoesFiltradas.sort((a, b) {
        final desafioA = a['apostas_disponiveis'] ?? {};
        final desafioB = b['apostas_disponiveis'] ?? {};

        final estagioA = obterEstagioDesafio(desafioA);
        final estagioB = obterEstagioDesafio(desafioB);

        int peso(String estagio) {
          if (estagio == 'Em Andamento') return 1;
          if (estagio == 'A iniciar') return 2;
          return 3;
        }

        return peso(estagioA).compareTo(peso(estagioB));
      });
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Em Andamento'),
                const SizedBox(width: 8),
                _buildFilterChip('A iniciar'), 
                const SizedBox(width: 8),
                _buildFilterChip('Concluídos'),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _buscarInscricoesDoSupabase,
            color: Colors.greenAccent,
            child: inscricoesFiltradas.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum desafio encontrado neste filtro.",
                      style: TextStyle(color: Colors.white38, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    itemCount: inscricoesFiltradas.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final inscricao = inscricoesFiltradas[index];
                      final desafio = inscricao['apostas_disponiveis'] ?? {}; 

                      final String titulo = desafio['nome'] ?? 'Desafio sem nome';
                      final String desafioId = desafio['id']?.toString() ?? '';
                      
                      final dataLimite = DateTime.tryParse(desafio['data_limite_inscricao'] ?? '') ?? agora;
                      final dataInicio = DateTime.tryParse(desafio['data_inicio'] ?? '') ?? agora;
                      final dataFim = DateTime.tryParse(desafio['data_fim'] ?? '') ?? agora;
                      
                      final duracaoDias = dataFim.difference(dataInicio).inDays;
                      final String limiteFormatado = dataLimite.shortFormatted;

                      final String statusPagamento = inscricao['status_pagamento'] ?? 'pendente';
                      final String statusVideo = inscricao['status_video'] ?? 'nao_enviado';

                      final int atletasConfirmados = _atletasConfirmadosPorDesafio[desafioId] ?? 0;
                      final double valorEntrada = double.tryParse(desafio['valor_entrada']?.toString() ?? '') ?? 0.0;
                      final double poteAcumulado = atletasConfirmados * valorEntrada;

                      final String estagioTemporal = obterEstagioDesafio(desafio);
                      final Color corEstagio = _obterCorEstagio(estagioTemporal);

                      // 🚀 FIXED: Variável renomeada para 'jaComecou' evitando caracteres ilegais no Dart
                      final bool irregular = (statusPagamento == 'pendente' || statusVideo == 'nao_enviado' || statusVideo == 'reprovado');
                      final bool jaComecou = agora.isAfter(dataInicio);
                      
                      int? diasRestantesCarencia;
                      if (irregular && jaComecou) {
                        final dataLimiteCarencia = dataInicio.add(const Duration(days: 5));
                        diasRestantesCarencia = dataLimiteCarencia.difference(agora).inDays + 1; 
                      }

                      return Card(
                        color: const Color(0xFF1A1A1A),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16), 
                          side: BorderSide(
                            color: diasRestantesCarencia != null ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white10,
                            width: diasRestantesCarencia != null ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TelaDetalhesDesafio(
                                  inscricaoData: inscricao,
                                  desafioData: desafio,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (diasRestantesCarencia != null) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            jaComecou && diasRestantesCarencia <= 0
                                                ? "⚠️ ATENÇÃO: Últimas horas para regularizar sua pesagem e pagamento!"
                                                : "⚠️ Desafio em andamento! Regularize seu envio em até $diasRestantesCarencia dias para não ser desclassificado.",
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        titulo,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: corEstagio.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: corEstagio, width: 1),
                                      ),
                                      child: Text(
                                        estagioTemporal.toUpperCase(),
                                        style: TextStyle(color: corEstagio, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 16, color: Colors.white54),
                                    const SizedBox(width: 6),
                                    Text("Duração: $duracaoDias dias", style: const TextStyle(color: Colors.white70)),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
                                    const SizedBox(width: 6),
                                    Text("Inscrições até: $limiteFormatado", style: const TextStyle(color: Colors.white70)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_outlined, size: 16, color: Colors.greenAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$atletasConfirmados ${atletasConfirmados == 1 ? 'confirmado' : 'confirmados'}", 
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.monetization_on_outlined, size: 16, color: Colors.greenAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Pote: R\$ ${poteAcumulado.toStringAsFixed(2)}", 
                                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white10),
                                Wrap(
                                  children: [
                                    if (statusPagamento == 'pendente')
                                      _buildStatusBadge("Pagamento Pendente", Colors.orangeAccent, Icons.payment_outlined),
                                    if (statusVideo == 'nao_enviado')
                                      _buildStatusBadge("Vídeo Pesagem Pendente", Colors.redAccent, Icons.videocam_off_outlined),
                                    if (statusVideo == 'reprovado')
                                      _buildStatusBadge("Vídeo Reprovado", Colors.redAccent, Icons.error_outline),
                                    if (statusVideo == 'aprovado')
                                      _buildStatusBadge("Vídeo Aprovado", Colors.greenAccent, Icons.check_circle_outline),
                                    if (statusVideo == 'em_analise')
                                      _buildStatusBadge("Vídeo em Análise", Colors.blueAccent, Icons.hourglass_top),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ), 
          ), 
        ), 
      ], 
    ); 
  }

  Widget _buildTelaVaziaGeral() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 80, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 20),
            const Text(
              "Você não está em nenhum desafio no momento.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220, height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.onIrParaNovaAposta,
                icon: const Icon(Icons.search, color: Colors.black),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text(
                  "BUSCAR DESAFIOS",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}