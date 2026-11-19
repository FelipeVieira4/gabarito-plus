import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/correcao_prova/services/correcao_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/data/versao_prova.dart';
import 'package:gabarito_plus/features/geracao_prova/service/prova_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/configuracao_prova.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/gabarito_qrcode.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/widgets/resumo_prova_card.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/widgets/versao_prova_card.dart';

/// Uma prova salva com as versões de cada aluno. O título pode sempre ser
/// trocado; editar o conteúdo e excluir só enquanto nenhuma versão foi
/// corrigida, porque a correção depende das versões gravadas.
class DetalhesProvaGeradaView extends StatefulWidget {
  const DetalhesProvaGeradaView({super.key, required this.prova});

  final ProvaSalva prova;

  @override
  State<DetalhesProvaGeradaView> createState() => _DetalhesProvaGeradaViewState();
}

class _DetalhesProvaGeradaViewState extends State<DetalhesProvaGeradaView> {
  late ProvaSalva _prova = widget.prova;
  List<VersaoProva> _versoes = [];
  int _corrigidas = 0;
  bool _carregando = true;
  bool _erroAoCarregar = false;
  bool _ocupado = false;

  bool get _bloqueada => _corrigidas > 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroAoCarregar = false;
    });

    try {
      final repositorio = ProvaRepository.instancia;
      final (prova, versoes, corrigidas) = await (
        repositorio.buscar(_prova.id),
        repositorio.listarVersoes(_prova.id),
        CorrecaoRepository.instancia.contarPorProva(_prova.id),
      ).wait;

      if (!mounted) return;
      setState(() {
        _prova = prova ?? _prova;
        _versoes = versoes;
        _corrigidas = corrigidas;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroAoCarregar = true;
      });
    }
  }

  void _mostrarAviso(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  String _mensagemErro(Object erro) => erro is StateError
      ? erro.message
      : 'Não foi possível salvar. Verifique a conexão e tente de novo.';

  Future<void> _editarTitulo() async {
    final novoTitulo = await showDialog<String>(
      context: context,
      builder: (context) => _DialogoTitulo(tituloAtual: _prova.titulo),
    );
    if (novoTitulo == null || novoTitulo == _prova.titulo || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await ProvaRepository.instancia.atualizarTitulo(_prova.id, novoTitulo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _mostrarAviso(_mensagemErro(e));
      return;
    }

    if (!mounted) return;
    setState(() {
      _prova = _prova.copiarComTitulo(novoTitulo);
      _ocupado = false;
    });
    _mostrarAviso('Título atualizado');
  }

  /// Prova com correções não muda: avisa em vez de seguir.
  Future<bool> _avisarSeBloqueada(String acao) async {
    if (!_bloqueada) return false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: const Text('Prova já corrigida'),
        content: Text('Não é possível $acao esta prova. '
            '${mensagemProvaComCorrecoes(_corrigidas)}'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    return true;
  }

  Future<void> _editarProva() async {
    if (await _avisarSeBloqueada('editar')) return;
    if (!mounted) return;
    final confirmou = await _confirmar(
      titulo: 'Editar prova?',
      mensagem: 'As versões serão embaralhadas de novo, com os mesmos códigos. '
          'Provas já impressas desta prova precisarão ser impressas outra vez.',
      acao: 'Editar',
    );
    if (!confirmou || !mounted) return;

    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ConfiguracaoProva(provaEditada: _prova),
      ),
    );
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _excluir() async {
    if (await _avisarSeBloqueada('excluir')) return;
    if (!mounted) return;
    final confirmou = await _confirmar(
      titulo: 'Excluir prova?',
      mensagem: 'A prova "${_prova.titulo}" e as ${_versoes.length} versões '
          'serão apagadas. Esta ação não pode ser desfeita.',
      acao: 'Excluir',
      destrutiva: true,
    );
    if (!confirmou || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await ProvaRepository.instancia.excluir(_prova.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _mostrarAviso(_mensagemErro(e));
      // pode ter sido corrigida desde que a tela abriu
      _carregar();
      return;
    }

    if (!mounted) return;
    _mostrarAviso('Prova "${_prova.titulo}" excluída');
    Navigator.pop(context, true);
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensagem,
    required String acao,
    bool destrutiva = false,
  }) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: destrutiva
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(acao),
          ),
        ],
      ),
    );
    return resposta ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final prova = _prova;
    final podeAgir = !_carregando && !_erroAoCarregar && !_ocupado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prova Gerada'),
        actions: [
          IconButton(
            tooltip: 'Editar título',
            icon: const Icon(Icons.title),
            onPressed: podeAgir ? _editarTitulo : null,
          ),
          IconButton(
            tooltip: 'Editar prova',
            icon: const Icon(Icons.edit),
            onPressed: podeAgir ? _editarProva : null,
          ),
          IconButton(
            tooltip: 'Excluir prova',
            icon: const Icon(Icons.delete_outline),
            onPressed: podeAgir ? _excluir : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_ocupado) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ResumoProvaCard(
              titulo: prova.titulo,
              nomeTurma: prova.nomeTurma,
              nomeAssunto: prova.nomeAssunto,
              codigo: prova.id,
              totalQuestoes: prova.questoesIds.length,
              totalVersoes: _versoes.length,
              embaralharQuestoes: prova.embaralharQuestoes,
              embaralharAlternativas: prova.embaralharAlternativas,
              criadaEm: prova.criadaEm,
              editadaEm: prova.editadaEm,
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erroAoCarregar
                    ? Center(
                        child: TextButton.icon(
                          onPressed: _carregar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Não foi possível carregar. Tentar novamente'),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _versoes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final versao = _versoes[index];
                          return VersaoProvaCard(
                            versao: versao,
                            onVerGabarito: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GabaritoQrCode(
                                  tituloProva: prova.titulo,
                                  nomeTurma: prova.nomeTurma,
                                  versao: versao,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _DialogoTitulo extends StatefulWidget {
  const _DialogoTitulo({required this.tituloAtual});

  final String tituloAtual;

  @override
  State<_DialogoTitulo> createState() => _DialogoTituloState();
}

class _DialogoTituloState extends State<_DialogoTitulo> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.tituloAtual);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar título'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Título da Prova',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Informe o título da prova'
              : null,
          onFieldSubmitted: (_) => _confirmar(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('Salvar')),
      ],
    );
  }
}
