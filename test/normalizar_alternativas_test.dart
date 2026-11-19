import 'package:flutter_test/flutter_test.dart';

import '../integration_test/migracoes/normalizar_alternativas.dart';

void main() {
  group('normalizarAlternativas', () {
    test('troca "correta" por "isCorreta" e mantém o texto', () {
      final r = normalizarAlternativas([
        {'texto': '3', 'correta': false},
        {'texto': '4', 'correta': true},
      ]);

      expect(r.problema, isNull);
      expect(r.alterada, isTrue);
      expect(r.corretas, 1);
      expect(r.alternativas, [
        {'texto': '3', 'isCorreta': false},
        {'texto': '4', 'isCorreta': true},
      ]);
    });

    test('questão já no formato certo não é regravada', () {
      final r = normalizarAlternativas([
        {'texto': 'a', 'isCorreta': true},
        {'texto': 'b', 'isCorreta': false},
      ]);

      expect(r.alterada, isFalse);
      expect(r.corretas, 1);
    });

    test('converte texto e número para booleano', () {
      final r = normalizarAlternativas([
        {'texto': 'a', 'correta': 'True'},
        {'texto': 'b', 'isCorreta': 'false'},
        {'texto': 'c', 'correta': 0},
      ]);

      expect(r.problema, isNull);
      expect(r.alterada, isTrue);
      expect(r.alternativas.map((a) => a['isCorreta']), [true, false, false]);
    });

    test('alternativa sem nenhum dos campos vira isCorreta false', () {
      final r = normalizarAlternativas([
        {'texto': 'a', 'correta': true},
        {'texto': 'b'},
      ]);

      expect(r.alternativas.last, {'texto': 'b', 'isCorreta': false});
      expect(r.alterada, isTrue);
    });

    test('mesmo valor nos dois campos é aceito e "correta" sai', () {
      final r = normalizarAlternativas([
        {'texto': 'a', 'correta': true, 'isCorreta': true},
      ]);

      expect(r.problema, isNull);
      expect(r.alternativas.single, {'texto': 'a', 'isCorreta': true});
    });

    test('valores diferentes nos dois campos não são gravados', () {
      final r = normalizarAlternativas([
        {'texto': 'a', 'correta': true, 'isCorreta': false},
      ]);

      expect(r.problema, contains('diferentes'));
      expect(r.alterada, isFalse);
    });

    test('valor não reconhecido não é gravado', () {
      final r = normalizarAlternativas([
        {'texto': 'a', 'correta': 'sim'},
      ]);

      expect(r.problema, contains('sim'));
      expect(r.alterada, isFalse);
    });

    test('sem alternativas é reportado', () {
      expect(normalizarAlternativas(null).problema, isNotNull);
      expect(normalizarAlternativas('x').problema, isNotNull);
    });

    test('conta quantas ficaram corretas', () {
      final nenhuma = normalizarAlternativas([
        {'texto': 'a', 'correta': false},
        {'texto': 'b', 'correta': false},
      ]);
      expect(nenhuma.corretas, 0);
    });
  });
}
