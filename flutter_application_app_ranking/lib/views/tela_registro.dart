import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/app_theme.dart';
import '../core/cpf_utils.dart';

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
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _carregando = false;
  bool _aceitouTermos = false;

  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;

  // Erros específicos de cada campo (validação assíncrona)
  String? _emailErro;
  String? _cpfErro;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceitouTermos) {
      _mostrarMensagem(
        "Você precisa aceitar os Termos de Uso para criar sua conta.",
        AppColors.warning,
      );
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _mostrarMensagem("As senhas devem ser idênticas", AppColors.error);
      setState(() => _carregando = false);
      return;
    }
    setState(() => _carregando = true);

    try {
      // 1) Verifica se já existe CPF cadastrado na tabela usuarios
      final cpfLimpo = _cpfController.text.trim().replaceAll(RegExp(r'\D'), '');
      final cpfExistente = await supabase
          .from('usuarios')
          .select('id')
          .eq('cpf', cpfLimpo)
          .maybeSingle();

      if (cpfExistente != null) {
        setState(() {
          _cpfErro = "Este CPF já está cadastrado em nossa plataforma.";
          _carregando = false;
        });
        return;
      }

      // 2) Verifica se já existe email cadastrado na tabela usuarios
      final emailLimpo = _emailController.text.trim().toLowerCase();
      final emailExistente = await supabase
          .from('usuarios')
          .select('id')
          .eq('email', emailLimpo)
          .maybeSingle();

      if (emailExistente != null) {
        setState(() {
          _emailErro = "Este e-mail já está cadastrado em nossa plataforma.";
          _carregando = false;
        });
        return;
      }

      // 3) Cria o usuário no Supabase Auth (Com as chaves corrigidas para a Trigger ler)
      await supabase.auth.signUp(
        email: emailLimpo,
        password: _senhaController.text.trim(),
        data: {
          'nome': _nomeController.text.trim(), // Ajustado igual à tabela
          'telefone': _telefoneController.text
              .trim(), // Ajustado igual à tabela
          'cpf': cpfLimpo,
        },
      );

      // O PASSO 4 FOI REMOVIDO DAQUI PORQUE A TRIGGER DO BANCO JÁ FAZ ISSO AUTOMATICAMENTE

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Conta criada com sucesso!"),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      setState(() => _carregando = false);
      debugPrint("❌ ERRO ORIGINAL DO SUPABASE: ${e.message}");

      if (e.message.toLowerCase().contains('already exists') ||
          e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('user already')) {
        setState(() {
          _emailErro = "Este e-mail já está cadastrado em nossa plataforma.";
        });
      } else if (e.message.toLowerCase().contains('database error') ||
          e.message.toLowerCase().contains('saving new user')) {
        _mostrarMensagem(
          "Erro ao criar conta. ${e.message}. Verifique as colunas do banco ou execute o script de correção.",
          AppColors.warning,
        );
      } else {
        _mostrarMensagem(e.message, AppColors.error);
      }
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        _mostrarMensagem("Erro inesperado: $e", AppColors.error);
      }
    }
  }

  void _mostrarMensagem(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }

  Future<void> _abrirTermosDeUso() async {
    try {
      final termos = await rootBundle.loadString('assets/termos_de_uso.txt');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.description,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Termos de Uso",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
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
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "ACEITAR E CONTINUAR",
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Fechar",
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _mostrarMensagem("Erro ao carregar Termos de Uso: $e", AppColors.error);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundElevated, AppColors.background],
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
                  const Text(
                    "Crie sua conta",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Comece sua jornada no Champions App",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 40),

                  _campo(
                    controller: _nomeController,
                    label: "Nome Completo",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  // Campo E-mail com validação de duplicidade
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoracaoDoCampo(
                      "E-mail",
                      Icons.email_outlined,
                    ),
                    onChanged: (_) {
                      if (_emailErro != null) setState(() => _emailErro = null);
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Campo obrigatório";
                      if (!v.contains('@') || !v.contains('.'))
                        return "Informe um e-mail válido";
                      if (_emailErro != null) return _emailErro;
                      return null;
                    },
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

                  // Campo CPF com validação de duplicidade
                  TextFormField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoracaoDoCampo(
                      "CPF (Somente números)",
                      Icons.badge_outlined,
                      placeholder: "00000000000",
                    ),
                    onChanged: (_) {
                      if (_cpfErro != null) setState(() => _cpfErro = null);
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Campo obrigatório";
                      final digitos = v.replaceAll(RegExp(r'\D'), '');
                      if (digitos.length != 11) {
                        return "CPF deve ter 11 dígitos";
                      }
                      if (!cpfValido(digitos)) {
                        return "CPF inválido";
                      }
                      if (_cpfErro != null) return _cpfErro;
                      return null;
                    },
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
                          _senhaVisivel
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Campo obrigatório";
                      if (v.length < 8)
                        return "A senha deve ter pelo menos 8 caracteres";
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
                          _confirmarSenhaVisivel
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                          () =>
                              _confirmarSenhaVisivel = !_confirmarSenhaVisivel,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Campo obrigatório";
                      if (v != _senhaController.text)
                        return "As senhas devem ser idênticas";
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
                            onChanged: (v) =>
                                setState(() => _aceitouTermos = v ?? false),
                            activeColor: AppColors.primary,
                            checkColor: AppColors.onPrimary,
                            side: const BorderSide(color: Colors.white38),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _aceitouTermos = !_aceitouTermos,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                                children: [
                                  const TextSpan(text: "Li e aceito os "),
                                  TextSpan(
                                    text: "Termos de Uso",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: null,
                                  ),
                                  const TextSpan(
                                    text:
                                        " e a Política de Privacidade da plataforma.",
                                  ),
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
                      icon: Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        "Ler Termos de Uso",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _registrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _carregando
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "CRIAR CONTA",
                              style: TextStyle(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  // Função auxiliar apenas para os campos simples (Nome, Telefone)
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
  InputDecoration _decoracaoDoCampo(
    String label,
    IconData icon, {
    String? placeholder,
    Widget? sufixo,
  }) {
    return buildInputDecoration(
      label: label,
      icon: icon,
      hintText: placeholder,
      suffixIcon: sufixo,
    ).copyWith(fillColor: Colors.white.withValues(alpha: 0.05));
  }
}
