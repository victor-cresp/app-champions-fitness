import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import 'detalhe_desafios.dart';

enum EstagioDesafio { divulgacao, bloqueio, jogo, finalizado }

class DesafioModel {
  final String id;
  final String title;
  final DateTime dataLimiteInscricao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valorEntrada;
  final int totalParticipantes;

  DesafioModel({
    required this.id,
    required this.title,
    required this.dataLimiteInscricao,
    required this.dataInicio,
    required this.dataFim,
    required this.valorEntrada,
    required this.totalParticipantes,
  });

  double get poteTotal => totalParticipantes * valorEntrada;

  EstagioDesafio get estagio {
    final agora = DateTime.now();
    
    if (agora.isBefore(dataLimiteInscricao)) {
      return EstagioDesafio.divulgacao;
    } else if (agora.isAfter(dataLimiteInscricao) && agora.isBefore(dataInicio)) {
      return EstagioDesafio.bloqueio;
    } else if (agora.isAfter(dataInicio) && agora.isBefore(dataFim)) {
      final limiteAtrasados = dataInicio.add(const Duration(days: 5));
      if (agora.isBefore(limiteAtrasados)) {
        return EstagioDesafio.divulgacao; 
      }
      return EstagioDesafio.jogo;
    } else {
      return EstagioDesafio.finalizado;
    }
  }
}

class TelaApostasDisponiveis extends StatefulWidget {
  final VoidCallback? onDesafioInscrito;

  const TelaApostasDisponiveis({super.key, this.onDesafioInscrito});

  @override
  State<TelaApostasDisponiveis> createState() => _TelaApostasDisponiveisState();
}

class _TelaApostasDisponiveisState extends State<TelaApostasDisponiveis> {
  List<dynamic> _listaDeDesafios = [];
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

    try {
      final dados = await supabase.from('v_apostas_com_participantes').select('*');

      if (uid != null) {
        final inscricoes = await supabase
            .from('participantes_apostas')
            .select('aposta_id')
            .eq('usuario_id', uid);
        
        _desafiosInscritosIds.clear();
        for (var inscricao in inscricoes) {
          _desafiosInscritosIds.add(inscricao['aposta_id'].toString());
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
          SnackBar(content: Text("Erro ao carregar desafios: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _inscreverNoDesafio(DesafioModel desafio, Map<String, dynamic> itemOriginal) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final novaInscricao = await supabase.from('participantes_apostas').insert({
        'aposta_id': desafio.id,
        'usuario_id': uid,
      }).select().single(); 

      if (mounted) {
        final agora = DateTime.now();
        
        if (agora.isAfter(desafio.dataInicio)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Inscrição realizada! Abra os detalhes para regularizar seu pagamento e peso."), backgroundColor: Colors.orangeAccent),
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TelaDetalhesDesafio(
                inscricaoData: novaInscricao, 
                desafioData: itemOriginal,    
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Inscrição confirmada! Redirecionando para seus desafios..."), backgroundColor: Colors.green),
          );
          if (widget.onDesafioInscrito != null) {
            widget.onDesafioInscrito!();
          }
        }
      }
      _carregarDesafios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao entrar no desafio: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _irParaTelaPesagem(String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Abrindo tela de pesagem inicial..."), backgroundColor: Colors.orangeAccent)
    );
  }

  void _irParaProgresso(String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Abrindo tela de evolução/treinos..."), backgroundColor: Colors.blueAccent)
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    }

    if (_listaDeDesafios.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum desafio disponível no momento.",
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarDesafios,
      color: Colors.greenAccent,
      child: ListView.builder(
        itemCount: _listaDeDesafios.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = _listaDeDesafios[index];
          final String desafioId = item['id']?.toString() ?? '';
          final bool jaParticipa = _desafiosInscritosIds.contains(desafioId);

          final desafio = DesafioModel(
            id: desafioId,
            title: item['nome'] ?? 'Sem nome',
            dataLimiteInscricao: DateTime.tryParse(item['data_limite_inscricao'] ?? '') ?? DateTime.now().add(const Duration(days: 2)),
            dataInicio: DateTime.tryParse(item['data_inicio'] ?? '') ?? DateTime.now().add(const Duration(days: 3)),
            dataFim: DateTime.tryParse(item['data_fim'] ?? '') ?? DateTime.now().add(const Duration(days: 30)),
            valorEntrada: double.tryParse(item['valor_entrada']?.toString() ?? '') ?? 25.00,
            totalParticipantes: int.tryParse(item['total_participantes']?.toString() ?? '') ?? 0,
          );

          return _cardDesafioReal(desafio, jaParticipa, item);
        },
      ),
    );
  }

