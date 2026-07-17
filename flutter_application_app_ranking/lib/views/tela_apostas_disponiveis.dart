import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import '../core/date_utils.dart';
import '../core/app_theme.dart';
import '../models/desafio_status.dart';
import 'detalhe_desafios.dart';

class TelaApostasDisponiveis extends StatefulWidget {
  final VoidCallback? onDesafioInscrito;

  const TelaApostasDisponiveis({super.key, this.onDesafioInscrito});

  @override
  State<TelaApostasDisponiveis> createState() => _TelaApostasDisponiveisState();
}

class _TelaApostasDisponiveisState extends State<TelaApostasDisponiveis> {
  List<dynamic> _listaDeDesafios = [];
  List<dynamic> _minhasPendencias = [];
  bool _carregando = true;
  final List<String> _desafiosInscritosIds = [];

  @override
  void initState() {
    super.initState();
    _carregarDesafios();
  }

  Future<void> _carregarDesafios() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    final uid = supabase.auth.currentUser?.id;
    final agora = DateTime.now().toIso8601String();

    try {
      // Filtra apenas desafios que ainda aceitam inscrição (data_limite_inscricao >= agora)
      final dados = await supabase
          .from('v_apostas_com_participantes')
          .select('*')
          .gte('data_limite_inscricao', agora)
          .order('data_limite_inscricao', ascending: true);

      if (uid != null) {
        // Busca inscrições do usuário para saber em quais ele já está
        final inscricoes = await supabase
            .from('participantes_desafios')
            .select('aposta_id, status_pagamento, status_video, desafios(*)')
            .eq('usuario_id', uid);

        _desafiosInscritosIds.clear();
        _minhasPendencias.clear();

        for (var inscricao in inscricoes) {
          _desafiosInscritosIds.add(inscricao['aposta_id'].toString());

          // Verifica se é uma pendência (pagamento pendente OU vídeo não aprovado)
          final String statusPagamento =
              inscricao['status_pagamento'] ?? 'pendente';
          final String statusVideo = inscricao['status_video'] ?? 'nao_enviado';
          final bool isPendente =
              (statusPagamento == 'pendente' ||
              statusVideo == 'nao_enviado' ||
              statusVideo == 'reprovado');

          if (isPendente) {
            _minhasPendencias.add(inscricao);
          }
        }
      }

      if (mounted) {
        setState(() {
          _listaDeDesafios = dados;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao carregar desafios: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _inscreverNoDesafio(
    DesafioModel desafio,
    Map<String, dynamic> itemOriginal,
  ) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final novaInscricao = await supabase
          .from('participantes_desafios')
          .insert({'aposta_id': desafio.id, 'usuario_id': uid})
          .select()
          .single();

      if (mounted) {
        // Exibe o feedback de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Inscrição realizada com sucesso!"),
            backgroundColor: AppColors.success,
          ),
        );

        // Redireciona DIRETAMENTE para a tela de detalhes do desafio recém-inscrito
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaDetalhesDesafio(
              inscricaoData: novaInscricao,
              desafioData: itemOriginal,
            ),
          ),
        ).then((_) {
          _carregarDesafios();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao entrar no desafio: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _irParaTelaPesagem(String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Abrindo tela de pesagem inicial..."),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _irParaProgresso(String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Abrindo tela de evolução/treinos..."),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Widget _buildPendenciaCard(Map<String, dynamic> inscricao) {
    final desafio = inscricao['desafios'] ?? {};
    final String titulo = desafio['nome'] ?? 'Desafio sem nome';
    final String statusPagamento = inscricao['status_pagamento'] ?? 'pendente';
    final String statusVideo = inscricao['status_video'] ?? 'nao_enviado';

    // Determina qual badge de pendência mostrar
    String textoPendencia;
    Color corPendencia;
    IconData iconePendencia;

    if (statusPagamento == 'pendente' &&
        (statusVideo == 'nao_enviado' || statusVideo == 'reprovado')) {
      textoPendencia = "Pagamento e Vídeo Pendentes";
      corPendencia = AppColors.error;
      iconePendencia = Icons.warning_amber_rounded;
    } else if (statusPagamento == 'pendente') {
      textoPendencia = "Pagamento Pendente";
      corPendencia = AppColors.warning;
      iconePendencia = Icons.payment_outlined;
    } else if (statusVideo == 'nao_enviado') {
      textoPendencia = "Vídeo de Pesagem não Enviado";
      corPendencia = AppColors.error;
      iconePendencia = Icons.videocam_off_outlined;
    } else if (statusVideo == 'reprovado') {
      textoPendencia = "Vídeo Reprovado - Reenvie";
      corPendencia = AppColors.error;
      iconePendencia = Icons.error_outline;
    } else {
      textoPendencia = "Pendente";
      corPendencia = AppColors.warning;
      iconePendencia = Icons.hourglass_empty;
    }

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: corPendencia.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: corPendencia.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconePendencia, color: corPendencia, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textoPendencia,
                      style: TextStyle(
                        color: corPendencia,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white38,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final bool temPendencias = _minhasPendencias.isNotEmpty;
    final bool temDesafiosDisponiveis = _listaDeDesafios.isNotEmpty;

    if (!temPendencias && !temDesafiosDisponiveis) {
      return const Center(
        child: Text(
          "Nenhum desafio disponível no momento.",
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    // Filtra para não mostrar desafios em que o usuário já está inscrito
    // (esses aparecem na aba DESAFIOS ou na seção de pendências acima)
    final desafiosNaoInscritos = _listaDeDesafios.where((item) {
      final String desafioId = item['id']?.toString() ?? '';
      return !_desafiosInscritosIds.contains(desafioId);
    }).toList();

    final bool temDesafiosNovos = desafiosNaoInscritos.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _carregarDesafios,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seção de Pendências (fixa no topo)
          if (temPendencias) ...[
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "MINHAS PENDÊNCIAS",
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            ..._minhasPendencias.map(
              (inscricao) => _buildPendenciaCard(inscricao),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
          ],

          // Título da seção de desafios disponíveis
          if (temDesafiosNovos) ...[
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "DESAFIOS ABERTOS",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            ...desafiosNaoInscritos.map((item) {
              final String desafioId = item['id']?.toString() ?? '';
              const bool jaParticipa =
                  false; // Sempre false aqui pois já filtramos

              final desafio = DesafioModel(
                id: desafioId,
                title: item['nome'] ?? 'Sem nome',
                dataLimiteInscricao:
                    DateTime.tryParse(item['data_limite_inscricao'] ?? '') ??
                    DateTime.now().add(const Duration(days: 2)),
                dataInicio:
                    DateTime.tryParse(item['data_inicio'] ?? '') ??
                    DateTime.now().add(const Duration(days: 3)),
                dataFim:
                    DateTime.tryParse(item['data_fim'] ?? '') ??
                    DateTime.now().add(const Duration(days: 30)),
                valorEntrada:
                    double.tryParse(item['valor_entrada']?.toString() ?? '') ??
                    25.00,
                totalParticipantes:
                    int.tryParse(
                      item['total_participantes']?.toString() ?? '',
                    ) ??
                    0,
              );

              return _cardDesafioReal(desafio, jaParticipa, item);
            }),
          ],
        ],
      ),
    );
  }

  Widget _cardDesafioReal(
    DesafioModel desafio,
    bool usuarioJaInscrito,
    Map<String, dynamic> itemOriginal,
  ) {
    final estagio = desafio.estagio;
    final agora = DateTime.now();

    Color corStatus;
    String textoStatus;
    String textoBotao;
    bool botaoAtivo = true;
    Widget infoExtra;

    final String dataFormatada = desafio.dataLimiteInscricao.shortFormatted;

    int diasDeJogo = 0;
    if (agora.isAfter(desafio.dataInicio)) {
      diasDeJogo = agora.difference(desafio.dataInicio).inDays;
    }

    switch (estagio) {
      case EstagioDesafio.divulgacao:
        corStatus = AppColors.primary;
        textoStatus = agora.isAfter(desafio.dataInicio)
            ? "COMEÇOU HÁ $diasDeJogo ${diasDeJogo == 1 ? 'DIA' : 'DIAS'}"
            : "INSCRIÇÕES ABERTAS";
        textoBotao = usuarioJaInscrito
            ? "VOCÊ JÁ ESTÁ DENTRO!"
            : "PARTICIPAR DO DESAFIO";
        botaoAtivo = !usuarioJaInscrito;
        infoExtra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pote Atual: R\$ ${desafio.poteTotal.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildBadgeParticipantes(desafio.totalParticipantes),
                const SizedBox(width: 12),
                _buildBadgeDataLimite(
                  "Inscrições até: $dataFormatada",
                  AppColors.warning,
                ),
              ],
            ),
          ],
        );
        break;

      case EstagioDesafio.bloqueio:
        corStatus = AppColors.warning;
        textoStatus = "INSCRIÇÕES ENCERRADAS";
        textoBotao = "PESAGEM INICIAL OBRIGATÓRIA";
        botaoAtivo = usuarioJaInscrito;
        infoExtra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pote Travado: R\$ ${desafio.poteTotal.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildBadgeParticipantes(desafio.totalParticipantes),
                const SizedBox(width: 12),
                _buildBadgeDataLimite(
                  "Encerradas em: $dataFormatada",
                  Colors.white38,
                ),
              ],
            ),
          ],
        );
        break;

      case EstagioDesafio.jogo:
        corStatus = AppColors.info;
        textoStatus =
            "EM ANDAMENTO (HÁ $diasDeJogo ${diasDeJogo == 1 ? 'DIA' : 'DIAS'})";
        textoBotao = usuarioJaInscrito ? "VER MEU PROGRESSO" : "SALA BLOQUEADA";
        botaoAtivo = usuarioJaInscrito;
        infoExtra = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "O cronômetro está rodando!",
              style: TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
            _buildBadgeParticipantes(desafio.totalParticipantes),
          ],
        );
        break;

      case EstagioDesafio.finalizado:
        corStatus = AppColors.error;
        textoStatus = "FASE FINAL (48H)";
        textoBotao = usuarioJaInscrito
            ? "ENVIAR PESAGEM FINAL"
            : "DESAFIO CONCLUÍDO";
        botaoAtivo = usuarioJaInscrito;
        infoExtra = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Divisão de R\$ ${desafio.poteTotal.toStringAsFixed(2)} em apuração!",
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildBadgeParticipantes(desafio.totalParticipantes),
          ],
        );
        break;
    }

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    desafio.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: corStatus, width: 1),
                  ),
                  child: Text(
                    textoStatus,
                    style: TextStyle(
                      color: corStatus,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            infoExtra,

            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: botaoAtivo
                    ? () {
                        if (estagio == EstagioDesafio.divulgacao) {
                          _inscreverNoDesafio(desafio, itemOriginal);
                        } else if (estagio == EstagioDesafio.bloqueio) {
                          _irParaTelaPesagem(desafio.id);
                        } else if (estagio == EstagioDesafio.jogo) {
                          _irParaProgresso(desafio.id);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: botaoAtivo
                      ? AppColors.primary
                      : Colors.white12,
                  disabledBackgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  textoBotao,
                  style: TextStyle(
                    color: botaoAtivo ? AppColors.onPrimary : Colors.white38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeParticipantes(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_alt_outlined,
            size: 14,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            "$total ${total == 1 ? 'atleta' : 'atletas'}",
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeDataLimite(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_outlined, size: 14, color: cor),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
