import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/service/prova_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/configuracao_prova.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/detalhes_prova_gerada.dart';

class ConsultaProvasGeradasView extends StatefulWidget {
  const ConsultaProvasGeradasView({super.key});

  @override
  State<ConsultaProvasGeradasView> createState() =>
      _ConsultaProvasGeradasViewState();
}

class _ConsultaProvasGeradasViewState extends State<ConsultaProvasGeradasView> {
  final _buscaController = TextEditingController();

  String? _turmaFiltro;

  List<ProvaSalva> _provas = [];
  bool _carregando = true;
  bool _erroAoCarregar = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroAoCarregar = false;
    });

    try {
      final provas = await ProvaRepository.instancia.listar();
      if (!mounted) return;
      setState(() {
        _provas = provas;
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

  List<ProvaSalva> _filtrar({required String? turmaAtiva}) {
    final busca = _buscaController.text.trim().toLowerCase();
    return _provas.where((prova) {
      if (turmaAtiva != null && prova.nomeTurma != turmaAtiva) return false;
      if (busca.isEmpty) return true;
      return prova.titulo.toLowerCase().contains(busca) ||
          prova.id.toLowerCase().contains(busca);
    }).toList();
  }

  void _limparFiltros() {
    _buscaController.clear();
    setState(() => _turmaFiltro = null);
  }

  Future<void> _abrirDetalhes(ProvaSalva prova) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesProvaGeradaView(prova: prova),
      ),
    );
    if (mounted) _carregar();
  }

  Future<void> _gerarNovaProva() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfiguracaoProva()),
    );
    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final turmas = _provas.map((p) => p.nomeTurma).toSet().toList()..sort();
    final turmaAtiva = turmas.contains(_turmaFiltro) ? _turmaFiltro : null;
    final provasFiltradas = _filtrar(turmaAtiva: turmaAtiva);
    final possuiFiltroAtivo =
        _buscaController.text.trim().isNotEmpty || turmaAtiva != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Provas Geradas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _buscaController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Buscar por título ou código...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _buscaController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _buscaController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey('turma-$turmaAtiva'),
                        initialValue: turmaAtiva,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Turma',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas as turmas'),
                          ),
                          ...turmas.map(
                            (turma) => DropdownMenuItem<String?>(
                              value: turma,
                              child: Text(turma, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (valor) => setState(() => _turmaFiltro = valor),
                      ),
                    ),
                    if (possuiFiltroAtivo) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Limpar filtros',
                        icon: const Icon(Icons.filter_alt_off),
                        onPressed: _limparFiltros,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : _erroAoCarregar
                        ? _Mensagem(
                            icone: Icons.cloud_off_outlined,
                            texto: 'Não foi possível carregar as provas.',
                            acao: TextButton.icon(
                              onPressed: _carregar,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          )
                        : provasFiltradas.isEmpty
                            ? _Mensagem(
                                icone: Icons.description_outlined,
                                texto: possuiFiltroAtivo
                                    ? 'Nenhuma prova encontrada para os filtros aplicados.'
                                    : 'Nenhuma prova gerada até o momento.',
                                acao: possuiFiltroAtivo
                                    ? TextButton.icon(
                                        onPressed: _limparFiltros,
                                        icon: const Icon(Icons.filter_alt_off),
                                        label: const Text('Limpar filtros'),
                                      )
                                    : null,
                              )
                            : RefreshIndicator(
                                onRefresh: _carregar,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                  itemCount: provasFiltradas.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final prova = provasFiltradas[index];
                                    return _CardProva(
                                      prova: prova,
                                      onTap: () => _abrirDetalhes(prova),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _gerarNovaProva,
        icon: const Icon(Icons.add),
        label: const Text('Gerar prova'),
      ),
    );
  }
}

class _CardProva extends StatelessWidget {
  const _CardProva({required this.prova, required this.onTap});

  final ProvaSalva prova;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('card-prova-${prova.id}'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: onTap,
        title: Text(
          prova.titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          prova.id,
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.icone, required this.texto, this.acao});

  final IconData icone;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            if (acao != null) ...[const SizedBox(height: 12), acao!],
          ],
        ),
      ),
    );
  }
}
