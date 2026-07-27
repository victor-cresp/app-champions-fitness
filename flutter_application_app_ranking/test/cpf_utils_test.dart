import 'package:flutter_application_app_ranking/core/cpf_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarCpf', () {
    test('preserva o zero inicial de um CPF com 11 dígitos', () {
      expect(normalizarCpf('01234567890'), '01234567890');
    });

    test('restaura o zero inicial perdido em um CPF histórico', () {
      expect(normalizarCpf('1234567890'), '01234567890');
    });

    test('remove a formatação sem converter o CPF para número', () {
      expect(normalizarCpf('012.345.678-90'), '01234567890');
    });

    test('rejeita CPF vazio, longo ou com dígitos verificadores inválidos', () {
      expect(() => normalizarCpf(''), throwsFormatException);
      expect(() => normalizarCpf('123456789012'), throwsFormatException);
      expect(() => normalizarCpf('09131852702'), throwsFormatException);
    });
  });

  group('cpfValido', () {
    test('aceita CPF com zero à esquerda e dígitos verificadores válidos', () {
      expect(cpfValido('01234567890'), isTrue);
    });

    test('rejeita sequência repetida', () {
      expect(cpfValido('00000000000'), isFalse);
    });
  });
}
