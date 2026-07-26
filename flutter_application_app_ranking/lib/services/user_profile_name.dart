const _chavesNomeAuth = [
  'nome',
  'full_name',
  'name',
  'display_name',
  'given_name',
];

String? nomeNosMetadadosAuth(Map<String, dynamic>? metadados) {
  if (metadados == null) return null;

  for (final chave in _chavesNomeAuth) {
    final nome = metadados[chave]?.toString().trim();
    if (nome != null && nome.isNotEmpty) {
      return nome;
    }
  }

  return null;
}

String primeiroNomeOuAtleta(String? nomeCompleto) {
  final nome = nomeCompleto?.trim();
  if (nome == null || nome.isEmpty) {
    return 'Atleta';
  }

  return nome.split(RegExp(r'\s+')).first;
}
