import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';
import 'package:gabarito_plus/features/provas/service/desempenho_repository.dart';
import 'package:gabarito_plus/features/provas/ui/consulta_provas_view.dart';
import 'package:gabarito_plus/features/provas/ui/provas_corrigidas_view.dart';
import 'package:gabarito_plus/features/provas/ui/desempenho_turma_view.dart';
import 'package:gabarito_plus/features/provas/ui/desempenho_turmas_view.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/filtros_provas.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/graficos_notas.dart';

/// Painel do módulo de provas: indicadores, atalhos e a média das turmas.
/// Carrega os dados uma vez e repassa para as telas filhas.
class DashboardProvasView extends StatefulWidget {
  const DashboardProvasView({super.key});

  @override
  State<DashboardProvasView> createState() => _DashboardProvasViewState();
}

class _DashboardProvasViewState extends State<DashboardProvasView> {
  AnaliseDesempenho _analise = AnaliseDesempenho.vazia();
  FiltroDesempenho _filtro = const FiltroDesempenho();
  bool _carregando = true;
  bool _erro = false;
  bool _primeiraCarga = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final analise = await DesempenhoRepository.instancia.carregar();
      if (!mounted) return;
      setState(() {
        _analise = analise;
        // Na primeira vez abre no semestre mais recente.
        if (_primeiraCarga && analise.semestres.isNotEmpty) {
          _filtro = FiltroDesempenho(semestre: analise.semestres.first);
        }
        _primeiraCarga = false;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = true;
      });
    }
  }

  Future<void> _abrir(Widget tela, {bool recarregarAoVoltar = false}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    if (recarregarAoVoltar && mounted) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provas e Desempenho'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro
              ? _ErroCarregamento(onTentarNovamente: _carregar)
              : RefreshIndicator(onRefresh: _carregar, child: _conteudo(context)),
    );
  }

  Widget _conteudo(BuildContext context) {
    final filtro = FiltrosProvas.validar(_analise, _filtro);
    final provas = _analise.provasFiltradas(filtro);
    final notas = _analise.notasFiltradas(filtro);
    final media = _analise.mediaGeral(filtro);
    final aprovados = notas.where((n) => n.nota >= notaCorteDesempenho).length;
    final percentual = notas.isEmpty ? null : (aprovados / notas.length * 100).round();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FiltrosProvas(
                analise: _analise,
                filtro: filtro,
                onChanged: (f) => setState(() => _filtro = f),
              ),
              const SizedBox(height: 16),
              IndicadoresResumo(
                itens: [
                  IndicadorResumo(
                    rotulo: 'Provas geradas',
                    valor: '${provas.length}',
                    icone: Icons.description_outlined,
                    cor: Colors.blue.shade700,
                  ),
                  IndicadorResumo(
                    rotulo: 'Provas corrigidas',
                    valor: '${notas.length}',
                    icone: Icons.fact_check_outlined,
                    cor: Colors.teal.shade700,
                  ),
                  IndicadorResumo(
                    rotulo: 'Média geral',
                    valor: formatarNota(media),
                    icone: Icons.analytics_outlined,
                    cor: media == null ? Colors.blueGrey : corDaNota(media),
                  ),
                  IndicadorResumo(
                    rotulo: 'Aprovação',
                    valor: percentual == null ? '—' : '$percentual%',
                    icone: Icons.verified_outlined,
                    cor: Colors.green.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _tituloSecao(context, 'Acessos', Icons.apps),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final largo = constraints.maxWidth >= 700;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: largo ? 3 : 2,
                    crossAxisSpacing: largo ? 16 : 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: largo ? 1.4 : 1.2,
                    children: [
                      _cardMenu(
                        context,
                        'Consulta de Provas',
                        Icons.search,
                        Colors.blue,
                        () => _abrir(ConsultaProvasView(analise: _analise, filtroInicial: filtro)),
                      ),
                      _cardMenu(
                        context,
                        'Desempenho das Turmas',
                        Icons.bar_chart,
                        Colors.indigo,
                        () => _abrir(DesempenhoTurmasView(analise: _analise, filtroInicial: filtro)),
                      ),
                      _cardMenu(
                        context,
                        'Provas Corrigidas',
                        Icons.fact_check,
                        Colors.teal,
                        () => _abrir(
                          ProvasCorrigidasView(analise: _analise, filtroInicial: filtro),
                          recarregarAoVoltar: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              SecaoGrafico(
                titulo: 'Média das turmas',
                subtitulo: filtro.semestre == null
                    ? 'Todas as notas de cada turma. Toque numa turma para ver os alunos.'
                    : 'Média no ${rotuloSemestre(filtro.semestre!)}. '
                        'Toque numa turma para ver os alunos.',
                icone: Icons.groups_outlined,
                child: GraficoBarrasNotas(
                  itens: _analise.mediasPorTurma(filtro),
                  mediaReferencia: media,
                  rotuloReferencia: 'Média geral (${formatarNota(media)})',
                  onTapItem: (item) => _abrir(
                    DesempenhoTurmaView(
                      analise: _analise,
                      turmaId: item.id,
                      filtroInicial: filtro,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tituloSecao(BuildContext context, String titulo, IconData icone) {
    return Row(
      children: [
        Icon(icone, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
        ),
      ],
    );
  }

  Widget _cardMenu(BuildContext context, String titulo, IconData icone, Color cor, VoidCallback onTap) {
    final isLargo = MediaQuery.sizeOf(context).width >= 700;
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: isLargo ? 40 : 32, color: cor),
              SizedBox(height: isLargo ? 12 : 6),
              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isLargo ? 14 : 12.5,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErroCarregamento extends StatelessWidget {
  const _ErroCarregamento({required this.onTentarNovamente});

  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar as provas.\nVerifique a conexão e tente de novo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTentarNovamente,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
