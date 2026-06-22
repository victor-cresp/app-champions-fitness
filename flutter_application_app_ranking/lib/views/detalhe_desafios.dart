import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../core/supabase_client.dart';               
import 'dart:typed_data'; 

// ==========================================
// TELA 1: DETALHES COMPLETOS DO DESAFIO
// ==========================================
class TelaDetalhesDesafio extends StatelessWidget {
  final Map<String, dynamic> inscricaoData;
  final Map<String, dynamic> desafioData;

  const TelaDetalhesDesafio({
    super.key, 
    required this.inscricaoData, 
    required this.desafioData
  });

  @override
  Widget build(BuildContext context) {
    final String titulo = desafioData['nome'] ?? 'Detalhes do Desafio';
    final String descricao = desafioData['descricao'] ?? 'Sem descrição disponível.';
    final double valor = double.tryParse(desafioData['valor_entrada']?.toString() ?? '') ?? 0.0;
    
    final dataInicio = DateTime.tryParse(desafioData['data_inicio'] ?? '') ?? DateTime.now();
    final dataFim = DateTime.tryParse(desafioData['data_fim'] ?? '') ?? DateTime.now();
    final String inicioFormatado = "${dataInicio.day.toString().padLeft(2, '0')}/${dataInicio.month.toString().padLeft(2, '0')}/${dataInicio.year}";
    final String fimFormatado = "${dataFim.day.toString().padLeft(2, '0')}/${dataFim.month.toString().padLeft(2, '0')}/${dataFim.year}";

    final String statusPagamento = inscricaoData['status_pagamento'] ?? 'pendente';
    final String statusVideo = inscricaoData['status_video'] ?? 'nao_enviado';

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
                  onPressed: () {},
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
                          inscricaoId: inscricaoData['id']?.toString() ?? '',
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


// ==========================================
// TELA 2: INSTRUÇÕES E CAPTURA EM VÍDEO AO VIVO
// ==========================================
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
    const palavras = ['CHAMP', 'FORCA', 'BALANCA', 'FOCO', 'TREINO', 'FITNESS', 'PUMP'];
    final random = Random();
    final numero = random.nextInt(900) + 100; 
    return "${palavras[random.nextInt(palavras.length)]}$numero";
  }

  // 🚀 Modificado: Agora grava estritamente da Câmera (Ao Vivo)
  Future<void> _capturarVideoAoVivo(int tipoVideo, Duration limiteTempo) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera, // 👈 Bloqueado apenas para gravação ao vivo
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
      print("DEBUG 1: Iniciando processo de envio...");
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw "Usuário não autenticado";

      final agora = DateTime.now();
      final dataFormatada = "${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}";
      
      final caminhoBase = "checagem_peso/videos/$dataFormatada";
      final nomeVideoRosto = "$caminhoBase/${widget.inscricaoId}_rosto_${agora.millisecondsSinceEpoch}.mp4";
      final nomeVideoPeso = "$caminhoBase/${widget.inscricaoId}_peso_${agora.millisecondsSinceEpoch}.mp4";

      print("DEBUG 2: Lendo bytes dos vídeos...");
      // Lendo os bytes convertendo explicitamente para garantir compatibilidade Web
      final bytesRosto = Uint8List.fromList(await _videoRosto!.readAsBytes());
      final bytesPeso = Uint8List.fromList(await _videoPeso!.readAsBytes());

      print("DEBUG 3: Bytes lidos. Iniciando upload para o Storage...");
      final bucket = supabase.storage.from('avatars');
      
      await bucket.uploadBinary(
        nomeVideoRosto, 
        bytesRosto, 
        fileOptions: const FileOptions(contentType: 'video/mp4')
      );
      print("DEBUG 4: Vídeo do Rosto enviado com sucesso!");

      await bucket.uploadBinary(
        nomeVideoPeso, 
        bytesPeso, 
        fileOptions: const FileOptions(contentType: 'video/mp4')
      );
      print("DEBUG 5: Vídeo do Peso enviado com sucesso!");

      // Gerando as URLs públicas
      final urlRosto = bucket.getPublicUrl(nomeVideoRosto);
      final urlPeso = bucket.getPublicUrl(nomeVideoPeso);
      print("DEBUG 6: URLs obtidas -> Rosto: $urlRosto | Peso: $urlPeso");

      print("DEBUG 7: Enviando comando de UPDATE para a tabela participantes_apostas (ID: ${widget.inscricaoId})...");
      
      // Criamos o mapa explicitamente para garantir que chaves batam com as colunas do banco
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

      print("DEBUG 8: UPDATE concluído no banco de dados com sucesso!");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 Vídeos enviados com sucesso para análise!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e, stacktrace) {
      print("❌ ERRO CAPTURADO NO FLUXO: $e");
      print("STACKTRACE DO ERRO: $stacktrace");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro no envio dos vídeos: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // 🚀 Modificado: Botão único de largura total focado em abrir a câmera
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
          
          // Botão único focado em captura ao vivo
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

                  // 🚀 VÍDEO 1: Ajustado para 3s e novas regras escritas
                  _buildBlocoUpload(
                    titulo: "VÍDEO 1: Rosto + Papel",
                    instrucao: "Grave um vídeo segurando o papel com a palavra escrita mostrando seu rosto de no máximo 3 segundos.",
                    tipoVideo: 1,
                    tempoLimite: const Duration(seconds: 3),
                    videoArquivo: _videoRosto,
                  ),

                  // 🚀 VÍDEO 2: Ajustado para 5s e novas regras escritas
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
                      onPressed: (_videoRosto != null && _videoPeso != null && !_enviando) ? _finalizarEnvio : null,
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