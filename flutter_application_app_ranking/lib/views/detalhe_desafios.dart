import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/app_theme.dart';
import '../core/date_utils.dart';

class TelaDetalhesDesafio extends StatefulWidget {
  final Map<String, dynamic> inscricaoData;
  final Map<String, dynamic> desafioData;

  const TelaDetalhesDesafio({
    super.key, 
    required this.inscricaoData, 
    required this.desafioData
  });

  @override
  State<TelaDetalhesDesafio> createState() => _TelaDetalhesDesafioState();
}

class _TelaDetalhesDesafioState extends State<TelaDetalhesDesafio> {
  bool _processandoPagamento = false;

  final _nomeCartaoController = TextEditingController();
  final _numeroCartaoController = TextEditingController();
  final _mesCartaoController = TextEditingController();
  final _anoCartaoController = TextEditingController();
  final _cvvCartaoController = TextEditingController();

  @override
  void dispose() {
    _nomeCartaoController.dispose();
    _numeroCartaoController.dispose();
    _mesCartaoController.dispose();
    _anoCartaoController.dispose();
    _cvvCartaoController.dispose();
    super.dispose();
  }

  Future<void> _processarPagamentoTransparente({
    required String formaPagamento,
    Map<String, dynamic>? dadosCartao,
    required StateSetter setModalState,
  }) async {
    final usuarioAtual = supabase.auth.currentUser;
    if (usuarioAtual == null) return;

    setModalState(() => _processandoPagamento = true);

    try {
      final dadosUsuario = await supabase
          .from('usuarios')
          .select('nome, cpf')
          .eq('id', usuarioAtual.id)
          .single();

      final nomeDoBanco = dadosUsuario['nome'] ?? '';
      final cpfDoBanco = dadosUsuario['cpf'] ?? '';

      if (cpfDoBanco.isEmpty || nomeDoBanco.isEmpty) {
        throw "Seu cadastro está incompleto. Por favor, atualize seu Nome e CPF no Perfil antes de pagar.";
      }

      final double valorDoDesafio = double.tryParse(widget.desafioData['valor_entrada']?.toString() ?? '') ?? 0.0;
      final String nomeDoDesafio = widget.desafioData['nome'] ?? 'Desafio';

      final Map<String, dynamic> bodyPayload = {
        'usuarioId': usuarioAtual.id,
        'nomeCliente': nomeDoBanco,
        'cpfCnpjCliente': cpfDoBanco,
        'formaPagamento': formaPagamento,
        'valorDesafio': valorDoDesafio, 
        'nomeDesafio': nomeDoDesafio,   
      };

      if (formaPagamento == 'CREDIT_CARD' && dadosCartao != null) {
        bodyPayload['cartao'] = dadosCartao;
      }

      final response = await supabase.functions.invoke(
        'criar-link-assinatura', 
        body: bodyPayload,
      );

      if (response.status == 200 && response.data != null) {
        final mapaDados = response.data as Map<String, dynamic>;
        
        if (mapaDados['success'] == true) {
          if (formaPagamento == 'PIX') {
            setModalState(() {
              _processandoPagamento = false;
              dadosCartao?['pixCopiaECola'] = mapaDados['pixCopiaECola'];
              dadosCartao?['pixQrCodeBase64'] = mapaDados['pixQrCodeBase64'];
            });
          } else {
            Navigator.pop(context);
            _mostrarSnack("✅ Inscrição confirmada com sucesso via Cartão!", Colors.green);
          }
        } else {
          throw mapaDados['error'] ?? 'Erro no processamento do Asaas.';
        }
      } else {
        throw 'Falha ao conectar com o servidor de pagamentos.';
      }
    } catch (e) {
      setModalState(() => _processandoPagamento = false);
      _mostrarSnack("❌ Erro: $e", Colors.redAccent);
    }
  }

