String normalizarCpf(String cpf) {
  final somenteDigitos = cpf.replaceAll(RegExp(r'\D'), '');

  if (somenteDigitos.isEmpty || somenteDigitos.length > 11) {
    throw const FormatException('CPF inválido.');
  }

  final cpfNormalizado = somenteDigitos.padLeft(11, '0');
  if (!cpfValido(cpfNormalizado)) {
    throw const FormatException('CPF inválido.');
  }

  return cpfNormalizado;
}

bool cpfValido(String cpf) {
  final digitos = cpf.replaceAll(RegExp(r'\D'), '');
  if (digitos.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digitos)) {
    return false;
  }

  for (var posicao = 9; posicao <= 10; posicao++) {
    var soma = 0;
    for (var indice = 0; indice < posicao; indice++) {
      soma += int.parse(digitos[indice]) * (posicao + 1 - indice);
    }

    final resto = (soma * 10) % 11;
    final verificador = resto == 10 ? 0 : resto;
    if (verificador != int.parse(digitos[posicao])) {
      return false;
    }
  }

  return true;
}
