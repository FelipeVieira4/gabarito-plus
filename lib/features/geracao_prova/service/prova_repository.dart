import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gabarito_plus/features/correcao_prova/services/correcao_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/data/gabarito_lido.dart';
import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/data/versao_prova.dart';

/// Sem 0/O, 1/I/L: o código é digitado à mão na correção.
const alfabetoCodigoProva = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const tamanhoCodigoProva = 6;

/// Id curto da prova, que também é o começo do código de cada versão
/// (ex.: `K7Q2XM-03`).
String gerarIdProva([Random? random]) {
  final gerador = random ?? Random.secure();
  return List.generate(
    tamanhoCodigoProva,
    (_) => alfabetoCodigoProva[gerador.nextInt(alfabetoCodigoProva.length)],
  ).join();
}

/// Provas geradas e os gabaritos de cada versão. As telas usam [instancia];
/// os testes de widget trocam por uma versão em memória, já que não
/// inicializam o Firebase.
abstract class ProvaRepository {
  static ProvaRepository instancia = ProvaRepositoryFirestore();

  /// Grava a prova e todas as versões juntas: ou entra tudo, ou nada.
  Future<void> salvar(Prova prova, List<VersaoProva> versoes);

  /// Gabarito da versão com esse código, ou null se não existir.
  Future<GabaritoLido?> buscarGabarito(String codigoVersao);

  /// Provas salvas, da mais nova para a mais antiga.
  Future<List<ProvaSalva>> listar();

  Future<ProvaSalva?> buscar(String provaId);

  /// Versões da prova, em ordem de código.
  Future<List<VersaoProva>> listarVersoes(String provaId);

  /// Sempre permitido: o título também é trocado nas correções da prova,
  /// que guardam uma cópia dele.
  Future<void> atualizarTitulo(String provaId, String titulo);

  /// Troca a prova e todas as versões por novas, mantendo o id. As versões
  /// que não existem mais (turma ficou menor) são apagadas. Recusa com
  /// [StateError] se alguma versão já foi corrigida.
  Future<void> substituir(Prova prova, List<VersaoProva> versoes);

  /// Apaga a prova e as versões. Recusa com [StateError] se alguma versão
  /// já foi corrigida.
  Future<void> excluir(String provaId);
}

/// Mensagem usada quando a prova já tem correções e não pode mudar.
String mensagemProvaComCorrecoes(int quantidade) =>
    'A prova já tem $quantidade ${quantidade == 1 ? 'versão corrigida' : 'versões corrigidas'}: '
    'só o título pode ser alterado.';

int _compararVersoes(VersaoProva a, VersaoProva b) =>
    a.codigo.compareTo(b.codigo);

int _compararProvas(ProvaSalva a, ProvaSalva b) {
  // provas sem data (gravação ainda pendente) vêm primeiro
  final da = a.criadaEm, db = b.criadaEm;
  if (da == null && db == null) return a.id.compareTo(b.id);
  if (da == null) return -1;
  if (db == null) return 1;
  return db.compareTo(da);
}

class ProvaRepositoryFirestore implements ProvaRepository {
  ProvaRepositoryFirestore({CorrecaoRepository? correcoes})
      : _repositorioCorrecoes = correcoes;

  final CorrecaoRepository? _repositorioCorrecoes;
  CorrecaoRepository get _contadorCorrecoes =>
      _repositorioCorrecoes ?? CorrecaoRepository.instancia;

  // late: só acessa o Firebase no primeiro uso, não ao criar a instância
  late final _db = FirebaseFirestore.instance;
  late final _provas = _db.collection('provas');
  late final _correcoes = _db.collection('correcoes');

  @override
  Future<void> salvar(Prova prova, List<VersaoProva> versoes) async {
    final provaRef = _provas.doc(prova.id);

    if ((await provaRef.get()).exists) {
      throw StateError(
        'Já existe uma prova com o código ${prova.id}. Gere as provas de novo.',
      );
    }

    final batch = _db.batch();
    batch.set(provaRef, prova.toMap());
    for (final versao in versoes) {
      batch.set(provaRef.collection('versoes').doc(versao.codigo), versao.toMap());
    }
    await batch.commit();
  }

  @override
  Future<GabaritoLido?> buscarGabarito(String codigoVersao) async {
    final codigo = codigoVersao.trim().toUpperCase();
    final separador = codigo.indexOf('-');
    if (separador <= 0) return null;

    final provaRef = _provas.doc(codigo.substring(0, separador));
    final provaDoc = await provaRef.get();
    if (!provaDoc.exists) return null;

    final versaoDoc = await provaRef.collection('versoes').doc(codigo).get();
    if (!versaoDoc.exists) return null;

    return GabaritoLido.daVersao(
      provaId: provaDoc.id,
      dadosProva: provaDoc.data()!,
      versao: VersaoProva.fromFirestore(versaoDoc),
    );
  }

  @override
  Future<List<ProvaSalva>> listar() async {
    final snap = await _provas.get();
    return snap.docs.map(ProvaSalva.fromFirestore).toList()
      ..sort(_compararProvas);
  }

  @override
  Future<ProvaSalva?> buscar(String provaId) async {
    final doc = await _provas.doc(provaId).get();
    return doc.exists ? ProvaSalva.fromFirestore(doc) : null;
  }

  @override
  Future<List<VersaoProva>> listarVersoes(String provaId) async {
    final snap = await _provas.doc(provaId).collection('versoes').get();
    return snap.docs.map(VersaoProva.fromFirestore).toList()
      ..sort(_compararVersoes);
  }

  // Um batch aceita até 500 operações; as turmas ficam bem abaixo disso.

  @override
  Future<void> atualizarTitulo(String provaId, String titulo) async {
    final (inicio, fim) = faixaCodigosDaProva(provaId);
    final correcoes = await _correcoes
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: inicio)
        .where(FieldPath.documentId, isLessThan: fim)
        .get();

    final batch = _db.batch();
    batch.update(_provas.doc(provaId), {
      'titulo': titulo,
      'editadaEm': FieldValue.serverTimestamp(),
    });
    for (final doc in correcoes.docs) {
      batch.update(doc.reference, {'tituloProva': titulo});
    }
    await batch.commit();
  }

  @override
  Future<void> substituir(Prova prova, List<VersaoProva> versoes) async {
    await _garantirSemCorrecoes(prova.id);

    final provaRef = _provas.doc(prova.id);
    final antigas = await provaRef.collection('versoes').get();
    final codigosNovos = versoes.map((v) => v.codigo).toSet();

    final batch = _db.batch();
    batch.update(provaRef, prova.toMap(edicao: true));
    for (final doc in antigas.docs) {
      if (!codigosNovos.contains(doc.id)) batch.delete(doc.reference);
    }
    for (final versao in versoes) {
      batch.set(provaRef.collection('versoes').doc(versao.codigo), versao.toMap());
    }
    await batch.commit();
  }

  @override
  Future<void> excluir(String provaId) async {
    await _garantirSemCorrecoes(provaId);

    final provaRef = _provas.doc(provaId);
    final versoes = await provaRef.collection('versoes').get();

    final batch = _db.batch();
    for (final doc in versoes.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(provaRef);
    await batch.commit();
  }

  Future<void> _garantirSemCorrecoes(String provaId) async {
    final quantidade = await _contadorCorrecoes.contarPorProva(provaId);
    if (quantidade > 0) throw StateError(mensagemProvaComCorrecoes(quantidade));
  }
}
