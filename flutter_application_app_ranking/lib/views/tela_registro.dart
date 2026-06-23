import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/app_theme.dart';

class TelaRegistro extends StatefulWidget {
  const TelaRegistro({super.key});

  @override
  State<TelaRegistro> createState() => _TelaRegistroState();
}

class _TelaRegistroState extends State<TelaRegistro> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  
  // 🚀 NOVO: Controlador para o CPF
  final _cpfController = TextEditingController();
  
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  
  bool _carregando = false;
  bool _aceitouTermos = false;
  
  // Variáveis para controlar a visibilidade das senhas
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceitouTermos) {
      _mostrarMensagem("Você precisa aceitar os Termos de Uso para criar sua conta.", Colors.orangeAccent);
      return;
    }
    setState(() => _carregando = true);

    try {
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
        data: {
          'display_name': _nomeController.text.trim(),
          'phone_number': _telefoneController.text.trim(),
          // 🚀 NOVO: Salvando o CPF nos metadados do usuário no Supabase
          'cpf': _cpfController.text.trim(),
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Conta criada com sucesso!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      _mostrarMensagem(e.message, Colors.redAccent);
    } catch (e) {
      _mostrarMensagem("Erro inesperado: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarMensagem(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor),
    );
  }

  Future<void> _abrirTermosDeUso() async {
    try {
      final termos = await rootBundle.loadString('assets/termos_de_uso.txt');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description, color: Colors.greenAccent, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Termos de Uso",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      termos,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _aceitouTermos = true);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "ACEITAR E CONTINUAR",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Fechar", style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _mostrarMensagem("Erro ao carregar Termos de Uso: $e", Colors.redAccent);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose(); // 🚀 NOVO: Limpando o controlador do CPF
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Colors.black],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Crie sua conta", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text("Comece sua jornada no Champions App", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 40),
                  
                  _campo(controller: _nomeController, label: "Nome Completo", icon: Icons.person_outline),
                  const SizedBox(height: 16),

                  _campo(
                    controller: _emailController, 
                    label: "E-mail", 
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  _campo(
                    controller: _telefoneController, 
                    label: "Telefone / Celular", 
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    placeholder: "(XX) XXXXX-XXXX",
                  ),
                  const SizedBox(height: 16),

                  // 🚀 NOVO: Campo visual do CPF
                  _campo(
                    controller: _cpfController, 
                    label: "CPF (Somente números)", 
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    placeholder: "00000000000",
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Senha
                  TextFormField(
                    controller: _senhaController,
                    obscureText: !_senhaVisivel,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoracaoDoCampo(
                      "Senha", 
                      Icons.lock_outline,
                      sufixo: IconButton(
                        icon: Icon(
                          _senhaVisivel ? Icons.visibility : Icons.visibility_off, 
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Campo obrigatório";
                      if (v.length < 8) return "A senha deve ter pelo menos 8 caracteres";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Confirmar Senha
                  TextFormField(
                    controller: _confirmarSenhaController,
                    obscureText: !_confirmarSenhaVisivel,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoracaoDoCampo(
                      "Confirmar Senha", 
                      Icons.lock_clock_outlined,
                      sufixo: IconButton(
                        icon: Icon(
                          _confirmarSenhaVisivel ? Icons.visibility : Icons.visibility_off, 
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _confirmarSenhaVisivel = !_confirmarSenhaVisivel),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Campo obrigatório";
                      if (v != _senhaController.text) return "As senhas não são iguais";
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),

                  // Aceite dos Termos de Uso
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _aceitouTermos,
                            onChanged: (v) => setState(() => _aceitouTermos = v ?? false),
                            activeColor: Colors.greenAccent.shade400,
                            checkColor: Colors.black,
                            side: const BorderSide(color: Colors.white38),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _aceitouTermos = !_aceitouTermos),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.3),
                                children: [
                                  const TextSpan(text: "Li e aceito os "),
                                  TextSpan(
                                    text: "Termos de Uso",
                                    style: TextStyle(
                                      color: Colors.greenAccent.shade400,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: null,
                                  ),
                                  const TextSpan(text: " e a Política de Privacidade da plataforma."),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botão de ver Termos de Uso
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _abrirTermosDeUso,
                      icon: Icon(Icons.description_outlined, size: 16, color: Colors.greenAccent.shade400),
                      label: Text(
                        "Ler Termos de Uso",
                        style: TextStyle(color: Colors.greenAccent.shade400, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _registrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _carregando 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          ) 
                        : const Text("CRIAR CONTA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Função auxiliar apenas para os campos simples (Nome, Email, Telefone, CPF)
  Widget _campo({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    TextInputType keyboardType = TextInputType.text,
    String? placeholder,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _decoracaoDoCampo(label, icon, placeholder: placeholder),
      validator: (v) => (v == null || v.isEmpty) ? "Campo obrigatório" : null,
    );
  }

  // Centraliza o estilo visual
  InputDecoration _decoracaoDoCampo(String label, IconData icon, {String? placeholder, Widget? sufixo}) {
    return buildInputDecoration(label: label, icon: icon, hintText: placeholder, suffixIcon: sufixo)
      .copyWith(fillColor: Colors.white.withValues(alpha: 0.05));
  }
}