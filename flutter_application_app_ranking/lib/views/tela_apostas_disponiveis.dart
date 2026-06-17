import 'package:flutter/material.dart';
import '../core/supabase_client.dart';

class TelaApostasDisponiveis extends StatefulWidget {
  const TelaApostasDisponiveis({super.key});

  @override
  State<TelaApostasDisponiveis> createState() => _TelaApostasDisponiveisState();
}

class _TelaApostasDisponiveisState extends State<TelaApostasDisponiveis> {
  List<dynamic> _listaDeDesafios = [];
  bool _carregando = true;
  final List<String> _desafiosInscritosIds = []; // Guarda temporariamente onde o usuário já clicou em participar

  @override
  void initState() {
    super.initState();
    _carregarDesafios();
  }

  // 1. Carrega os desafios e verifica em quais o usuário já está inscrito
  Future<void> _carregarDesafios() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    final uid = supabase.auth.currentUser?.id;

    try {
      // Busca a lista da View inteligente do Supabase
      final dados = await supabase.from('v_apostas_com_participantes').select('*');

      // Busca quais desse usuário já estão na tabela participantes_apostas
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

  // 2. Função acionada ao clicar no botão "PARTICIPAR"
  Future<void> _inscreverNoDesafio(String desafioId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Insere o registro na tabela de relacionamento do Supabase
      await supabase.from('participantes_apostas').insert({
        'aposta_id': desafioId,
        'usuario_id': uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Inscrição confirmada! Vá para 'Meus Desafios' para acompanhar."),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Recarrega a lista para atualizar a contagem de participantes na tela
      _carregarDesafios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao entrar no desafio: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
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
          
          // Verifica se o ID desse card está na lista de inscritos do usuário
          final bool jaParticipa = _desafiosInscritosIds.contains(desafioId);

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
                  // Nome do Desafio
                  Text(
                    item['nome'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Informações de Duração e Participantes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.orangeAccent),
                          const SizedBox(width: 6),
                          Text(
                            item['duracao'] ?? '',
                            style: const TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                        ],
                      ),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people_alt_outlined, size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 6),
                            Text(
                              "${item['total_participantes'] ?? 0} atletas", // Trocamos "participantes" por "atletas"
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 16),

                  // 🚀 BOTÃO ADICIONADO: Entrar no Desafio
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: jaParticipa ? null : () => _inscreverNoDesafio(desafioId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: jaParticipa ? Colors.white12 : Colors.greenAccent.shade400,
                        disabledBackgroundColor: Colors.white10, // Cor de fundo se já estiver participando
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        jaParticipa ? "VOCÊ JÁ ESTÁ PARTICIPANDO" : "PARTICIPAR DO DESAFIO",
                        style: TextStyle(
                          color: jaParticipa ? Colors.white38 : Colors.black,
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
        },
      ),
    );
  }
}