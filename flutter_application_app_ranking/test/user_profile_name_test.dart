import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_app_ranking/services/user_profile_name.dart';

void main() {
  group('nomeNosMetadadosAuth', () {
    test('prioriza o nome usado no cadastro tradicional', () {
      final nome = nomeNosMetadadosAuth({
        'nome': 'Maria Silva',
        'full_name': 'Outro Nome',
      });

      expect(nome, 'Maria Silva');
    });

    test('aceita o full_name enviado pelo Google', () {
      final nome = nomeNosMetadadosAuth({'full_name': 'João Souza'});

      expect(nome, 'João Souza');
    });

    test('ignora valores vazios e procura a próxima alternativa', () {
      final nome = nomeNosMetadadosAuth({
        'nome': '  ',
        'full_name': '',
        'name': 'Ana Lima',
      });

      expect(nome, 'Ana Lima');
    });
  });

  group('primeiroNomeOuAtleta', () {
    test('retorna apenas o primeiro nome', () {
      expect(primeiroNomeOuAtleta('  Carlos   Andrade  '), 'Carlos');
    });

    test('usa Atleta quando não há nome', () {
      expect(primeiroNomeOuAtleta(null), 'Atleta');
      expect(primeiroNomeOuAtleta('   '), 'Atleta');
    });
  });
}
