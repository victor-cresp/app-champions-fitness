import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🔥 Importado para usar o RealtimeChannel
import '../core/supabase_client.dart';
import '../core/app_theme.dart';
import '../asaas_service.dart';

class TelaMembro extends StatefulWidget {
  final VoidCallback? onAbrirDesafios;

  const TelaMembro({super.key, this.onAbrirDesafios});

  @override
  State<TelaMembro> createState() => _TelaMembroState();
}

class _TelaMembroState extends State<TelaMembro> {
  bool _carregandoStatus = true;
  bool _isMembro = false;
  bool _processandoAssinatura = false;
  bool _mostrarCheckout = false;
  final _checkoutKey = GlobalKey();
  RealtimeChannel? _usuarioSubscription; // 🔥 Canal Realtime da assinatura

  String _metodoSelecionado = 'PIX';
  String? _pixCode;
  String? _qrCodeBase64;

  final _nomeCard = TextEditingController();
  final _numCard = TextEditingController();
  final _mesCard = TextEditingController();
  final _anoCard = TextEditingController();
  final _cvvCard = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checarStatusMembro();
    _escutarStatusMembroRealtime(); // 🔥 Inicia a escuta em tempo real do plano
  }

  @override
  void dispose() {
    // 🔥 Correção: Remove o canal diretamente usando a instância dele
    if (_usuarioSubscription != null) {
      supabase.removeChannel(_usuarioSubscription!);
    }
    _nomeCard.dispose();
    _numCard.dispose();
    _mesCard.dispose();
    _anoCard.dispose();
    _cvvCard.dispose();
    super.dispose();
  }

  void _escutarStatusMembroRealtime() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _usuarioSubscription = supabase
        .channel('public:usuarios:id=eq.$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'usuarios',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (payload) {
            final virouMembro = payload.newRecord['is_membro'] == true;

            if (virouMembro) {
              if (mounted) {
                setState(() {
                  _isMembro = true;
                  _pixCode = null;
                  _qrCodeBase64 = null;
                });
                _alerta(
                  "PRO Ativado! ⚡",
                  "Parabéns! Seu acesso Atleta PRO está ativo em tempo real.",
                  AppColors.success,
                );
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _checarStatusMembro() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _carregandoStatus = false);
      return;
    }
    try {
      final dados = await supabase
          .from('usuarios')
          .select('is_membro')
          .eq('id', uid)
          .single();
      if (mounted) {
        setState(() {
          _isMembro = dados['is_membro'] ?? false;
          _carregandoStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregandoStatus = false);
    }
  }

  Future<void> _assinarPlanoPro() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _processandoAssinatura = true);
    try {
      final userDb = await supabase
          .from('usuarios')
          .select('nome, cpf')
          .eq('id', uid)
          .single();
      final String cpfCliente = userDb['cpf'] ?? '';

      final emailUsuario = supabase.auth.currentUser?.email ?? '';

      if ((userDb['nome'] ?? '').toString().trim().isEmpty ||
          cpfCliente.trim().isEmpty ||
          emailUsuario.trim().isEmpty) {
        throw 'Seu cadastro precisa ter nome, CPF e e-mail antes da assinatura.';
      }

      if (_metodoSelecionado == 'PIX') {
        final resultado = await AsaasService.criarAssinaturaProPix(
          usuarioId: uid,
          nomeCliente: userDb['nome'] ?? '',
          emailCliente: emailUsuario,
          cpfCnpjCliente: cpfCliente,
        );

        if (!mounted) return;
        setState(() {
          _pixCode = resultado['pixCopiaECola'];
          _qrCodeBase64 = resultado['pixQrCodeBase64'];
        });
      } else {
        if (_nomeCard.text.isEmpty ||
            _numCard.text.isEmpty ||
            _mesCard.text.isEmpty ||
            _anoCard.text.isEmpty ||
            _cvvCard.text.isEmpty) {
          throw "Por favor, preencha todos os campos do cartão.";
        }

        await AsaasService.criarAssinaturaProCartao(
          usuarioId: uid,
          nomeCliente: userDb['nome'] ?? '',
          emailCliente: emailUsuario,
          cpfCnpjCliente: cpfCliente,
          dadosCartao: {
            'holderName': _nomeCard.text.trim(),
            'number': _numCard.text.trim(),
            'expiryMonth': _mesCard.text.trim(),
            'expiryYear': _anoCard.text.trim(),
            'ccv': _cvvCard.text.trim(),
          },
        );

        // A confirmação visual do cartão pode ser imediata ou cair na escuta do Webhook reativo
        if (!mounted) return;
        _alerta(
          'Pagamento enviado',
          'Aguarde a confirmação para ativarmos seu acesso PRO.',
          AppColors.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _alerta("Erro", e.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _processandoAssinatura = false);
    }
  }

  void _abrirCheckout() {
    setState(() => _mostrarCheckout = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checkoutContext = _checkoutKey.currentContext;
      if (checkoutContext == null) return;

      Scrollable.ensureVisible(
        checkoutContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  void _alerta(String t, String m, Color c) {
    if (c == AppColors.error) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            t,
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              m,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "FECHAR",
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("$t: $m"), backgroundColor: c));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoStatus) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.proPlatinum),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.proPlatinum,
        backgroundColor: AppColors.card,
        onRefresh: _checarStatusMembro,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _isMembro
                  ? _buildLayoutMembroAtivo()
                  : _buildLayoutPlano(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutMembroAtivo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.proGunmetal, AppColors.proCharcoal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.proSteel.withValues(alpha: 0.65),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.proGunmetal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 48,
                  color: AppColors.proPlatinum,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.45),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ASSINATURA ATIVA',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Você é Atleta PRO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seu status foi confirmado e os benefícios do plano já podem ser reconhecidos pela plataforma.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _tituloSecao('Seu plano'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.autorenew_rounded, color: AppColors.proSilver),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Circuito Fitness PRO mensal',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Status ativo • cobrança recorrente',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'R\$ 19,90',
                style: TextStyle(
                  color: AppColors.proPlatinum,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.proPlatinum,
              foregroundColor: AppColors.proOnPrimary,
            ),
            onPressed: widget.onAbrirDesafios,
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text(
              'EXPLORAR DESAFIOS',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutPlano() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.proGunmetal, AppColors.proCharcoal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.proSteel.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/logo.png',
                  height: 105,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.proGunmetal,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'CIRCUITO FITNESS PRO',
                  style: TextStyle(
                    color: AppColors.proPlatinum,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mais circuito.\nMenos barreiras.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tenha status de atleta PRO e uma experiência centralizada para aproveitar os benefícios do plano nos desafios do circuito.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ 19,90',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 5, left: 5),
                    child: Text(
                      '/mês',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.proPlatinum,
                    foregroundColor: AppColors.proOnPrimary,
                  ),
                  onPressed: _abrirCheckout,
                  child: const Text(
                    'QUERO SER PRO',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Plano mensal recorrente',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (_mostrarCheckout) ...[
          const SizedBox(height: 30),
          _buildCheckoutAssinatura(),
        ],
        const SizedBox(height: 30),
        _tituloSecao('O que você encontra no PRO'),
        const SizedBox(height: 12),
        _beneficio(
          Icons.workspace_premium_outlined,
          'Status de Atleta PRO',
          'Sua conta passa a ser reconhecida como membro do circuito.',
        ),
        const SizedBox(height: 10),
        _beneficio(
          Icons.emoji_events_outlined,
          'Benefícios nos desafios',
          'Use o plano nos desafios contemplados pelo Circuito Fitness Pro.',
        ),
        const SizedBox(height: 10),
        _beneficio(
          Icons.bolt_outlined,
          'Ativação em tempo real',
          'Assim que o pagamento for confirmado, o status atualiza automaticamente.',
        ),
        const SizedBox(height: 30),
        _tituloSecao('Como funciona'),
        const SizedBox(height: 14),
        _passo(1, 'Escolha PIX ou cartão'),
        _passo(2, 'Conclua o pagamento mensal'),
        _passo(3, 'Aguarde a confirmação e aproveite o PRO'),
        const SizedBox(height: 28),
        _tituloSecao('Dúvidas frequentes'),
        const SizedBox(height: 10),
        _faq(
          'O pagamento é recorrente?',
          'Sim. O Circuito Fitness Pro custa R\$ 19,90 por mês e a cobrança é mensal.',
        ),
        _faq(
          'Quando meu PRO é ativado?',
          'A ativação acontece após a confirmação do pagamento. A tela acompanha essa mudança em tempo real.',
        ),
        _faq(
          'As regras dos desafios mudam?',
          'Não. Prazos, pesagens, vídeos e critérios de premiação continuam seguindo as regras de cada desafio.',
        ),
      ],
    );
  }

  Widget _tituloSecao(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _beneficio(IconData icone, String titulo, String descricao) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.proGunmetal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: AppColors.proPlatinum, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descricao,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passo(int numero, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.proPlatinum,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: AppColors.proOnPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq(String pergunta, String resposta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        iconColor: AppColors.proSilver,
        collapsedIconColor: AppColors.textMuted,
        shape: const RoundedRectangleBorder(),
        title: Text(
          pergunta,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              resposta,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutAssinatura() {
    return Container(
      key: _checkoutKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.proSteel.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finalizar assinatura',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Circuito Fitness Pro • R\$ 19,90/mês',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar checkout',
                onPressed: () => setState(() => _mostrarCheckout = false),
                icon: const Icon(Icons.close, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_qrCodeBase64 == null) ...[
            Row(
              children: [
                Expanded(child: _botaoAba('PIX', Icons.pix)),
                const SizedBox(width: 10),
                Expanded(child: _botaoAba('CARD', Icons.credit_card)),
              ],
            ),
            const SizedBox(height: 20),
            if (_metodoSelecionatedCard()) _buildFormCartao(),
            if (!_metodoSelecionatedCard())
              const Text(
                'O QR Code será exibido aqui. Após o pagamento, aguarde a confirmação automática.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.proPlatinum,
                  foregroundColor: AppColors.proOnPrimary,
                ),
                onPressed: _processandoAssinatura ? null : _assinarPlanoPro,
                child: _processandoAssinatura
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.proOnPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _metodoSelecionatedCard()
                            ? 'ASSINAR COM CARTÃO'
                            : 'GERAR PIX',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Cobrança mensal recorrente de R\$ 19,90',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const Text(
                    'Escaneie para pagar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.memory(
                      base64Decode(_qrCodeBase64!),
                      width: 200,
                      height: 200,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text(
                        'COPIAR PIX COPIA E COLA',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.proPlatinum,
                        side: const BorderSide(color: AppColors.proSilver),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _pixCode ?? ''));
                        _alerta(
                          'Copiado',
                          'Código Pix copiado para a área de transferência.',
                          AppColors.success,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A tela será atualizada quando o pagamento for confirmado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _metodoSelecionatedCard() => _metodoSelecionado == 'CARD';

  Widget _botaoAba(String id, IconData ico) {
    final sel = _metodoSelecionado == id;
    return ElevatedButton.icon(
      icon: Icon(ico, size: 16),
      label: Text(id == 'CARD' ? 'CARTÃO' : id),
      style: ElevatedButton.styleFrom(
        backgroundColor: sel ? AppColors.proPlatinum : Colors.white10,
        foregroundColor: sel ? AppColors.proOnPrimary : Colors.white70,
      ),
      onPressed: () => setState(() => _metodoSelecionado = id),
    );
  }

  Widget _buildFormCartao() {
    return Column(
      children: [
        _input(_nomeCard, "Nome no Cartão", Icons.person),
        const SizedBox(height: 12),
        _input(
          _numCard,
          "Número do Cartão",
          Icons.credit_card,
          tecladoNumerico: true,
          tamanhoMaximo: 19,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _input(
                _mesCard,
                "Mês (MM)",
                Icons.calendar_today,
                tecladoNumerico: true,
                tamanhoMaximo: 2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _input(
                _anoCard,
                "Ano (AAAA)",
                Icons.calendar_today,
                tecladoNumerico: true,
                tamanhoMaximo: 4,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _input(
                _cvvCard,
                "CVV",
                Icons.lock,
                tecladoNumerico: true,
                tamanhoMaximo: 4,
                ocultarTexto: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController c,
    String l,
    IconData i, {
    bool tecladoNumerico = false,
    int? tamanhoMaximo,
    bool ocultarTexto = false,
  }) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      keyboardType: tecladoNumerico ? TextInputType.number : TextInputType.text,
      obscureText: ocultarTexto,
      inputFormatters: tecladoNumerico
          ? [
              FilteringTextInputFormatter.digitsOnly,
              if (tamanhoMaximo != null)
                LengthLimitingTextInputFormatter(tamanhoMaximo),
            ]
          : null,
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, color: AppColors.proSilver, size: 18),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
