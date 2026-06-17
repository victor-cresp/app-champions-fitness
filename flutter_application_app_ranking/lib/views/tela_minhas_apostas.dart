import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

class TelaMinhasApostas extends StatefulWidget {
  final VoidCallback onIrParaNovaAposta;

  const TelaMinhasApostas({super.key, required this.onIrParaNovaAposta});

  @override
  State<TelaMinhasApostas> createState() => _TelaMinhasApostasState();
}

class _TelaMinhasApostasState extends State<TelaMinhasApostas> {
  List<dynamic> _apostas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarApostasDoSupabase();
  }

  // Faz a ponte real e segura com a tabela do Supabase
  Future<void> _buscarApostasDoSupabase() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _carregando = true);

    try {
      // Busca da tabela pública "apostas" filtrando pelo ID do usuário atual
      final dados = await supabase
          .from('participantes_apostas')
          .select('*')
          .eq('usuario_id', uid)
          .order('created_at', ascending: false);

      setState(() {
        _apostas = dados;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar apostas: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Método auxiliar para definir a cor do texto do status de forma limpa
  Color _obterCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ganhou': return Colors.greenAccent;
      case 'perdeu': return Colors.redAccent;
      default: return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    }

    // Caso o usuário não tenha nenhuma aposta salva no banco de dados
    if (_apostas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.casino_outlined, size: 80, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              const Text(
                "Você ainda não possui apostas registradas.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                "Dê o seu palpite agora mesmo e comece a pontuar!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white38),
              ),
              const SizedBox(height: 32),
              
              // Botão que redireciona o usuário para a aba de Apostas
              SizedBox(
                width: 220, height: 50,
                child: ElevatedButton.icon(
                  onPressed: widget.onIrParaNovaAposta,
                  icon: const Icon(Icons.add, color: Colors.black),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    "NOVO DESAFIO",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Se ele possuir apostas, exibe a lista estilizada
    return RefreshIndicator(
      onRefresh: _buscarApostasDoSupabase,
      color: Colors.greenAccent,
      child: ListView.builder(
        itemCount: _apostas.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final aposta = _apostas[index];
          final String descricao = aposta['descricao'] ?? 'Aposta';
          final double valor = double.tryParse(aposta['valor_aposta'].toString()) ?? 0.0;
          final String status = aposta['status'] ?? 'Pendente';

          return Card(
            color: const Color(0xFF1A1A1A),
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: _obterCorStatus(status).withValues(alpha: 0.15),
                child: Icon(Icons.sports_soccer, color: _obterCorStatus(status)),
              ),
              title: Text(
                descricao, 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Valor: R\$ ${valor.toStringAsFixed(2)}", 
                  style: const TextStyle(color: Colors.white54)
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _obterCorStatus(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: _obterCorStatus(status), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}