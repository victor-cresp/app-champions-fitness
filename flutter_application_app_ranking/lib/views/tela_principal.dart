import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../services/ranking_service.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final String bairroFoco = "taquara";
  final RankingService _rankingService = RankingService();

  bool _treinando = false;
  List<dynamic> _rankingDados = [];
  bool _carregandoRanking = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _carregandoRanking = true);
    try {
      final dados = await _rankingService.buscarRanking(bairroFoco);
      if (mounted) {
        setState(() {
          _rankingDados = dados;
          _carregandoRanking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoRanking = false);
    }
  }

  Future<void> _alternarTreino() async {
    final String? usuarioId = supabase.auth.currentUser?.id;
    if (usuarioId == null) return;

    setState(() => _treinando = !_treinando);

    if (!_treinando) {
      final sucesso = await _rankingService.enviarTreino({
        'usuario_id': usuarioId,
        'bairro_id': bairroFoco,
        'data_treino': DateTime.now().toIso8601String(),
        'pontos_ganhos': 10,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sucesso ? "Treino concluído! +10 PTS" : "Erro ao computar pontos."),
            backgroundColor: sucesso ? Colors.green : Colors.redAccent,
          ),
        );
      }
      _carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retorna apenas o conteúdo interno sem Scaffold ou AppBar própria
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Seção de Destaque / Botão de Treinar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  _treinando ? "Treino em andamento..." : "Pronto para pontuar?",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _alternarTreino,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _treinando ? Colors.redAccent : Colors.greenAccent.shade400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _treinando ? "PARAR E SALVAR TREINO" : "INICIAR TREINO",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Título da Liga
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Liga ${bairroFoco.toUpperCase()}", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                onPressed: _carregarDados,
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          
          // Lista do Ranking
          Expanded(
            child: _carregandoRanking
                ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : _rankingDados.isEmpty
                    ? const Center(child: Text("Nenhum atleta pontuou neste bairro ainda.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: _rankingDados.length,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemBuilder: (context, index) {
                          final atleta = _rankingDados[index];
                          return Card(
                            color: const Color(0xFF1A1A1A),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: index == 0 ? Colors.orangeAccent : Colors.grey[800],
                                child: Text("${index + 1}º", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(atleta['usuario_nome'] ?? 'Atleta', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              subtitle: Text("${atleta['total_treinos']} treinos confirmados", style: const TextStyle(color: Colors.white60)),
                              trailing: Text("${atleta['total_pontos']} PTS", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}