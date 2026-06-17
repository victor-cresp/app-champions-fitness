import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/supabase_client.dart';
import '../../services/ranking_service.dart';
import 'tela_login.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final String bairroFoco = "taquara";
  final RankingService _rankingService = RankingService();

  bool _treinando = false;
  DateTime? _timestampInicio;
  List<dynamic> _rankingDados = [];
  bool _carregandoRanking = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  

  Future<void> _carregarDados() async {
    setState(() => _carregandoRanking = true);
    try {
      final dados = await _rankingService.buscarRanking(bairroFoco);
      setState(() {
        _rankingDados = dados;
        _carregandoRanking = false;
      });
    } catch (e) {
      setState(() => _carregandoRanking = false);
    }
  }

 Future<void> _alternarTreino() async {
  final String? usuarioId = supabase.auth.currentUser?.id;

  if (usuarioId == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuário não identificado.")));
    return;
  }

  if (!_treinando) {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }
    setState(() {
      _treinando = true;
      _timestampInicio = DateTime.now();
    });
  } else {
    setState(() => _carregandoRanking = true);
    Position position = await Geolocator.getCurrentPosition();
    int minutosTreinados = DateTime.now().difference(_timestampInicio!).inMinutes;
    if (minutosTreinados == 0) minutosTreinados = 55; // Mantendo sua regra de segurança

    // Dados mapeados perfeitamente para as colunas da sua tabela no Supabase
    final dadosTreino = {
      "usuario_id": usuarioId, 
      "bairro_id": bairroFoco,
      "academia_latitude": position.latitude,
      "academia_longitude": position.longitude,
      "tempo_total_minutos": minutosTreinados,
      "percentual_movimento": 85
    };

    final sucesso = await _rankingService.enviarTreino(dadosTreino);
    if (sucesso) {
      await _carregarDados(); // Recarrega o ranking atualizado direto do banco
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao salvar treino. Verifique o RLS do banco.")),
        );
      }
      setState(() => _carregandoRanking = false);
    }

    setState(() {
      _treinando = false;
      _timestampInicio = null;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🏆 Liga ${bairroFoco.toUpperCase()}"),
        backgroundColor: const Color(0xFF1F1F1F),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaLogin()));
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _alternarTreino,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _treinando ? Colors.redAccent.withValues(alpha: 0.1) : Colors.greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _treinando ? Colors.redAccent : Colors.greenAccent, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_treinando ? Icons.stop_circle : Icons.play_circle_fill, color: _treinando ? Colors.redAccent : Colors.greenAccent, size: 36),
                    const SizedBox(height: 8),
                    Text(_treinando ? "ENCERRAR TREINO" : "INICIAR TREINO", style: TextStyle(fontWeight: FontWeight.bold, color: _treinando ? Colors.redAccent : Colors.greenAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                Icon(Icons.leaderboard, color: Colors.orangeAccent),
                SizedBox(width: 8),
                Text("Classificação da Categoria", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: _carregandoRanking
                  ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                  : ListView.builder(
                      itemCount: _rankingDados.length,
                      itemBuilder: (context, index) {
                        final atleta = _rankingDados[index];
                        return Card(
                          color: const Color(0xFF1F1F1F),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: index == 0 ? Colors.orangeAccent : Colors.grey[800],
                              child: Text("${index + 1}º", style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(atleta['usuario_nome'] ?? 'Atleta', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${atleta['total_treinos']} treinos confirmados"),
                            trailing: Text("${atleta['total_pontos']} PTS", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}