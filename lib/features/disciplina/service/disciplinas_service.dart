import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/disciplina/data/disciplina.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';
import 'package:gabarito_plus/core/professor_db.dart';

class DisciplinasService {
  CollectionReference<Map<String, dynamic>> get _disciplinas =>
      ProfessorDb.colecao('disciplinas');
  CollectionReference<Map<String, dynamic>> get _assuntos =>
      ProfessorDb.colecao('assuntos');
  CollectionReference<Map<String, dynamic>> get _questoes =>
      ProfessorDb.colecao('questoes');

  Future<List<Disciplina>> listarDisciplinas() async {
    final snaps = await Future.wait([
      _disciplinas.get(),
      _assuntos.get(),
      _questoes.get(),
    ]);
    final disciplinasSnap = snaps[0];
    final assuntosSnap = snaps[1];
    final questoesSnap = snaps[2];

    final questoesPorAssunto = <String, List<Questao>>{};
    for (final doc in questoesSnap.docs) {
      final assuntoId = doc.data()['assuntoId'] as String? ?? '';
      questoesPorAssunto
          .putIfAbsent(assuntoId, () => [])
          .add(Questao.fromFirestore(doc));
    }

    final assuntosPorDisciplina = <String, List<Assunto>>{};
    for (final doc in assuntosSnap.docs) {
      final d = doc.data();
      final disciplinaId = d['disciplinaId'] as String? ?? '';
      assuntosPorDisciplina.putIfAbsent(disciplinaId, () => []).add(
            Assunto(
              id: doc.id,
              nome: d['nome'] ?? '',
              questoes: questoesPorAssunto[doc.id] ?? [],
            ),
          );
    }

    for (final assuntos in assuntosPorDisciplina.values) {
      assuntos.sort(
        (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
      );
    }

    final lista = disciplinasSnap.docs.map((doc) {
      return Disciplina(
        id: doc.id,
        descricao: doc.data()['descricao'] ?? '',
        assuntos: assuntosPorDisciplina[doc.id] ?? [],
      );
    }).toList();

    lista.sort(
      (a, b) => a.descricao.toLowerCase().compareTo(b.descricao.toLowerCase()),
    );
    return lista;
  }

  /// [ignorarId] permite ignorar a própria disciplina ao editar.
  Future<bool> existeDisciplina(String descricao, {String? ignorarId}) async {
    final snap = await _disciplinas
        .where('descricaoBusca', isEqualTo: descricao.trim().toLowerCase())
        .limit(2)
        .get();
    return snap.docs.any((d) => d.id != ignorarId);
  }

  Future<String> criarDisciplina(String descricao) async {
    final disciplina = Disciplina(id: '', descricao: descricao, assuntos: []);
    final doc = await _disciplinas.add(disciplina.toMap());
    return doc.id;
  }

  /// Se o toMap() de Disciplina gravar outros campos derivados,
  /// inclua-os aqui também.
  Future<void> atualizarDisciplina({
    required String id,
    required String descricao,
  }) {
    final texto = descricao.trim();
    return _disciplinas.doc(id).update({
      'descricao': texto,
      'descricaoBusca': texto.toLowerCase(),
    });
  }

  Future<void> excluirDisciplina(String id) => _disciplinas.doc(id).delete();

  Future<String> criarAssunto({
    required String disciplinaId,
    required String nome,
  }) async {
    final assunto = Assunto(id: '', nome: nome, questoes: []);
    final doc = await _assuntos.add(assunto.toMap(disciplinaId: disciplinaId));
    return doc.id;
  }

  /// Se o toMap() de Assunto gravar outros campos derivados
  /// (ex.: nomeBusca), inclua-os aqui também.
  Future<void> atualizarAssunto({
    required String id,
    required String nome,
    required String disciplinaId,
  }) {
    return _assuntos.doc(id).update({
      'nome': nome.trim(),
      'disciplinaId': disciplinaId,
    });
  }

  Future<void> excluirAssunto(String id) => _assuntos.doc(id).delete();
}