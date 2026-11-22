import 'dart:math';

import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/data/versao_prova.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';

class Embaralhador {
  static List<VersaoProva> gerarVersoes(Prova prova, [Random? random]) {
    final gerador = random ?? Random();

    final alunos = prova.turma.listaAlunos;
    final sorteio = _SorteioQuestoes(prova.questoes, gerador);

    return List.generate(alunos.length, (indice) {
      final aluno = alunos[indice];
      final questoes = prova.sorteiaQuestoes
          ? sorteio.sortear(prova.questoesPorProva!)
          : List.of(prova.questoes);

      if (prova.embaralharQuestoes) {
        questoes.shuffle(gerador);
      } else if (prova.sorteiaQuestoes) {
        // Sem embaralhar, as sorteadas seguem a ordem do banco.
        questoes.sort((a, b) =>
            prova.questoes.indexOf(a).compareTo(prova.questoes.indexOf(b)));
      }

      final questoesEmbaralhadas = questoes.map((questao) {
        final alternativasEmbaralhadas = List.of(questao.alternativas);

        if (prova.embaralharAlternativas) {
          alternativasEmbaralhadas.shuffle(gerador);
        }

        final indexCorreta = alternativasEmbaralhadas.indexWhere((alt) => alt.isCorreta);

        return QuestaoEmbaralhada(
          questao: questao,
          alternativas: alternativasEmbaralhadas.map((alt) => alt.texto).toList(),
          respostaCorreta: indexCorreta,
        );
      }).toList();

      // O código começa com o id da prova: a câmera encontra a versão
      // em provas/{provaId}/versoes/{codigo} sem precisar de busca.
      return VersaoProva(
        codigo: '${prova.id}-${(indice + 1).toString().padLeft(2, '0')}',
        aluno: aluno,
        questoes: questoesEmbaralhadas,
      );
    });
  }
}

/// Sorteia questões do banco como cartas de um baralho: uma questão só
/// volta a sair depois que todas as outras saíram. Assim as versões ficam
/// o mais diferentes possível e o uso do banco fica equilibrado.
class _SorteioQuestoes {
  _SorteioQuestoes(this._banco, this._random);

  final List<Questao> _banco;
  final Random _random;
  final List<Questao> _baralho = [];

  List<Questao> sortear(int quantidade) {
    final sorteadas = <Questao>[];
    while (sorteadas.length < quantidade) {
      if (_baralho.isEmpty) {
        // Rebaralha sem as que já estão nesta versão, para não repetir
        // questão dentro da mesma prova.
        _baralho
          ..addAll(_banco.where((q) => !sorteadas.contains(q)))
          ..shuffle(_random);
      }
      sorteadas.add(_baralho.removeLast());
    }
    return sorteadas;
  }
}
