import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/features/aluno/data/aluno.dart';
import 'package:gabarito_plus/features/correcao_prova/services/correcao_service.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/geracao_prova/data/embaralhador.dart';
import 'package:gabarito_plus/features/geracao_prova/data/gabarito_lido.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/provas/service/prova_repository.dart';
import 'package:gabarito_plus/features/questoes/data/alternativa.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';
import 'package:gabarito_plus/features/turma/data/turma.dart';

import 'helpers/prova_repository_memoria.dart';

void main() {
  Questao questao(String id, int correta, {int alternativas = 4}) => Questao(
        id: id,
        enunciado: 'Enunciado $id',
        alternativas: [
          for (var i = 0; i < alternativas; i++)
            Alternativa(texto: 'Alt $i', isCorreta: i == correta),
        ],
      );

  Prova provaDeTeste({bool embaralhar = false}) => Prova(
        id: 'K7Q2XM',
        titulo: 'Prova de Teste',
        turma: Turma(
          id: 'turma-1',
          nomeTurma: '3º Ano A',
          listaAlunos: [
            Aluno(id: 'aluno-a', nome: 'Ana', email: '', isAtivo: true),
            Aluno(id: 'aluno-b', nome: 'Bruno', email: '', isAtivo: true),
          ],
          ativa: true,
        ),
        assunto: Assunto(id: 'assunto-1', nome: 'Soma', questoes: const []),
        questoes: [questao('q1', 2), questao('q2', 0, alternativas: 5)],
        embaralharQuestoes: embaralhar,
        embaralharAlternativas: embaralhar,
      );

  group('gerarIdProva', () {
    test('gera 6 caracteres do alfabeto sem caracteres ambíguos', () {
      final random = Random(42);
      for (var i = 0; i < 200; i++) {
        final id = gerarIdProva(random);
        expect(id, hasLength(tamanhoCodigoProva));
        expect(id.split('').every(alfabetoCodigoProva.contains), isTrue);
      }
    });

    test('o alfabeto não tem 0, O, 1, I nem L', () {
      for (final ambiguo in ['0', 'O', '1', 'I', 'L']) {
        expect(alfabetoCodigoProva.contains(ambiguo), isFalse);
      }
    });
  });

  group('Embaralhador', () {
    test('código da versão é o id da prova mais a posição do aluno', () {
      final versoes = Embaralhador.gerarVersoes(provaDeTeste(embaralhar: true));

      expect(versoes.map((v) => v.codigo), ['K7Q2XM-01', 'K7Q2XM-02']);
      expect(versoes.map((v) => v.aluno.nome), ['Ana', 'Bruno']);
    });

    Prova provaComSorteio({
      required int alunos,
      required int banco,
      required int porProva,
      bool embaralhar = true,
    }) =>
        Prova(
          id: 'K7Q2XM',
          titulo: 'Prova Sorteada',
          turma: Turma(
            id: 'turma-1',
            nomeTurma: '3º Ano A',
            listaAlunos: [
              for (var i = 0; i < alunos; i++)
                Aluno(id: 'aluno-$i', nome: 'Aluno $i', email: '', isAtivo: true),
            ],
            ativa: true,
          ),
          assunto: Assunto(id: 'assunto-1', nome: 'Soma', questoes: const []),
          questoes: [for (var i = 0; i < banco; i++) questao('q$i', i % 4)],
          questoesPorProva: porProva,
          embaralharQuestoes: embaralhar,
          embaralharAlternativas: embaralhar,
        );

    test('cada versão sorteia a quantidade pedida, sem repetir questão', () {
      final versoes = Embaralhador.gerarVersoes(
        provaComSorteio(alunos: 30, banco: 12, porProva: 5),
        Random(7),
      );

      for (final versao in versoes) {
        final ids = versao.questoes.map((q) => q.questao.id).toList();
        expect(ids, hasLength(5));
        expect(ids.toSet(), hasLength(5));
      }
    });

    test('o banco é usado de forma equilibrada entre as versões', () {
      final versoes = Embaralhador.gerarVersoes(
        provaComSorteio(alunos: 12, banco: 12, porProva: 4),
        Random(3),
      );

      final usos = <String, int>{};
      for (final q in versoes.expand((v) => v.questoes)) {
        usos.update(q.questao.id, (n) => n + 1, ifAbsent: () => 1);
      }
      // 12 versões x 4 questões = 48 usos para 12 questões: 4 cada, +-1.
      expect(usos.keys, hasLength(12));
      expect(usos.values.every((n) => n >= 3 && n <= 5), isTrue);
    });

    test('versões seguidas recebem questões diferentes', () {
      final versoes = Embaralhador.gerarVersoes(
        provaComSorteio(alunos: 2, banco: 10, porProva: 5),
        Random(1),
      );

      final primeira = versoes[0].questoes.map((q) => q.questao.id).toSet();
      final segunda = versoes[1].questoes.map((q) => q.questao.id).toSet();
      expect(primeira.intersection(segunda), isEmpty);
    });

    test('sem embaralhar, as sorteadas mantêm a ordem do banco', () {
      final versoes = Embaralhador.gerarVersoes(
        provaComSorteio(alunos: 5, banco: 9, porProva: 4, embaralhar: false),
        Random(5),
      );

      for (final versao in versoes) {
        final posicoes = versao.questoes
            .map((q) => int.parse(q.questao.id.substring(1)))
            .toList();
        expect(posicoes, List.of(posicoes)..sort());
      }
    });

    test('quantidade igual ao banco gera todas as questões em toda versão', () {
      final prova = provaComSorteio(alunos: 3, banco: 4, porProva: 4);
      expect(prova.sorteiaQuestoes, isFalse);

      for (final versao in Embaralhador.gerarVersoes(prova)) {
        expect(versao.questoes, hasLength(4));
      }
      expect(prova.toMap()['questoesPorProva'], 4);
    });

    test('o gabarito de cada versão bate com as questões sorteadas', () {
      final prova = provaComSorteio(alunos: 6, banco: 8, porProva: 3);
      for (final versao in Embaralhador.gerarVersoes(prova, Random(9))) {
        final gabarito = GabaritoLido.daVersao(
          provaId: prova.id,
          dadosProva: prova.toMap(),
          versao: versao,
        );
        expect(gabarito.totalQuestoes, 3);
        for (var i = 0; i < 3; i++) {
          final q = versao.questoes[i];
          final correta = q.questao.alternativas.firstWhere((a) => a.isCorreta);
          expect(q.alternativas[gabarito.respostasCorretas[i]], correta.texto);
        }
      }
    });
  });

  group('GabaritoLido.daVersao', () {
    test('usa as respostas da versão e os dados da prova', () {
      final prova = provaDeTeste();
      final versao = Embaralhador.gerarVersoes(prova).last;

      final gabarito = GabaritoLido.daVersao(
        provaId: prova.id,
        dadosProva: prova.toMap(),
        versao: versao,
      );

      expect(gabarito.codigoVersao, 'K7Q2XM-02');
      expect(gabarito.provaId, 'K7Q2XM');
      expect(gabarito.turmaId, 'turma-1');
      expect(gabarito.alunoId, 'aluno-b');
      expect(gabarito.tituloProva, 'Prova de Teste');
      expect(gabarito.nomeTurma, '3º Ano A');
      expect(gabarito.nomeAluno, 'Bruno');
      expect(gabarito.respostasCorretas, [2, 0]);
      // a maior questão tem 5 alternativas
      expect(gabarito.quantidadeAlternativas, 5);
    });
  });

  group('ProvaRepository (memória)', () {
    test('encontra o gabarito pelo código, sem diferenciar maiúsculas', () async {
      final repositorio = ProvaRepositoryMemoria();
      final prova = provaDeTeste();
      await repositorio.salvar(prova, Embaralhador.gerarVersoes(prova));

      final gabarito = await repositorio.buscarGabarito(' k7q2xm-01 ');

      expect(gabarito, isNotNull);
      expect(gabarito!.nomeAluno, 'Ana');
      expect(await repositorio.buscarGabarito('K7Q2XM-99'), isNull);
    });

    test('recusa salvar duas provas com o mesmo código', () async {
      final repositorio = ProvaRepositoryMemoria();
      final prova = provaDeTeste();
      await repositorio.salvar(prova, Embaralhador.gerarVersoes(prova));

      await expectLater(
        repositorio.salvar(prova, Embaralhador.gerarVersoes(prova)),
        throwsStateError,
      );
    });
  });

  test('CorrecaoService leva prova, turma e aluno do gabarito para a correção',
      () {
    final gabarito = GabaritoLido(
      codigoVersao: 'K7Q2XM-01',
      provaId: 'K7Q2XM',
      turmaId: 'turma-1',
      alunoId: 'aluno-a',
      tituloProva: 'Prova de Teste',
      nomeTurma: '3º Ano A',
      nomeAluno: 'Ana',
      respostasCorretas: [2, 0],
      quantidadeAlternativas: 4,
    );

    final correcao = CorrecaoService().corrigir(
      gabarito: gabarito,
      folha: FolhaLida(codigoVersao: 'K7Q2XM-01', respostasMarcadas: [2, 1]),
    );

    expect(correcao.provaId, 'K7Q2XM');
    expect(correcao.turmaId, 'turma-1');
    expect(correcao.alunoId, 'aluno-a');
    expect(correcao.acertos, 1);
  });
}
