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
  ///
  /// Na [edicao], `criadaEm` fica como estava e grava-se `editadaEm`.
  Map<String, dynamic> toMap({bool edicao = false}) => {
        'titulo': titulo,
        'turmaId': turma.id,
        'nomeTurma': turma.nomeTurma,
        'assuntoId': assunto.id,
        'nomeAssunto': assunto.nome,
        'questoesIds': questoes.map((q) => q.id).toList(),
        'questoesPorProva': quantidadeQuestoesPorVersao,
        'embaralharQuestoes': embaralharQuestoes,
        'embaralharAlternativas': embaralharAlternativas,
        if (edicao)
          'editadaEm': FieldValue.serverTimestamp()
        else
          'criadaEm': FieldValue.serverTimestamp(),
      };
}

/// Prova já salva, como lida do Firestore. Diferente de [Prova], guarda
/// turma, assunto e questões só por id: eles podem ter mudado ou sido
/// excluídos depois que a prova foi gerada.
class ProvaSalva {
  final String id;
  final String titulo;
  final String turmaId;
  final String nomeTurma;
  final String assuntoId;
  final String nomeAssunto;
  final List<String> questoesIds;
  final bool embaralharQuestoes;
  final bool embaralharAlternativas;
  final DateTime? criadaEm;
  final DateTime? editadaEm;

  ProvaSalva({
    required this.id,
    required this.titulo,
    required this.turmaId,
    required this.nomeTurma,
    required this.assuntoId,
    required this.nomeAssunto,
    required this.questoesIds,
    required this.embaralharQuestoes,
    required this.embaralharAlternativas,
    this.criadaEm,
    this.editadaEm,
  });

  factory ProvaSalva.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ProvaSalva.fromMap(doc.id, doc.data() ?? {});
  }

  factory ProvaSalva.fromMap(String id, Map<String, dynamic> data) {
    DateTime? data_(Object? valor) => switch (valor) {
          Timestamp t => t.toDate(),
          DateTime d => d,
          _ => null,
        };

    return ProvaSalva(
      id: id,
      titulo: data['titulo'] ?? '',
      turmaId: data['turmaId'] ?? '',
      nomeTurma: data['nomeTurma'] ?? '',
      assuntoId: data['assuntoId'] ?? '',
      nomeAssunto: data['nomeAssunto'] ?? '',
      questoesIds: List<String>.from(data['questoesIds'] ?? []),
      embaralharQuestoes: data['embaralharQuestoes'] ?? false,
      embaralharAlternativas: data['embaralharAlternativas'] ?? false,
      criadaEm: data_(data['criadaEm']),
      editadaEm: data_(data['editadaEm']),
    );
  }

  ProvaSalva copiarComTitulo(String novoTitulo) => ProvaSalva(
        id: id,
        titulo: novoTitulo,
        turmaId: turmaId,
        nomeTurma: nomeTurma,
        assuntoId: assuntoId,
        nomeAssunto: nomeAssunto,
        questoesIds: questoesIds,
        embaralharQuestoes: embaralharQuestoes,
        embaralharAlternativas: embaralharAlternativas,
        criadaEm: criadaEm,
        editadaEm: editadaEm,
      );
}
