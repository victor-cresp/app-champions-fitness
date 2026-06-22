import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/supabase_client.dart';

class TelaMembro extends StatefulWidget {
  const TelaMembro({super.key});

  @override
  State<TelaMembro> createState() => _TelaMembroState();
}

class _TelaMembroState extends State<TelaMembro> {
  bool _carregandoStatus = true;
  bool _isMembro = false;
  bool _processandoAssinatura = false;

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
  }

  Future<void> _checarStatusMembro() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final dados = await supabase.from('usuarios').select('is_membro').eq('id', uid).single();
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
      final userDb = await supabase.from('usuarios').select('nome, cpf').eq('id', uid).single();

      final payload = {
        'usuarioId': uid,
        'nomeCliente': userDb['nome'],
        'cpfCnpjCliente': userDb['cpf'],
        'formaPagamento': _metodoSelecionado == 'PIX' ? 'PIX' : 'CREDIT_CARD',
      };

      if (_metodoSelecionado == 'CARD') {
        payload['cartao'] = {
          'holderName': _nomeCard.text.trim(),
          'number': _numCard.text.trim(),
          'expiryMonth': _mesCard.text.trim(),
          'expiryYear': _anoCard.text.trim(),
          'ccv': _cvvCard.text.trim()
        };
      }

      final response = await supabase.functions.invoke('processar-assinatura', body: payload);
      final resData = response.data as Map<String, dynamic>;

      if (response.status == 200 && resData['success'] == true) {
        if (_metodoSelecionado == 'PIX') {
          setState(() {
            _pixCode = resData['pixCopiaECola'];
            _qrCodeBase64 = resData['pixQrCodeBase64'];
            _processandoAssinatura = false;
          });
        } else {
          setState(() {
            _isMembro = true;
            _processandoAssinatura = false;
          });
          _alerta("PRO Ativado!", "Você agora é um Atleta PRO oficial.", Colors.green);
        }
      } else {
        throw resData['error'] ?? 'Erro no gateway.';
      }
    } catch (e) {
      setState(() => _processandoAssinatura = false);
      _alerta("Erro", e.toString(), Colors.redAccent);
    }
  }

  void _alerta(String t, String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$t: $m"), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoStatus) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: _isMembro ? _buildLayoutMembroAtivo() : _buildLayoutCheckout(),
      ),
    );
  }

  Widget _buildLayoutMembroAtivo() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.verified, size: 90, color: Colors.greenAccent),
          const SizedBox(height: 24),
          // 🚀 CORRIGIDO: Alterado de FontWeight.black para FontWeight.w900
          const Text("VOCÊ É ATLETA PRO ⚡", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text("Sua assinatura está ativa. Suas inscrições em todos os desafios do aplicativo estão liberadas!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLayoutCheckout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("EVOLUA PARA O", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
        const Text("CHAMPIONS PRO ⚡", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
        const SizedBox(height: 12),
        const Text(
          "Não assista de fora. Torne-se membro oficial do circuito, destrave o direito de participar de todos os desafios da plataforma e dispute os maiores potes da comunidade!",
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Plano Mensal Recorrente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text("R\$ 29,90/mês", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (_qrCodeBase64 == null) ...[
          Row(
            children: [
              Expanded(child: _botaoAba('PIX', Icons.pix)),
              const SizedBox(width: 12),
              Expanded(child: _botaoAba('CARD', Icons.credit_card)),
            ],
          ),
          const SizedBox(height: 24),
          if (_metodoSelecionatedCard()) _buildFormCartao(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade400),
              onPressed: _processandoAssinatura ? null : _assinarPlanoPro,
              child: _processandoAssinatura 
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text("ATIVAR MEMBRO PRO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ] else ...[
          Center(
            child: Column(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Image.memory(base64Decode(_qrCodeBase64!), width: 200, height: 200)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy, color: Colors.black),
                  label: const Text("COPIAR PIX COPIA E COLA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _pixCode ?? ''));
                    _alerta("Copiado", "Código do Pix na área de transferência", Colors.green);
                  },
                ),
              ],
            ),
          )
        ]
      ],
    );
  }

  bool _metodoSelecionatedCard() => _metodoSelecionado == 'CARD';

  Widget _botaoAba(String id, IconData ico) {
    final sel = _metodoSelecionado == id;
    return ElevatedButton.icon(
      icon: Icon(ico, size: 16), label: Text(id),
      style: ElevatedButton.styleFrom(backgroundColor: sel ? Colors.greenAccent.shade400 : Colors.white10, foregroundColor: sel ? Colors.black : Colors.white70),
      onPressed: () => setState(() => _metodoSelecionado = id),
    );
  }

  Widget _buildFormCartao() {
    return Column(
      children: [
        _input(_nomeCard, "Nome no Cartão", Icons.person),
        const SizedBox(height: 12),
        _input(_numCard, "Número do Cartão", Icons.credit_card),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _input(_mesCard, "Mês (MM)", Icons.calendar_today)),
            const SizedBox(width: 8),
            Expanded(child: _input(_anoCard, "Ano (AAAA)", Icons.calendar_today)),
            const SizedBox(width: 8),
            Expanded(child: _input(_cvvCard, "CVV", Icons.lock)),
          ],
        )
      ],
    );
  }

  Widget _input(TextEditingController c, String l, IconData i) {
    return TextFormField(
      controller: c, style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: l, prefixIcon: Icon(i, color: Colors.greenAccent, size: 18),
        filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}