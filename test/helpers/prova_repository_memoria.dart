import 'package:gabarito_plus/features/correcao_prova/services/correcao_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/data/gabarito_lido.dart';
import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/data/versao_prova.dart';
import 'package:gabarito_plus/features/geracao_prova/service/prova_repository.dart';

import 'correcao_repository_memoria.dart';

/// Repositório de provas em memória para os testes de widget, que não
/// inicializam o Firebase. Monta o gabarito do mesmo jeito que o real e
/// consulta [correcoes] para saber se a prova ainda pode mudar.
class ProvaRepositoryMemoria implements ProvaRepository {
  ProvaRepositoryMemoria({CorrecaoRepository? correcoes})
      : correcoes = correcoes ?? CorrecaoRepositoryMemoria();

  final CorrecaoRepository correcoes;
  final Map<String, Map<String, dynamic>> _provas = {};
  final Map<String, VersaoProva> _versoes = {};

  @override
  Future<void> salvar(Prova prova, List<VersaoProva> versoes) async {
    if (_provas.containsKey(prova.id)) {
      throw StateError('Já existe uma prova com o código ${prova.id}.');
    }
    // o FieldValue.serverTimestamp() não faz sentido fora do Firestore
    _provas[prova.id] = {...prova.toMap(), 'criadaEm': DateTime.now()};
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
  Future<List<ProvaSalva>> listar() async {
    final lista = [
      for (final entry in _provas.entries) ProvaSalva.fromMap(entry.key, entry.value),
    ];
    lista.sort((a, b) => b.criadaEm!.compareTo(a.criadaEm!));
    return lista;
  }

  @override
  Future<ProvaSalva?> buscar(String provaId) async {
    final dados = _provas[provaId];
    return dados == null ? null : ProvaSalva.fromMap(provaId, dados);
  }

  @override
  Future<List<VersaoProva>> listarVersoes(String provaId) async =>
      _versoes.values.where((v) => v.codigo.startsWith('$provaId-')).toList()
        ..sort((a, b) => a.codigo.compareTo(b.codigo));

  @override
  Future<void> atualizarTitulo(String provaId, String titulo) async {
    _provas[provaId] = {..._provas[provaId]!, 'titulo': titulo};
    for (final correcao in await correcoes.obterTodas()) {
      if (correcao.codigoVersao.startsWith('$provaId-')) {
        await correcoes.salvar(correcao.comTituloProva(titulo));
      }
    }
  }

  @override
  Future<void> substituir(Prova prova, List<VersaoProva> versoes) async {
    await _garantirSemCorrecoes(prova.id);
    _provas[prova.id] = {
      ..._provas[prova.id]!,
      ...prova.toMap(edicao: true),
      'editadaEm': DateTime.now(),
    };
    _versoes.removeWhere((codigo, _) => codigo.startsWith('${prova.id}-'));
    for (final versao in versoes) {
      _versoes[versao.codigo] = versao;
    }
  }

  @override
  Future<void> excluir(String provaId) async {
    await _garantirSemCorrecoes(provaId);
    _provas.remove(provaId);
    _versoes.removeWhere((codigo, _) => codigo.startsWith('$provaId-'));
  }

  Future<void> _garantirSemCorrecoes(String provaId) async {
    final quantidade = await correcoes.contarPorProva(provaId);
    if (quantidade > 0) throw StateError(mensagemProvaComCorrecoes(quantidade));
  }
}