  void _mostrarSnack(String msg, Color col) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: col));
  }

  void _abrirModalPagamento() {
    String metodoAbas = 'PIX'; 
    String? pixStringCopiaECola;
    String? qrCodeBase64;

    final double valorExibicao = double.tryParse(widget.desafioData['valor_entrada']?.toString() ?? '') ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),
                    const Text("Escolha a Forma de Pagamento", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    if (qrCodeBase64 == null)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.pix, size: 18),
                              label: const Text("PIX"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: metodoAbas == 'PIX' ? Colors.greenAccent.shade400 : Colors.white10,
                                foregroundColor: metodoAbas == 'PIX' ? Colors.black : Colors.white70,
                              ),
                              onPressed: () => setModalState(() => metodoAbas = 'PIX'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.credit_card, size: 18),
                              label: const Text("Cartão"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: metodoAbas == 'CARD' ? Colors.greenAccent.shade400 : Colors.white10,
                                foregroundColor: metodoAbas == 'CARD' ? Colors.black : Colors.white70,
                              ),
                              onPressed: () => setModalState(() => metodoAbas = 'CARD'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    if (metodoAbas == 'PIX') ...[
                      if (qrCodeBase64 == null) ...[
                        Text(
                          "A taxa de inscrição para este desafio será gerada no valor de R\$ ${valorExibicao.toStringAsFixed(2)}. O código Pix expira em 24h.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade400),
                            onPressed: _processandoPagamento ? null : () async {
                              final Map<String, dynamic> pixContainer = {};
                              await _processarPagamentoTransparente(
                                formaPagamento: 'PIX',
                                dadosCartao: pixContainer,
                                setModalState: setModalState,
                              );
                              setModalState(() {
                                pixStringCopiaECola = pixContainer['pixCopiaECola'];
                                qrCodeBase64 = pixContainer['pixQrCodeBase64'];
                              });
                            },
                            child: _processandoPagamento 
                                ? const CircularProgressIndicator(color: Colors.black)
                                : const Text("GERAR QR CODE PIX", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Image.memory(base64Decode(qrCodeBase64!), width: 200, height: 200),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.copy, color: Colors.black),
                          label: const Text("COPIAR PIX COPIA E COLA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: pixStringCopiaECola ?? ''));
                            _mostrarSnack("📋 Código Copiado!", Colors.green);
                          },
                        ),
                      ]
                    ],

                    if (metodoAbas == 'CARD') ...[
                      TextFormField(
                        controller: _nomeCartaoController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputModalDecoration("Nome impresso no Cartão", Icons.person_outline),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _numeroCartaoController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputModalDecoration("Número do Cartão", Icons.credit_card_outlined),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mesCartaoController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputModalDecoration("Mês (MM)", Icons.calendar_today),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _anoCartaoController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputModalDecoration("Ano (AAAA)", Icons.calendar_today),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _cvvCartaoController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputModalDecoration("CVV", Icons.lock_outline),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade400),
                          onPressed: _processandoPagamento ? null : () {
                            if (_nomeCartaoController.text.isEmpty || _numeroCartaoController.text.isEmpty || _cvvCartaoController.text.isEmpty) {
                              _mostrarSnack("Preencha todos os campos do cartão.", Colors.orangeAccent);
                              return;
                            }
                            _processarPagamentoTransparente(
                              formaPagamento: 'CREDIT_CARD',
                              setModalState: setModalState,
                              dadosCartao: {
                                'holderName': _nomeCartaoController.text.trim(),
                                'number': _numeroCartaoController.text.trim(),
                                'expiryMonth': _mesCartaoController.text.trim(),
                                'expiryYear': _anoCartaoController.text.trim(),
                                'ccv': _cvvCartaoController.text.trim()
                              }
                            );
                          },
                          child: _processandoPagamento
                              ? const CircularProgressIndicator(color: Colors.black)
                              : const Text("CONFIRMAR PAGAMENTO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() => _processandoPagamento = false);
    });
  }

  InputDecoration _buildInputModalDecoration(String label, IconData icon) {
    return buildInputDecoration(label: label, icon: icon).copyWith(
      fillColor: Colors.white.withValues(alpha: 0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String titulo = widget.desafioData['nome'] ?? 'Detalhes do Desafio';
    final String descricao = widget.desafioData['descricao'] ?? 'Sem descrição disponível.';
    final double valor = double.tryParse(widget.desafioData['valor_entrada']?.toString() ?? '') ?? 0.0;
    
    final dataInicio = DateTime.tryParse(widget.desafioData['data_inicio'] ?? '') ?? DateTime.now();
    final dataFim = DateTime.tryParse(widget.desafioData['data_fim'] ?? '') ?? DateTime.now();
    final String inicioFormatado = dataInicio.formatted;
    final String fimFormatado = dataFim.formatted;

    final String statusPagamento = widget.inscricaoData['status_pagamento'] ?? 'pendente';
    final String statusVideo = widget.inscricaoData['status_video'] ?? 'nao_enviado';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("VALOR DA INSCRIÇÃO", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    "R\$ ${valor.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text("Período: $inicioFormatado até $fimFormatado", style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("REGRAS E DESCRIÇÃO", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              descricao,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 32),
            
            if (statusPagamento == 'pendente') ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment_outlined, color: Colors.black),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _abrirModalPagamento,
                  label: const Text("EFETUAR PAGAMENTO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (statusVideo == 'nao_enviado' || statusVideo == 'reprovado')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaInstrucoesVideo(
                          inscricaoId: widget.inscricaoData['id']?.toString() ?? '',
                        ),
                      ),
                    );
                  },
                  label: const Text("ENVIAR VÍDEO DE PESAGEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),

            if (statusVideo == 'em_analise')
              _buildCardAviso("Vídeo em Análise ⏳", "Nossa equipe está avaliando seus vídeos de pesagem. Fique atento!", Colors.blueAccent),
            if (statusVideo == 'aprovado')
              _buildCardAviso("Pesagem Homologada! ✅", "Seus vídeos foram aprovados com sucesso. Bom desafio!", Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAviso(String titulo, String sub, Color col) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class TelaInstrucoesVideo extends StatefulWidget {
  final String inscricaoId;

  const TelaInstrucoesVideo({super.key, required this.inscricaoId});

  @override
  State<TelaInstrucoesVideo> createState() => _TelaInstrucoesVideoState();
}

class _TelaInstrucoesVideoState extends State<TelaInstrucoesVideo> {
  final ImagePicker _picker = ImagePicker();
  bool _enviando = false;
  late String _palavraAleatoria;

  XFile? _videoRosto;
  XFile? _videoPeso;

  @override
  void initState() {
    super.initState();
    _palavraAleatoria = _gerarPalavraAleatoria();
  }

  String _gerarPalavraAleatoria() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _capturarVideoAoVivo(int tipoVideo, Duration limiteTempo) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera, 
        maxDuration: limiteTempo,
      );

      if (video != null) {
        setState(() {
          if (tipoVideo == 1) {
            _videoRosto = video;
          } else {
            _videoPeso = video;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro ao abrir a câmera: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _finalizarEnvio() async {
    if (_videoRosto == null || _videoPeso == null) return;

    setState(() => _enviando = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw "Usuário não autenticado";

      final agora = DateTime.now();
      final dataFormatada = "${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}";
      
      final caminhoBase = "checagem_peso/videos/$dataFormatada";
      final nomeVideoRosto = "$caminhoBase/${widget.inscricaoId}_rosto_${agora.millisecondsSinceEpoch}.mp4";
      final nomeVideoPeso = "$caminhoBase/${widget.inscricaoId}_peso_${agora.millisecondsSinceEpoch}.mp4";

      final bytesRosto = Uint8List.fromList(await _videoRosto!.readAsBytes());
      final bytesPeso = Uint8List.fromList(await _videoPeso!.readAsBytes());

      final bucket = supabase.storage.from('avatars');
      
      await bucket.uploadBinary(
        nomeVideoRosto, 
        bytesRosto, 
        fileOptions: const FileOptions(contentType: 'video/mp4')
      );

      await bucket.uploadBinary(
        nomeVideoPeso, 
        bytesPeso, 
        fileOptions: const FileOptions(contentType: 'video/mp4')
      );

      final urlRosto = bucket.getPublicUrl(nomeVideoRosto);
      final urlPeso = bucket.getPublicUrl(nomeVideoPeso);
      
      final dadosAtualizacao = {
        'status_video': 'em_analise',
        'video_rosto_url': urlRosto, 
        'video_peso_url': urlPeso,
        'codigo_verificacao': _palavraAleatoria,
      };

      await supabase
          .from('participantes_apostas')
          .update(dadosAtualizacao)
          .eq('id', widget.inscricaoId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 Vídeos enviados com sucesso para análise!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro no envio dos vídeos: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _buildBlocoUpload({
    required String titulo,
    required String instrucao,
    required int tipoVideo,
    required Duration tempoLimite,
    required XFile? videoArquivo,
  }) {
    final bool jaPossui = videoArquivo != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: jaPossui ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (jaPossui)
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 4),
                    Text("PRONTO", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(instrucao, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.3)),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.videocam, size: 18, color: Colors.black),
              label: Text(
                jaPossui ? "REGRAVAR VÍDEO (MÁX ${tempoLimite.inSeconds}S)" : "GRAVAR VÍDEO AGORA", 
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: jaPossui ? Colors.white54 : Colors.white, 
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () => _capturarVideoAoVivo(tipoVideo, tempoLimite),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Envio de Pesagem", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _enviando
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hd_outlined, color: Colors.orangeAccent, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "ATENÇÃO: Altere as configurações de gravação da câmera do seu celular para 480p (qualidade baixa) antes de iniciar.",
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        const Text("CÓDIGO OBRIGATÓRIO DO PAPEL", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(_palavraAleatoria, style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildBlocoUpload(
                    titulo: "VÍDEO 1: Rosto + Papel",
                    instrucao: "Grave um vídeo segurando o papel com a palavra escrita mostrando seu rosto de no máximo 3 segundos.",
                    tipoVideo: 1,
                    tempoLimite: const Duration(seconds: 3),
                    videoArquivo: _videoRosto,
                  ),

                  _buildBlocoUpload(
                    titulo: "VÍDEO 2: Peso + Papel",
                    instrucao: "Grave outro vídeo mostrando o seu peso e mostrando sua mão segurando o papel de no máximo 5 segundos.",
                    tipoVideo: 2,
                    tempoLimite: const Duration(seconds: 5),
                    videoArquivo: _videoPeso,
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_videoRosto != null && _videoPeso != null && !_enviando) 
                          ? _finalizarEnvio 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade400,
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "CONCLUIR E ENVIAR GRAVAÇÕES",
                        style: TextStyle(
                          color: (_videoRosto != null && _videoPeso != null) ? Colors.black : Colors.white30,
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
  }
}