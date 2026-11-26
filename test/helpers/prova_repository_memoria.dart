import 'package:gabarito_plus/features/geracao_prova/data/gabarito_lido.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/provas/data/versao_prova.dart';
import 'package:gabarito_plus/features/provas/service/prova_repository.dart';

/// Repositório de provas em memória para os testes de widget, que não
/// inicializam o Firebase. Monta o gabarito do mesmo jeito que o real.
class ProvaRepositoryMemoria implements ProvaRepository {
  final Map<String, Map<String, dynamic>> _provas = {};
  final Map<String, VersaoProva> _versoes = {};

  @override
  Future<void> salvar(Prova prova, List<VersaoProva> versoes) async {
    if (_provas.containsKey(prova.id)) {
      throw StateError('Já existe uma prova com o código ${prova.id}.');
    }
    _provas[prova.id] = prova.toMap();
    for (final versao in versoes) {
      _versoes[versao.codigo] = versao;
    }
  }

  @override
  Future<ProvaSalva?> buscarProva(String provaId) async {
    final dados = _provas[provaId];
    if (dados == null) return null;
    return ProvaSalva.fromMap(provaId, dados);
  }

  @override
  Future<void> substituir(Prova prova, List<VersaoProva> versoes) async {
    _provas[prova.id] = prova.toMap();
    // Remove versões antigas que não estão na nova lista.
    final codigosNovos = versoes.map((v) => v.codigo).toSet();
    _versoes.removeWhere(
      (codigo, _) => codigo.startsWith('${prova.id}-') &&
          !codigosNovos.contains(codigo),
    );
    for (final versao in versoes) {
      _versoes[versao.codigo] = versao;
    }
  }

  @override
  Future<GabaritoLido?> buscarGabarito(String codigoVersao) async {
    final codigo = codigoVersao.trim().toUpperCase();
    final versao = _versoes[codigo];
    if (versao == null) return null;

    final provaId = codigo.substring(0, codigo.indexOf('-'));
    return GabaritoLido.daVersao(
      provaId: provaId,
      dadosProva: _provas[provaId]!,
      versao: versao,
    );
  }

  @override
  Future<List<VersaoProva>> buscarVersoes(String provaId) async {
    final versoes = _versoes.values
        .where((v) => v.codigo.startsWith('$provaId-'))
        .toList();
    versoes.sort((a, b) => a.codigo.compareTo(b.codigo));
    return versoes;
  }

  @override
  Future<List<String>> buscarOrdemQuestoes(String provaId) async {
    final provaData = _provas[provaId];
    if (provaData == null) return [];

    final questoesIds = provaData['questoesIds'] as List<dynamic>?;
    return questoesIds?.cast<String>() ?? [];
  }
}
