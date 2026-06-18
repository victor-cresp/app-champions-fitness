import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import 'tela_minhas_apostas.dart'; 
import 'tela_apostas_disponiveis.dart';
import 'tela_perfil.dart';
import 'tela_adm.dart';

class TelaAbas extends StatefulWidget {
  const TelaAbas({super.key});

  @override
  State<TelaAbas> createState() => _TelaAbasState();
}

class _TelaAbasState extends State<TelaAbas> {
  int _abaAtual = 0;
  bool _isAdmin = false;
  String _nomeUsuario = "Atleta"; // Nome padrão caso demore a carregar

  void _mudarAba(int index) {
    setState(() => _abaAtual = index);
  }

  @override
  void initState() {
    super.initState();
    _buscarDadosIniciais();
  }

// Busca o status de admin e o nome do usuário de forma assíncrona garantindo atualização de tela
  Future<void> _buscarDadosIniciais() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Fazemos a query exata que a tela de perfil faz com sucesso
      final dados = await supabase
          .from('usuarios')
          .select('is_admin, nome')
          .eq('id', uid)
          .single();
      
      if (mounted) {
        setState(() {
          _isAdmin = dados['is_admin'] ?? false;
          
          final nomeCompleto = dados['nome'];
          if (nomeCompleto != null && nomeCompleto.toString().trim().isNotEmpty) {
            // Pega o primeiro nome e garante que o Flutter atualize o topo do app!
            _nomeUsuario = nomeCompleto.toString().trim().split(' ')[0];
          } else {
            _nomeUsuario = "Atleta";
          }
        });
      }
    } catch (e) {
      // Fallback de segurança se a internet falhar
      if (mounted) {
        setState(() {
          _nomeUsuario = "Atleta";
        });
      }
    }
  }

  List<Widget> _obterTelas() {
    final telas = [
      TelaMinhasApostas(onIrParaNovaAposta: () => _mudarAba(1)), 
      const TelaApostasDisponiveis(),                            
      const TelaPerfil(),                                        
      const Center(child: Text("Tela de Configurações em Desenvolvimento", style: TextStyle(color: Colors.white70, fontSize: 16))), 
    ];

    if (_isAdmin) {
      telas.add(const TelaAdm());
    }
    return telas;
  }

  @override
  Widget build(BuildContext context) {
    final todasAsTelas = _obterTelas();

    if (_abaAtual >= todasAsTelas.length) {
      _abaAtual = 0;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        toolbarHeight: 70, // Dá um pouquinho mais de espaço para o topo respirar
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Olá,",
              style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w400),
            ),
            // 🚀 MENSAGEM DE BOAS-VINDAS DEVOLVIDA COM ESTILO ESPORTIVO
            Text(
              _nomeUsuario,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 26),
            tooltip: "Sair do Aplicativo",
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text("Sair do Aplicativo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text("Você tem certeza que deseja sair da sua conta?", style: TextStyle(color: Colors.white70)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancelar", style: TextStyle(color: Colors.white38)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await supabase.auth.signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Sair", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      
      body: SafeArea(child: todasAsTelas[_abaAtual]),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual,
        onTap: (index) => setState(() => _abaAtual = index),
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: Colors.greenAccent.shade400,
        unselectedItemColor: Colors.white38,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, 
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.style_outlined),
            activeIcon: Icon(Icons.style),
            label: 'Meus Desafios',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Desafios',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
          if (_isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'ADM',
            ),
        ],
      ),
    );
  }
}