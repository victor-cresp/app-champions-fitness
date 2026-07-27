import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/supabase_client.dart';
import 'core/app_theme.dart';
import 'core/cpf_utils.dart';

/// Service para integração com Asaas via Supabase Edge Function
class AsaasService {
  /// Cria um pagamento PIX via Asaas para inscrição em desafio
  static Future<Map<String, dynamic>> criarPagamentoPix({
    required String usuarioId,
    required String nomeCliente,
    required String emailCliente,
    required String cpfCnpjCliente,
    required double valorDesafio,
    required String nomeDesafio,
    required String desafioId,
    required String inscricaoId,
  }) async {
    final cpfNormalizado = normalizarCpf(cpfCnpjCliente);

    final response = await supabase.functions.invoke(
      'asaas-pagamento-desafio',
      body: {
        'usuarioId': usuarioId,
        'nomeCliente': nomeCliente,
        'emailCliente': emailCliente,
        'cpfCnpjCliente': cpfNormalizado,
        'formaPagamento': 'PIX',
        'valorDesafio': valorDesafio,
        'nomeDesafio': nomeDesafio,
        'desafioId': desafioId,
        'inscricaoId': inscricaoId,
      },
    );

    if (response.status == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data;
      } else {
        throw data['error'] ?? 'Erro ao gerar PIX no Asaas.';
      }
    }
    throw 'Falha ao conectar com o servidor de pagamentos.';
  }

  /// Cria um pagamento via Cartão de Crédito no Asaas para inscrição em desafio
  static Future<Map<String, dynamic>> criarPagamentoCartao({
    required String usuarioId,
    required String nomeCliente,
    required String emailCliente,
    required String cpfCnpjCliente,
    required double valorDesafio,
    required String nomeDesafio,
    required String desafioId,
    required String inscricaoId,
    required Map<String, dynamic> dadosCartao,
    int parcelas = 1,
  }) async {
    final cpfNormalizado = normalizarCpf(cpfCnpjCliente);

    final response = await supabase.functions.invoke(
      'asaas-pagamento-desafio',
      body: {
        'usuarioId': usuarioId,
        'nomeCliente': nomeCliente,
        'emailCliente': emailCliente,
        'cpfCnpjCliente': cpfNormalizado,
        'formaPagamento': 'CREDIT_CARD',
        'valorDesafio': valorDesafio,
        'nomeDesafio': nomeDesafio,
        'desafioId': desafioId,
        'inscricaoId': inscricaoId,
        'cartao': dadosCartao,
        'parcelas': parcelas,
      },
    );

    if (response.status == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data;
      } else {
        throw data['error'] ?? 'Erro ao processar cartão no Asaas.';
      }
    }
    throw 'Falha ao conectar com o servidor de pagamentos.';
  }

  /// Cria pagamento PIX para assinatura PRO (CLIENTE PRO)
  static Future<Map<String, dynamic>> criarAssinaturaProPix({
    required String usuarioId,
    required String nomeCliente,
    required String emailCliente,
    required String cpfCnpjCliente,
  }) async {
    final cpfNormalizado = normalizarCpf(cpfCnpjCliente);

    final response = await supabase.functions.invoke(
      'asaas-assinatura-pro',
      body: {
        'usuarioId': usuarioId,
        'nomeCliente': nomeCliente,
        'emailCliente': emailCliente,
        'cpfCnpjCliente': cpfNormalizado,
        'formaPagamento': 'PIX',
      },
    );

    if (response.status == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data;
      } else {
        throw data['error'] ?? 'Erro ao gerar PIX da assinatura PRO.';
      }
    }
    throw 'Falha ao conectar com o servidor de pagamentos.';
  }

  /// Cria pagamento via Cartão para assinatura PRO
  static Future<Map<String, dynamic>> criarAssinaturaProCartao({
    required String usuarioId,
    required String nomeCliente,
    required String emailCliente,
    required String cpfCnpjCliente,
    required Map<String, dynamic> dadosCartao,
  }) async {
    final cpfNormalizado = normalizarCpf(cpfCnpjCliente);

    final response = await supabase.functions.invoke(
      'asaas-assinatura-pro',
      body: {
        'usuarioId': usuarioId,
        'nomeCliente': nomeCliente,
        'emailCliente': emailCliente,
        'cpfCnpjCliente': cpfNormalizado,
        'formaPagamento': 'CREDIT_CARD',
        "phone": "21999999999",
        'cartao': dadosCartao,
      },
    );

    if (response.status == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data;
      } else {
        throw data['error'] ?? 'Erro ao processar cartão da assinatura PRO.';
      }
    }
    throw 'Falha ao conectar com o servidor de pagamentos.';
  }

  /// Copia o código PIX para a área de transferência
  static void copiarPix(String codigoPix, BuildContext context) {
    Clipboard.setData(ClipboardData(text: codigoPix));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📋 Código PIX copiado!"),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
