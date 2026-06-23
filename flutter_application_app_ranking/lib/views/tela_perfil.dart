import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/supabase_client.dart';
import '../core/app_theme.dart';

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  
  String? _fotoUrl;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosPerfil();
  }

  // 1. Busca os dados da sua tabela existente 'usuarios'
  Future<void> _carregarDadosPerfil() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final dados = await supabase
          .from('usuarios')
          .select('nome, descricao, foto_url')
          .eq('id', uid)
          .single();

      setState(() {
        _nomeController.text = dados['nome'] ?? '';
        _descricaoController.text = dados['descricao'] ?? '';
        _fotoUrl = dados['foto_url'];
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      _mostrarMensagem("Erro ao carregar perfil: $e", Colors.redAccent);
    }
  }

  // 2. Abre a galeria, faz upload da foto para o Storage e atualiza o link
// 2. Abre a galeria, lê os bytes (funciona em celular e web) e faz o upload
  Future<void> _alterarFotoPerfil() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final picker = ImagePicker();
    final XFile? imagemSelecionada = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compacta a imagem para o upload voar
    );

    if (imagemSelecionada == null) return; // Usuário desistiu de escolher a foto

    setState(() => _salvando = true);

    try {
      final nomeArquivo = '$uid/perfil.jpg';

      // 🛠️ A MÁGICA AQUI: Lemos os bytes diretamente do XFile (compatível com Web e Mobile!)
      final byteData = await imagemSelecionada.readAsBytes();

// 🛠️ RESOLVIDO: Enviamos apenas o nome do arquivo e os bytes.
      // O Supabase cuida do resto automaticamente sem precisar de classes extras!
      await supabase.storage.from('avatars').uploadBinary(
            nomeArquivo,
            byteData,
          );

      // Pega a URL pública gerada no Supabase
      final String urlPublica = supabase.storage.from('avatars').getPublicUrl(nomeArquivo);

      // Atualiza na sua tabela de usuários
      await supabase.from('usuarios').update({'foto_url': urlPublica}).eq('id', uid);

      setState(() {
        _fotoUrl = urlPublica;
        _salvando = false;
      });
      _mostrarMensagem("Foto de perfil atualizada!", Colors.green);
    } catch (e) {
      setState(() => _salvando = false);
      _mostrarMensagem("Erro ao enviar foto: $e", Colors.redAccent);
    }
  }

  // 3. Salva as alterações de Nome e Descrição
  Future<void> _salvarDados() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _salvando = true);

    try {
      await supabase.from('usuarios').update({
        'nome': _nomeController.text.trim(),
        'descricao': _descricaoController.text.trim(),
      }).eq('id', uid);

      setState(() => _salvando = false);
      _mostrarMensagem("Perfil atualizado com sucesso!", Colors.green);
    } catch (e) {
      setState(() => _salvando = false);
      _mostrarMensagem("Erro ao salvar dados: $e", Colors.redAccent);
    }
  }

  void _mostrarMensagem(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 🚀 FOTO DE PERFIL REDONDA E INTERATIVA
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.white10,
                    backgroundImage: _fotoUrl != null ? NetworkImage(_fotoUrl!) : null,
                    child: _fotoUrl == null
                        ? const Icon(Icons.person, size: 65, color: Colors.white38)
                        : null,
                  ),
                  if (_salvando)
                    const Positioned.fill(
                      child: CircularProgressIndicator(color: Colors.greenAccent),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _salvando ? null : _alterarFotoPerfil,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.greenAccent.shade400,
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // Campo Nome
            TextFormField(
              controller: _nomeController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Nome do Atleta", Icons.person_outline),
            ),
            
            const SizedBox(height: 20),

            // Campo Descrição
            TextFormField(
              controller: _descricaoController,
              maxLines: 3, // Deixa o campo maior para caber textos longos
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Sua Descrição / Frase de Treino", Icons.chat_bubble_outline),
            ),
            
            const SizedBox(height: 32),

            // Botão Salvar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarDados,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        "SALVAR ALTERAÇÕES",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData iconData) {
    return buildInputDecoration(label: label, icon: iconData)
      .copyWith(
        icon: Icon(iconData, color: AppColors.primary),
        fillColor: Colors.white.withValues(alpha: 0.05),
      );
  }
}