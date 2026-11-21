import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';
import 'package:gabarito_plus/features/turma/data/turma.dart';

class Prova {
  final String id;
  final String titulo;
  final Turma turma;
  final Assunto assunto;
  /// Banco de questões da prova. Sem [questoesPorProva], todas entram em
  /// cada versão; com ele, cada versão sorteia uma parte deste banco.
  final List<Questao> questoes;

  /// Quantas questões cada aluno recebe, sorteadas de [questoes].
  /// Null = todas as questões em todas as versões.
  final int? questoesPorProva;
  final bool embaralharQuestoes;
  final bool embaralharAlternativas;

  Prova({
    required this.id,
    required this.titulo,
    required this.turma,
    required this.assunto,
    required this.questoes,
    this.questoesPorProva,
    required this.embaralharQuestoes,
    required this.embaralharAlternativas,
  });

  bool get sorteiaQuestoes =>
      questoesPorProva != null && questoesPorProva! < questoes.length;

  /// Quantidade de questões que cada versão terá.
  int get quantidadeQuestoesPorVersao =>
      sorteiaQuestoes ? questoesPorProva! : questoes.length;

  /// Formato salvo no Firestore (o id fica no documento, não nos campos).
  /// Turma e assunto são guardados por id, com o nome copiado para exibição.
  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'turmaId': turma.id,
        'nomeTurma': turma.nomeTurma,
        'assuntoId': assunto.id,
        'nomeAssunto': assunto.nome,
        'questoesIds': questoes.map((q) => q.id).toList(),
        'questoesPorProva': quantidadeQuestoesPorVersao,
        'embaralharQuestoes': embaralharQuestoes,
        'embaralharAlternativas': embaralharAlternativas,
        'criadaEm': FieldValue.serverTimestamp(),
      };
}
