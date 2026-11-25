import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/features/aluno/data/aluno.dart';
import 'package:gabarito_plus/features/correcao_prova/services/correcao_service.dart';
import 'package:gabarito_plus/features/geracao_prova/data/correcao.dart';
import 'package:gabarito_plus/features/geracao_prova/data/gabarito_lido.dart';
import 'package:gabarito_plus/features/provas/data/versao_prova.dart';
import 'package:gabarito_plus/features/questoes/data/alternativa.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';

import 'helpers/fixtures_correcao.dart';

void main() {
  final service = CorrecaoService();
  final correcoes = gerarCorrecoesDeTeste();

  GabaritoLido gabaritoDe(List<int> corretas) => GabaritoLido(
        codigoVersao: 'TESTE-001',
        tituloProva: 'Prova de teste',
        nomeTurma: 'Turma de teste',
        nomeAluno: 'Aluno de teste',
        respostasCorretas: corretas,
        quantidadeAlternativas: 4,
      );

  FolhaLida folhaDe(List<int?> marcadas, {String codigo = 'TESTE-001'}) =>
      FolhaLida(codigoVersao: codigo, respostasMarcadas: marcadas);

  group('corrigir', () {
    test('conta acertos, erros e questões em branco separadamente', () {
      final correcao = service.corrigir(
        gabarito: gabaritoDe([0, 1, 2, 3]),
        folha: folhaDe([0, 1, 3, null]),
      );

      expect(correcao.acertos, 2);
      expect(correcao.erros, 1);
      expect(correcao.emBranco, 1);
      expect(correcao.nota, 5.0);
    });

    test('trata marcação fora do intervalo de alternativas como em branco', () {
      final correcao = service.corrigir(
        gabarito: gabaritoDe([0, 1]),
        folha: folhaDe([0, 9]),
      );

      expect(correcao.acertos, 1);
      expect(correcao.emBranco, 1);
      expect(correcao.erros, 0);
    });

    test('recusa folha de outra prova', () {
      expect(
        () => service.corrigir(
          gabarito: gabaritoDe([0, 1]),
          folha: folhaDe([0, 1], codigo: 'OUTRA-002'),
        ),
        throwsArgumentError,
      );
    });

    test('recusa folha com quantidade de questões diferente do gabarito', () {
      expect(
        () => service.corrigir(
          gabarito: gabaritoDe([0, 1, 2]),
          folha: folhaDe([0, 1]),
        ),
        throwsArgumentError,
      );
    });
  });

  group('correção manual na conferência', () {
    test('trocar a marcação recalcula a nota', () {
      final correcao = service.corrigir(
        gabarito: gabaritoDe([0, 1]),
        folha: folhaDe([0, 0]),
      );
      expect(correcao.nota, 5.0);

      final ajustada = correcao.comRespostaAlterada(2, 1);

      expect(ajustada.nota, 10.0);
      expect(correcao.nota, 5.0, reason: 'a correção original não muda');
    });

    test('marcar como em branco remove o acerto', () {
      final correcao = service
          .corrigir(gabarito: gabaritoDe([0, 1]), folha: folhaDe([0, 1]))
          .comRespostaAlterada(1, null);

      expect(correcao.acertos, 1);
      expect(correcao.emBranco, 1);
    });

    test('recusa alternativa que não existe na prova', () {
      final correcao = service.corrigir(
        gabarito: gabaritoDe([0, 1]),
        folha: folhaDe([0, 1]),
      );

      expect(() => correcao.comRespostaAlterada(1, 7), throwsArgumentError);
    });
  });

  group('resumo da turma', () {
    test('apura média, extremos e aprovação da turma de teste', () {
      final resumo = service.resumoDaTurma(correcoes);

      expect(resumo.totalCorrigidas, 8);
      expect(resumo.media, 6.5);
      expect(resumo.maiorNota, 10.0);
      expect(resumo.menorNota, 3.0);
      expect(resumo.aprovados, 5);
      expect(resumo.reprovados, 3);
    });

    test('distribui todas as notas entre as faixas, sem perder nenhuma', () {
      final resumo = service.resumoDaTurma(correcoes);
      final somaDasFaixas = resumo.distribuicao
          .fold<int>(0, (total, faixa) => total + faixa.quantidade);

      expect(somaDasFaixas, correcoes.length);
    });

    test('turma sem correções não quebra', () {
      final resumo = service.resumoDaTurma([]);

      expect(resumo.totalCorrigidas, 0);
      expect(resumo.media, 0);
      expect(resumo.percentualAprovacao, 0);
    });
  });

  group('estatísticas por questão', () {
    test('conta as marcações de cada alternativa', () {
      final estatisticas = service.estatisticasPorQuestao(
        correcoes,
        enunciados: enunciadosTeste,
      );
      final questao6 = estatisticas[5];

      expect(questao6.marcacoesPorAlternativa, [0, 6, 1, 1]);
      expect(questao6.totalCorrecoes, correcoes.length);
      expect(questao6.acertos, 1);
      expect(questao6.enunciado, enunciadosTeste[5]);
    });

    test('identifica a alternativa errada mais marcada', () {
      final estatisticas = service.estatisticasPorQuestao(correcoes);
      final questao6 = estatisticas[5];

      expect(questao6.distratorMaisMarcado, 1);
      expect(questao6.marcacoesDoDistrator, 6);
    });

    test('não aponta distrator quando a turma inteira acertou', () {
      final estatisticas = service.estatisticasPorQuestao(correcoes);
      final questao1 = estatisticas[0];

      expect(questao1.acertos, 7);
      expect(questao1.distratorMaisMarcado, 0);
    });

    test('contabiliza questões em branco fora das alternativas', () {
      final estatisticas = service.estatisticasPorQuestao(correcoes);
      final questao3 = estatisticas[2];

      expect(questao3.emBranco, 1);
      expect(questao3.acertos, 2);
      expect(questao3.erros, 5);
      expect(
        questao3.acertos + questao3.erros + questao3.emBranco,
        correcoes.length,
      );
    });

    test('ordena as questões da mais errada para a menos errada', () {
      final ordenadas = service.questoesMaisErradas(correcoes);

      expect(ordenadas.first.numeroQuestao, 6);
      expect(
        ordenadas.first.percentualAcerto <= ordenadas.last.percentualAcerto,
        isTrue,
      );
    });

    test('lista vazia devolve estatística vazia', () {
      expect(service.estatisticasPorQuestao([]), isEmpty);
    });
  });

  group('ordenação por nota', () {
    test('lista da maior para a menor nota', () {
      final ordenadas = service.ordenadasPorNota(correcoes);

      expect(ordenadas.first.nomeAluno, 'Ana Maria');
      expect(ordenadas.first.nota, 10.0);
      expect(ordenadas.last.nota, 3.0);
    });
  });

  test('letra da alternativa acompanha o índice, e branco vira traço', () {
    expect(letraAlternativa(0), 'A');
    expect(letraAlternativa(3), 'D');
    expect(letraAlternativa(null), '—');
  });

  group('estatísticas por questão original (ignorando embaralhamento)', () {
    test('usa a referência da primeira versão para alinhar alternativas', () {
      // Q1: versão 1 tem [Alt A, Alt B, Alt C] com correta em 0 (A)
      //     versão 2 tem [Alt C, Alt B, Alt A] com correta em 2 (A no índice 2)
      // Aluno 1 (versão 1) marca índice 0 (Alt A)
      // Aluno 2 (versão 2) marca índice 2 (Alt A)
      // Resultado esperado: questão original terá 2 marcações em Alt A

      final aluno1 = Aluno(
        id: 'aluno-1',
        nome: 'Aluno 1',
        email: '',
        isAtivo: true,
      );
      final aluno2 = Aluno(
        id: 'aluno-2',
        nome: 'Aluno 2',
        email: '',
        isAtivo: true,
      );

      final questao1 = Questao(
        id: 'q1',
        enunciado: 'Questão 1',
        alternativas: [
          Alternativa(texto: 'Alt A', isCorreta: true),
          Alternativa(texto: 'Alt B', isCorreta: false),
          Alternativa(texto: 'Alt C', isCorreta: false),
        ],
      );

      // Versão 1: ordem original [A, B, C], correta em 0
      final versao1 = VersaoProva(
        codigo: 'TEST-001',
        aluno: aluno1,
        questoes: [
          QuestaoEmbaralhada(
            questao: questao1,
            alternativas: ['Alt A', 'Alt B', 'Alt C'],
            respostaCorreta: 0,
          ),
        ],
      );

      // Versão 2: ordem embaralhada [C, B, A], correta em 2 (Alt A)
      final versao2 = VersaoProva(
        codigo: 'TEST-002',
        aluno: aluno2,
        questoes: [
          QuestaoEmbaralhada(
            questao: questao1,
            alternativas: ['Alt C', 'Alt B', 'Alt A'],
            respostaCorreta: 2,
          ),
        ],
      );

      final correcao1 = Correcao(
        codigoVersao: 'TEST-001',
        provaId: 'prova-1',
        turmaId: 'turma-1',
        alunoId: 'aluno-1',
        tituloProva: 'Prova',
        nomeTurma: 'Turma',
        nomeAluno: 'Aluno 1',
        respostas: [RespostaMarcada(numeroQuestao: 1, indiceMarcado: 0, indiceCorreto: 0)],
        quantidadeAlternativas: 3,
        dataHora: DateTime.now(),
      );

      final correcao2 = Correcao(
        codigoVersao: 'TEST-002',
        provaId: 'prova-1',
        turmaId: 'turma-1',
        alunoId: 'aluno-2',
        tituloProva: 'Prova',
        nomeTurma: 'Turma',
        nomeAluno: 'Aluno 2',
        respostas: [RespostaMarcada(numeroQuestao: 1, indiceMarcado: 2, indiceCorreto: 2)],
        quantidadeAlternativas: 3,
        dataHora: DateTime.now(),
      );

      final stats = service.estatisticasPorQuestaoOriginal(
        [correcao1, correcao2],
        [versao1, versao2],
      );

      expect(stats, isNotEmpty);
      expect(stats[0].numero, 1);
      expect(stats[0].alternativas, ['Alt A', 'Alt B', 'Alt C']);
      expect(stats[0].marcacoesPorAlternativa[0], 2); // Alt A marcada 2x
      expect(stats[0].indiceMaisMarcada, 0);
    });

    test('questão presente só em parte das versões conta só alunos que tinham', () {
      final aluno1 = Aluno(
        id: 'aluno-1',
        nome: 'Aluno 1',
        email: '',
        isAtivo: true,
      );
      final aluno2 = Aluno(
        id: 'aluno-2',
        nome: 'Aluno 2',
        email: '',
        isAtivo: true,
      );

      final questao1 = Questao(
        id: 'q1',
        enunciado: 'Q1',
        alternativas: [
          Alternativa(texto: 'A', isCorreta: true),
          Alternativa(texto: 'B', isCorreta: false),
        ],
      );

      // Versão 1 tem a questão
      final versao1 = VersaoProva(
        codigo: 'TEST-001',
        aluno: aluno1,
        questoes: [
          QuestaoEmbaralhada(
            questao: questao1,
            alternativas: ['A', 'B'],
            respostaCorreta: 0,
          ),
        ],
      );

      // Versão 2 NÃO tem a questão (lista vazia)
      final versao2 = VersaoProva(
        codigo: 'TEST-002',
        aluno: aluno2,
        questoes: [],
      );

      final correcao1 = Correcao(
        codigoVersao: 'TEST-001',
        provaId: 'prova-1',
        turmaId: 'turma-1',
        alunoId: 'aluno-1',
        tituloProva: 'Prova',
        nomeTurma: 'Turma',
        nomeAluno: 'Aluno 1',
        respostas: [RespostaMarcada(numeroQuestao: 1, indiceMarcado: 0, indiceCorreto: 0)],
        quantidadeAlternativas: 2,
        dataHora: DateTime.now(),
      );

      final correcao2 = Correcao(
        codigoVersao: 'TEST-002',
        provaId: 'prova-1',
        turmaId: 'turma-1',
        alunoId: 'aluno-2',
        tituloProva: 'Prova',
        nomeTurma: 'Turma',
        nomeAluno: 'Aluno 2',
        respostas: [],
        quantidadeAlternativas: 2,
        dataHora: DateTime.now(),
      );

      final stats = service.estatisticasPorQuestaoOriginal(
        [correcao1, correcao2],
        [versao1, versao2],
      );

      expect(stats, isNotEmpty);
      expect(stats[0].totalAlunos, 1); // Só aluno 1 tinha essa questão
      expect(stats[0].marcacoesPorAlternativa[0], 1);
    });

    test('questão com maioria em branco não aparece como "mais marcada"', () {
      final aluno1 = Aluno(
        id: 'aluno-1',
        nome: 'Aluno 1',
        email: '',
        isAtivo: true,
      );
      final aluno2 = Aluno(
        id: 'aluno-2',
        nome: 'Aluno 2',
        email: '',
        isAtivo: true,
      );

      final questao1 = Questao(
        id: 'q1',
        enunciado: 'Q1',
        alternativas: [
          Alternativa(texto: 'A', isCorreta: true),
          Alternativa(texto: 'B', isCorreta: false),
        ],
      );

      final versao1 = VersaoProva(
        codigo: 'TEST-001',
        aluno: aluno1,
        questoes: [
          QuestaoEmbaralhada(
            questao: questao1,
            alternativas: ['A', 'B'],
            respostaCorreta: 0,
          ),
        ],
      );

      final versao2 = VersaoProva(
        codigo: 'TEST-002',
        aluno: aluno2,
        questoes: [
          QuestaoEmbaralhada(
            questao: questao1,
            alternativas: ['A', 'B'],
            respostaCorreta: 0,
          ),
        ],
      );

      // Aluno 1 marca em branco
      final correcao1 = Correcao(
        codigoVersao: 'TEST-001',
        provaId: 'prova-1',
        turmaId: 'turma-1',
        alunoId: 'aluno-1',
        tituloProva: 'Prova',
        nomeTurma: 'Turma',
        nomeAluno: 'Aluno 1',
        respostas: [RespostaMarcada(numeroQuestao: 1, indiceMarcado: null, indiceCorreto: 0)],
        quantidadeAlternativas: 2,
        dataHora: DateTime.now(),
      );

      // Aluno 2 marca em branco
      final correcao2 = Correcao(
        codigoVersao: 'TEST-002',
        provaId: 'prova-1',
        turmaId: 'turma-1',
        alunoId: 'aluno-2',
        tituloProva: 'Prova',
        nomeTurma: 'Turma',
        nomeAluno: 'Aluno 2',
        respostas: [RespostaMarcada(numeroQuestao: 1, indiceMarcado: null, indiceCorreto: 0)],
        quantidadeAlternativas: 2,
        dataHora: DateTime.now(),
      );

      final stats = service.estatisticasPorQuestaoOriginal(
        [correcao1, correcao2],
        [versao1, versao2],
      );

      expect(stats[0].emBranco, 2);
      expect(stats[0].indiceMaisMarcada, isNull);
      expect(stats[0].percentualMaisMarcada, 0);
    });

    test('respeita a ordem de questoesIds quando fornecida', () {
      final aluno1 = Aluno(
        id: 'aluno-1',
        nome: 'Aluno 1',
        email: '',
        isAtivo: true,
      );

      final q1 = Questao(
        id: 'questao-1',
        enunciado: 'Q1',
        alternativas: [
          Alternativa(texto: 'A', isCorreta: true),
          Alternativa(texto: 'B', isCorreta: false),
        ],
      );

      final q2 = Questao(
        id: 'questao-2',
        enunciado: 'Q2',
        alternativas: [
          Alternativa(texto: 'C', isCorreta: false),
          Alternativa(texto: 'D', isCorreta: true),
        ],
      );

      final versao1 = VersaoProva(
        codigo: 'TEST-001',
        aluno: aluno1,
        questoes: [
          QuestaoEmbaralhada(
            questao: q1,
            alternativas: ['A', 'B'],
            respostaCorreta: 0,
          ),
          QuestaoEmbaralhada(
            questao: q2,
            alternativas: ['C', 'D'],
            respostaCorreta: 1,
          ),
        ],
      );

      final correcao1 = Correcao(
        codigoVersao: 'TEST-001',
        provaId: 'prova-1',
        turmaId: 'turma-1',
        alunoId: 'aluno-1',
        tituloProva: 'Prova',
        nomeTurma: 'Turma',
        nomeAluno: 'Aluno 1',
        respostas: [
          RespostaMarcada(numeroQuestao: 1, indiceMarcado: 0, indiceCorreto: 0),
          RespostaMarcada(numeroQuestao: 2, indiceMarcado: 1, indiceCorreto: 1),
        ],
        quantidadeAlternativas: 2,
        dataHora: DateTime.now(),
      );

      // Ordem invertida: q2 deve vir primeiro
      final stats = service.estatisticasPorQuestaoOriginal(
        [correcao1],
        [versao1],
        ordemQuestoesIds: ['questao-2', 'questao-1'],
      );

      expect(stats[0].numero, 1);
      expect(stats[0].questaoId, 'questao-2');
      expect(stats[1].numero, 2);
      expect(stats[1].questaoId, 'questao-1');
    });

    test('lista vazia de versões retorna lista vazia', () {
      final stats = service.estatisticasPorQuestaoOriginal(
        [gerarCorrecoesDeTeste().first],
        [],
      );

      expect(stats, isEmpty);
    });

    test('lista vazia de correções retorna lista vazia', () {
      final questao1 = Questao(
        id: 'q1',
        enunciado: 'Q1',
        alternativas: [Alternativa(texto: 'A', isCorreta: true)],
      );

      final versao1 = VersaoProva(
        codigo: 'TEST-001',
        aluno: Aluno(
          id: 'aluno-1',
          nome: 'Aluno',
          email: '',
          isAtivo: true,
        ),
        questoes: [
          QuestaoEmbaralhada(
            questao: questao1,
            alternativas: ['A'],
            respostaCorreta: 0,
          ),
        ],
      );

      final stats = service.estatisticasPorQuestaoOriginal([], [versao1]);

      expect(stats, isEmpty);
    });
  });
}