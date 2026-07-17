import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';
import '../core/supabase_client.dart';

class TelaAjustes extends StatefulWidget {
  final VoidCallback onEditarPerfil;
  final VoidCallback onAbrirDesafios;
  final VoidCallback onAbrirPro;

  const TelaAjustes({
    super.key,
    required this.onEditarPerfil,
    required this.onAbrirDesafios,
    required this.onAbrirPro,
  });

  @override
  State<TelaAjustes> createState() => _TelaAjustesState();
}

class _TelaAjustesState extends State<TelaAjustes> {
  bool _alterandoSenha = false;

  User? get _usuario => supabase.auth.currentUser;

  void _mostrarMensagem(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }

  Future<void> _alterarSenha() async {
    final senhaController = TextEditingController();
    final confirmarSenhaController = TextEditingController();
    var ocultarSenha = true;
    String? erro;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Alterar senha',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Crie uma senha com pelo menos 6 caracteres.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: senhaController,
                      obscureText: ocultarSenha,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: buildInputDecoration(
                        label: 'Nova senha',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => ocultarSenha = !ocultarSenha,
                          ),
                          icon: Icon(
                            ocultarSenha
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmarSenhaController,
                      obscureText: ocultarSenha,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: buildInputDecoration(
                        label: 'Confirmar nova senha',
                        icon: Icons.lock_reset,
                      ),
                    ),
                    if (erro != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        erro!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: primaryButtonStyle(),
                  onPressed: () {
                    final senha = senhaController.text;
                    final confirmacao = confirmarSenhaController.text;

                    if (senha.length < 6) {
                      setDialogState(
                        () => erro =
                            'A senha precisa ter pelo menos 6 caracteres.',
                      );
                      return;
                    }
                    if (senha != confirmacao) {
                      setDialogState(
                        () => erro = 'As senhas digitadas não coincidem.',
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text(
                    'SALVAR SENHA',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    final novaSenha = senhaController.text;
    senhaController.dispose();
    confirmarSenhaController.dispose();

    if (confirmou != true) return;

    setState(() => _alterandoSenha = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: novaSenha));
      _mostrarMensagem('Senha atualizada com sucesso!', AppColors.success);
    } catch (e) {
      _mostrarMensagem('Não foi possível alterar a senha: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _alterandoSenha = false);
    }
  }

  Future<void> _abrirTermos() async {
    try {
      final termos = await rootBundle.loadString('assets/termos_de_uso.txt');
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Termos de Uso',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 620,
            height: MediaQuery.sizeOf(dialogContext).height * 0.65,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  termos,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: primaryButtonStyle(),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'FECHAR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarMensagem('Não foi possível abrir os termos: $e', AppColors.error);
    }
  }

  Future<void> _abrirDadosDaConta() async {
    final usuario = _usuario;
    if (usuario == null) return;

    final dataCriacao = DateTime.tryParse(usuario.createdAt);
    final dataFormatada = dataCriacao == null
        ? 'Não informada'
        : DateFormat('dd/MM/yyyy').format(dataCriacao.toLocal());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Dados da conta',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDadoConta('E-mail', usuario.email ?? 'Não informado'),
              const SizedBox(height: 14),
              _buildDadoConta('Conta criada em', dataFormatada),
              const SizedBox(height: 14),
              const Text(
                'ID da conta',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      usuario.id,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar ID',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: usuario.id));
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      _mostrarMensagem(
                        'ID da conta copiado.',
                        AppColors.success,
                      );
                    },
                    icon: const Icon(
                      Icons.copy_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Fechar',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirPrivacidade() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Privacidade e seus dados',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const SizedBox(
          width: 520,
          child: Text(
            'Seus dados de perfil são usados para identificar sua conta e sua participação nos desafios. '
            'Os vídeos enviados são utilizados para validação da atividade e prevenção a fraudes. '
            'Pagamentos são processados pelo parceiro financeiro indicado no aplicativo. '
            'Consulte os Termos de Uso para conhecer prazos, regras de validação e descarte dos vídeos.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Entendi',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirSobre() {
    showAboutDialog(
      context: context,
      applicationName: 'Circuito Fitness',
      applicationVersion: '0.1.0 (1)',
      applicationIcon: const CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Icon(Icons.fitness_center, color: AppColors.onPrimary),
      ),
      children: const [
        Text(
          'Desafios de performance, disciplina e evolução pessoal.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sair da conta',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Você precisará entrar novamente para acessar seus desafios.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(
              'SAIR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (sair == true) await supabase.auth.signOut();
  }

  Widget _buildDadoConta(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        SelectableText(
          valor,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildTituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 8),
      child: Text(
        titulo.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildGrupo(List<Widget> itens) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: itens),
    );
  }

  Widget _buildItem({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required VoidCallback? onTap,
    Color cor = AppColors.primary,
    bool mostrarDivisor = true,
    Widget? trailing,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: cor, size: 22),
          ),
          title: Text(
            titulo,
            style: TextStyle(
              color: cor == AppColors.error
                  ? AppColors.error
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitulo,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          trailing:
              trailing ??
              const Icon(Icons.chevron_right, color: AppColors.textDisabled),
        ),
        if (mostrarDivisor)
          const Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: AppColors.border,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _usuario?.email ?? 'E-mail não informado';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          const Text(
            'Ajustes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gerencie sua conta, segurança e informações do aplicativo.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.card,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.person,
                    color: AppColors.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sua conta',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Sessão protegida',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _buildTituloSecao('Conta e segurança'),
          _buildGrupo([
            _buildItem(
              icone: Icons.manage_accounts_outlined,
              titulo: 'Editar perfil',
              subtitulo: 'Altere sua foto, nome e descrição',
              onTap: widget.onEditarPerfil,
            ),
            _buildItem(
              icone: Icons.password_outlined,
              titulo: 'Alterar senha',
              subtitulo: 'Defina uma nova senha de acesso',
              onTap: _alterandoSenha ? null : _alterarSenha,
              trailing: _alterandoSenha
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            _buildItem(
              icone: Icons.badge_outlined,
              titulo: 'Dados da conta',
              subtitulo: 'Consulte e copie seu identificador',
              onTap: _abrirDadosDaConta,
              mostrarDivisor: false,
            ),
          ]),
          const SizedBox(height: 22),
          _buildTituloSecao('Acesso rápido'),
          _buildGrupo([
            _buildItem(
              icone: Icons.emoji_events_outlined,
              titulo: 'Meus desafios',
              subtitulo: 'Acompanhe suas participações e resultados',
              onTap: widget.onAbrirDesafios,
            ),
            _buildItem(
              icone: Icons.workspace_premium_outlined,
              titulo: 'Assinatura PRO',
              subtitulo: 'Veja os benefícios e o status da assinatura',
              onTap: widget.onAbrirPro,
              cor: AppColors.accent,
              mostrarDivisor: false,
            ),
          ]),
          const SizedBox(height: 22),
          _buildTituloSecao('Privacidade e informações'),
          _buildGrupo([
            _buildItem(
              icone: Icons.privacy_tip_outlined,
              titulo: 'Privacidade e seus dados',
              subtitulo: 'Entenda como as informações são utilizadas',
              onTap: _abrirPrivacidade,
            ),
            _buildItem(
              icone: Icons.description_outlined,
              titulo: 'Termos de Uso',
              subtitulo: 'Consulte as regras dos desafios',
              onTap: _abrirTermos,
            ),
            _buildItem(
              icone: Icons.info_outline,
              titulo: 'Sobre o aplicativo',
              subtitulo: 'Circuito Fitness • versão 0.1.0',
              onTap: _abrirSobre,
              mostrarDivisor: false,
            ),
          ]),
          const SizedBox(height: 22),
          _buildGrupo([
            _buildItem(
              icone: Icons.logout,
              titulo: 'Sair da conta',
              subtitulo: 'Encerrar a sessão neste dispositivo',
              onTap: _confirmarSaida,
              cor: AppColors.error,
              mostrarDivisor: false,
            ),
          ]),
        ],
      ),
    );
  }
}