  Widget _cardDesafioReal(DesafioModel desafio, bool usuarioJaInscrito, Map<String, dynamic> itemOriginal) {    
    final estagio = desafio.estagio;
    final agora = DateTime.now();

    Color corStatus;
    String textoStatus;
    String textoBotao;
    bool botaoAtivo = true;
    Widget infoExtra;

    final String dataFormatada = "${desafio.dataLimiteInscricao.day.toString().padLeft(2, '0')}/${desafio.dataLimiteInscricao.month.toString().padLeft(2, '0')}";

    int diasDeJogo = 0;
    if (agora.isAfter(desafio.dataInicio)) {
      diasDeJogo = agora.difference(desafio.dataInicio).inDays;
    }

    switch (estagio) {
      case EstagioDesafio.divulgacao:
        corStatus = Colors.greenAccent;
        textoStatus = agora.isAfter(desafio.dataInicio) 
            ? "COMEÇOU HÁ $diasDeJogo ${diasDeJogo == 1 ? 'DIA' : 'DIAS'}" 
            : "INSCRIÇÕES ABERTAS";
        textoBotao = usuarioJaInscrito ? "VOCÊ JÁ ESTÁ DENTRO!" : "PARTICIPAR DO DESAFIO";
        botaoAtivo = !usuarioJaInscrito;
        infoExtra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pote Atual: R\$ ${desafio.poteTotal.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildBadgeParticipantes(desafio.totalParticipantes),
                const SizedBox(width: 12),
                _buildBadgeDataLimite("Inscrições até: $dataFormatada", Colors.orangeAccent),
              ],
            ),
          ],
        );
        break;

      case EstagioDesafio.bloqueio:
        corStatus = Colors.orangeAccent;
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
                _buildBadgeDataLimite("Encerradas em: $dataFormatada", Colors.white38),
              ],
            ),
          ],
        );
        break;

      case EstagioDesafio.jogo:
        corStatus = Colors.blueAccent;
        textoStatus = "EM ANDAMENTO (HÁ $diasDeJogo ${diasDeJogo == 1 ? 'DIA' : 'DIAS'})";
        textoBotao = usuarioJaInscrito ? "VER MEU PROGRESSO" : "SALA BLOQUEADA";
        botaoAtivo = usuarioJaInscrito;
        infoExtra = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "O cronômetro está rodando!",
              style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
            _buildBadgeParticipantes(desafio.totalParticipantes),
          ],
        );
        break;

      case EstagioDesafio.finalizado:
        corStatus = Colors.redAccent;
        textoStatus = "FASE FINAL (48H)";
        textoBotao = usuarioJaInscrito ? "ENVIAR PESAGEM FINAL" : "DESAFIO CONCLUÍDO";
        botaoAtivo = usuarioJaInscrito;
        infoExtra = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Divisão de R\$ ${desafio.poteTotal.toStringAsFixed(2)} em apuração!",
                style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold),
              ),
            ),
            _buildBadgeParticipantes(desafio.totalParticipantes),
          ],
        );
        break;
    }

    return Card(
      color: const Color(0xFF1A1A1A),
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: corStatus, width: 1),
                  ),
                  child: Text(
                    textoStatus,
                    style: TextStyle(color: corStatus, fontSize: 10, fontWeight: FontWeight.bold),
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
                onPressed: botaoAtivo ? () {
                  if (estagio == EstagioDesafio.divulgacao) {
                    // 🚀 CORRIGIDO: Agora usa o 'itemOriginal' mapeado no parâmetro do card
                    _inscreverNoDesafio(desafio, itemOriginal);
                  } else if (estagio == EstagioDesafio.bloqueio) {
                    _irParaTelaPesagem(desafio.id);
                  } else if (estagio == EstagioDesafio.jogo) {
                    _irParaProgresso(desafio.id);
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: botaoAtivo ? Colors.greenAccent.shade400 : Colors.white12,
                  disabledBackgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  textoBotao,
                  style: TextStyle(
                    color: botaoAtivo ? Colors.black : Colors.white38,
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
        color: Colors.greenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_outlined, size: 14, color: Colors.greenAccent),
          const SizedBox(width: 6),
          Text(
            "$total ${total == 1 ? 'atleta' : 'atletas'}",
            style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
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
            style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}