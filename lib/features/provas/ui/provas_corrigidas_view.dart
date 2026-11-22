import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/correcao_prova/views/correcao/consulta_provas_corrigidas.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';
import 'package:gabarito_plus/features/provas/service/desempenho_repository.dart';
import 'package:gabarito_plus/features/provas/ui/consulta_provas_view.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/filtros_provas.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/graficos_notas.dart';

/// Provas corrigidas agrupadas por prova. Por padrão mostra só as provas
/// com todas as versões corrigidas; ao tocar, abre as correções da prova
/// (aluno, nota, acertos...).
class ProvasCorrigidasView extends StatefulWidget {
  const ProvasCorrigidasView({
    super.key,
    required this.analise,
    this.filtroInicial = const FiltroDesempenho(),
  });

  final AnaliseDesempenho analise;
  final FiltroDesempenho filtroInicial;

  @override
  State<ProvasCorrigidasView> createState() => _ProvasCorrigidasViewState();
}

class _ProvasCorrigidasViewState extends State<ProvasCorrigidasView> {
  final _buscaController = TextEditingController();
  late AnaliseDesempenho _analise = widget.analise;
  late FiltroDesempenho _filtro = widget.filtroInicial;
  bool _somenteConcluidas = true;
  bool _recarregando = false;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  /// Depois de remover uma correção no detalhe, a lista precisa refletir.
  Future<void> _recarregar() async {
    setState(() => _recarregando = true);
    try {
      final analise = await DesempenhoRepository.instancia.carregar();
      if (!mounted) return;
      setState(() => _analise = analise);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar a lista.')),
      );
    } finally {
      if (mounted) setState(() => _recarregando = false);
    }
  }

  Future<void> _abrirCorrecoes(ProvaResumo prova) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultaProvasCorrigidasView(
          provaId: prova.id,
          titulo: prova.titulo.isEmpty ? 'Prova ${prova.id}' : prova.titulo,
          notaCorte: notaCorteDesempenho,
        ),
      ),
    );
    if (mounted) await _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final analise = _analise;
    final filtro = FiltrosProvas.validar(analise, _filtro);
    final termo = _buscaController.text.trim().toLowerCase();

    final comCorrecao = <({ProvaResumo prova, List<NotaLancada> notas})>[];
    for (final prova in analise.provasFiltradas(filtro)) {
      final notas = analise.notasDaProva(prova.id);
      if (notas.isEmpty) continue;
      if (termo.isNotEmpty &&
          !prova.titulo.toLowerCase().contains(termo) &&
          !prova.id.toLowerCase().contains(termo)) {
        continue;
      }
      comCorrecao.add((prova: prova, notas: notas));
    }

    final concluidas =
        comCorrecao.where((p) => provaTotalmenteCorrigida(p.prova, p.notas)).toList();
    final exibidas = _somenteConcluidas ? concluidas : comCorrecao;
    final emAndamento = comCorrecao.length - concluidas.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provas Corrigidas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _recarregando ? null : _recarregar,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              if (_recarregando) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _buscaController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Buscar por título ou código...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FiltrosProvas(
                  analise: analise,
                  filtro: filtro,
                  onChanged: (f) => setState(() => _filtro = f),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Correção concluída (${concluidas.length})'),
                        selected: _somenteConcluidas,
                        onSelected: (_) => setState(() => _somenteConcluidas = true),
                      ),
                      ChoiceChip(
                        label: Text('Todas com correções (${comCorrecao.length})'),
                        selected: !_somenteConcluidas,
                        onSelected: (_) => setState(() => _somenteConcluidas = false),
                      ),
                    ],
                  ),
                ),
              ),
              if (_somenteConcluidas && emAndamento > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$emAndamento ${emAndamento == 1 ? 'prova' : 'provas'} '
                          'com correção em andamento não '
                          '${emAndamento == 1 ? 'aparece' : 'aparecem'} aqui.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: exibidas.isEmpty
                    ? GraficoVazio(
                        mensagem: _somenteConcluidas
                            ? 'Nenhuma prova com a correção concluída para os filtros.'
                            : 'Nenhuma prova com correções para os filtros.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: exibidas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = exibidas[index];
                          return CardProva(
                            prova: item.prova,
                            notas: item.notas,
                            onTap: () => _abrirCorrecoes(item.prova),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
