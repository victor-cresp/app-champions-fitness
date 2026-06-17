import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import 'tela_minhas_apostas.dart'; // Vamos criar essa tela a seguir
import 'tela_apostas_disponiveis.dart';

class TelaAbas extends StatefulWidget {
  const TelaAbas({super.key});

  @override
  State<TelaAbas> createState() => _TelaAbasState();
}

class _TelaAbasState extends State<TelaAbas> {
  int _abaAtual = 0;
  String _nomeUsuario = "Atleta";

  // Função que permite que uma tela filha mude a aba ativa do menu inferior
  void _mudarAba(int index) {
    setState(() => _abaAtual = index);
  }

  // Lista atualizada com as 4 telas do aplicativo
  List<Widget> get _telas => [
    TelaMinhasApostas(onIrParaNovaAposta: () => _mudarAba(1)), // Aba 0: Minhas Apostas
    const TelaApostasDisponiveis(),                            // 🛠️ MUDOU AQUI: Aba 1 Conectada!
    const Center(child: Text("Tela de Perfil em Desenvolvimento", style: TextStyle(color: Colors.white70, fontSize: 16))), // Aba 2
    const Center(child: Text("Tela de Configurações em Desenvolvimento", style: TextStyle(color: Colors.white70, fontSize: 16))), // Aba 3
  ];

  @override
  void initState() {
    super.initState();
    _recuperarNomeDoUsuario();
  }

  void _recuperarNomeDoUsuario() {
    final usuario = supabase.auth.currentUser;
    if (usuario != null && usuario.userMetadata != null) {
      setState(() {
        _nomeUsuario = usuario.userMetadata!['display_name'] ?? "Atleta";
      });
    }
  }

  Future<void> _fazerLogout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        toolbarHeight: 90,
        automaticallyImplyLeading: false, 
        title: Padding(
          padding: const EdgeInsets.only(left: 4.0, top: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Olá,", 
                style: TextStyle(
                  fontSize: 18, 
                  color: Colors.white.withValues(alpha: 0.6), 
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _nomeUsuario, 
                style: const TextStyle(
                  fontSize: 28, 
                  color: Colors.white, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: -0.5, 
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 14.0, right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Sair"),
                    content: const Text("Deseja realmente sair do aplicativo?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                      TextButton(onPressed: () {
                        Navigator.pop(context);
                        _fazerLogout();
                      }, child: const Text("Sair", style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(child: _telas[_abaAtual]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual,
        onTap: (index) => setState(() => _abaAtual = index),
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: Colors.greenAccent.shade400,
        unselectedItemColor: Colors.white38,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, // Necessário para exibir mais de 3 itens sem sumir com os textos
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.style_outlined),
            activeIcon: Icon(Icons.style),
            label: 'Meus Desafios', // <-- Trocado de 'Minhas Apostas'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Desafios', // <-- Trocado de 'Apostas'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Configurações',
          ),
        ],
      ),
    );
  }
}