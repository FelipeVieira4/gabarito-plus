import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/correcao_prova/ui/detalhes_prova_corrigida_view.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';
import 'package:gabarito_plus/features/provas/data/prova.dart';
import 'package:gabarito_plus/features/provas/pdf/exportar_pdf.dart';
import 'package:gabarito_plus/features/provas/pdf/prova_pdf.dart';
import 'package:gabarito_plus/features/provas/service/prova_repository.dart';
import 'package:gabarito_plus/features/turma/data/turma.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/filtros_provas.dart';
import 'package:gabarito_plus/features/provas/ui/widgets/graficos_notas.dart';

/// Lista das provas geradas, com filtro de disciplina, turma e semestre.
class ConsultaProvasView extends StatefulWidget {
  const ConsultaProvasView({
    super.key,
    required this.analise,
    this.filtroInicial = const FiltroDesempenho(),
  });

  final AnaliseDesempenho analise;
  final FiltroDesempenho filtroInicial;

  @override
  State<ConsultaProvasView> createState() => _ConsultaProvasViewState();
}

class _ConsultaProvasViewState extends State<ConsultaProvasView> {
  final _buscaController = TextEditingController();
  late FiltroDesempenho _filtro = widget.filtroInicial;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<ProvaResumo> _provas(FiltroDesempenho filtro) {
    final termo = _buscaController.text.trim().toLowerCase();
    final lista = widget.analise.provasFiltradas(filtro);
    if (termo.isEmpty) return lista;
    return lista.where((p) {
      return p.titulo.toLowerCase().contains(termo) ||
          p.id.toLowerCase().contains(termo) ||
          p.nomeAssunto.toLowerCase().contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final analise = widget.analise;
    final filtro = FiltrosProvas.validar(analise, _filtro);
    final provas = _provas(filtro);

    return Scaffold(
      appBar: AppBar(title: const Text('Consulta de Provas')),
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
                    labelText: 'Buscar por título, código ou assunto...',
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${provas.length} ${provas.length == 1 ? 'prova encontrada' : 'provas encontradas'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ),
              Expanded(
                child: provas.isEmpty
                    ? const GraficoVazio(mensagem: 'Nenhuma prova encontrada para os filtros.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: provas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final prova = provas[index];
                          final notas = analise.notasDaProva(prova.id);
                          return CardProva(
                            prova: prova,
                            notas: notas,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetalheProvaView(
                                  prova: prova,
                                  notas: notas,
                                ),
                              ),
                            ),
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

/// Card de uma prova com a média e o andamento da correção.
class CardProva extends StatelessWidget {
  const CardProva({
    super.key,
    required this.prova,
    required this.notas,
    required this.onTap,
  });

  final ProvaResumo prova;
  final List<NotaLancada> notas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = mediaDe(notas.map((n) => n.nota));
    final cor = media == null ? Colors.blueGrey : corDaNota(media);
    final disciplina = [
      if (prova.nomeDisciplina.isNotEmpty) prova.nomeDisciplina,
      if (prova.nomeAssunto.isNotEmpty) prova.nomeAssunto,
    ].join(' › ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatarNota(media),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('média', style: TextStyle(fontSize: 11, color: cor)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prova.titulo.isEmpty ? 'Prova ${prova.id}' : prova.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [prova.nomeTurma, if (disciplina.isNotEmpty) disciplina].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Etiqueta(texto: prova.id, cor: Colors.grey.shade800, mono: true),
                        _Etiqueta(
                          texto: '${prova.quantidadeQuestoes} questões',
                          cor: Colors.blue.shade700,
                        ),
                        _Etiqueta(
                          texto: prova.quantidadeVersoes == null
                              ? '${notas.length} '
                                  '${notas.length == 1 ? 'corrigida' : 'corrigidas'}'
                              : '${notas.length}/${prova.quantidadeVersoes} corrigidas',
                          cor: provaTotalmenteCorrigida(prova, notas)
                              ? Colors.green.shade700
                              : Colors.teal.shade700,
                        ),
                        if (provaTotalmenteCorrigida(prova, notas))
                          _Etiqueta(texto: 'Correção concluída', cor: Colors.green.shade700),
                        Text(
                          formatarData(prova.criadaEm),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.cor, this.mono = false});

  final String texto;
  final Color cor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
    );
  }
}

/// Todas as versões (alunos) da prova já têm correção.
bool provaTotalmenteCorrigida(ProvaResumo prova, List<NotaLancada> notas) {
  final total = prova.quantidadeVersoes;
  if (total == null || total == 0) return false;
  final corrigidas = notas.map((n) => n.correcao.codigoVersao).toSet().length;
  return corrigidas >= total;
}

/// Notas de todos os alunos numa prova.
class DetalheProvaView extends StatelessWidget {
  const DetalheProvaView({super.key, required this.prova, required this.notas});

  final ProvaResumo prova;
  final List<NotaLancada> notas;

  /// Reimprime as provas de todos os alunos (prova + folha de respostas),
  /// a partir das versões salvas.
  Future<void> _exportarPdf(BuildContext context) async {
    // O PDF só usa título, turma, assunto e disciplina da prova.
    final provaPdf = Prova(
      id: prova.id,
      titulo: prova.titulo,
      turma: Turma(
        id: prova.turmaId,
        nomeTurma: prova.nomeTurma,
        listaAlunos: const [],
        ativa: true,
      ),
      assunto: Assunto(id: prova.assuntoId, nome: prova.nomeAssunto, questoes: const []),
      disciplinaId: prova.disciplinaId,
      nomeDisciplina: prova.nomeDisciplina,
      questoes: const [],
      embaralharQuestoes: false,
      embaralharAlternativas: false,
    );

    await exportarPdf(
      context,
      nomeArquivo: nomeArquivoPdf('${prova.titulo}_${prova.nomeTurma}'),
      gerar: () async {
        final versoes = await ProvaRepository.instancia.buscarVersoes(prova.id);
        if (versoes.isEmpty) {
          throw Exception('as versões desta prova não foram encontradas.');
        }
        return ProvaPdf.todasAsProvas(provaPdf, versoes);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = mediaDe(notas.map((n) => n.nota));
    final ordenadas = List<NotaLancada>.of(notas)
      ..sort((a, b) {
        final comp = b.nota.compareTo(a.nota);
        return comp != 0 ? comp : a.correcao.nomeAluno.compareTo(b.correcao.nomeAluno);
      });
    final aprovados = notas.where((n) => n.nota >= notaCorteDesempenho).length;
    final notasOrdenadas = notas.map((n) => n.nota).toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(prova.titulo.isEmpty ? 'Prova ${prova.id}' : prova.titulo),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportarPdf(context),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Gerar PDF'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    prova.nomeTurma,
                    if (prova.nomeDisciplina.isNotEmpty) prova.nomeDisciplina,
                    if (prova.nomeAssunto.isNotEmpty) prova.nomeAssunto,
                    formatarData(prova.criadaEm),
                  ].join(' • '),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                IndicadoresResumo(
                  itens: [
                    IndicadorResumo(
                      rotulo: 'Média da prova',
                      valor: formatarNota(media),
                      icone: Icons.analytics_outlined,
                      cor: media == null ? Colors.blueGrey : corDaNota(media),
                    ),
                    IndicadorResumo(
                      rotulo: 'Corrigidas',
                      valor: '${notas.length}',
                      icone: Icons.fact_check_outlined,
                      cor: Colors.teal.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Maior / Menor',
                      valor: notas.isEmpty
                          ? '—'
                          : '${formatarNota(notasOrdenadas.last)} / '
                              '${formatarNota(notasOrdenadas.first)}',
                      icone: Icons.swap_vert,
                      cor: Colors.blueGrey.shade700,
                    ),
                    IndicadorResumo(
                      rotulo: 'Aprovados',
                      valor: '$aprovados/${notas.length}',
                      icone: Icons.verified_outlined,
                      cor: Colors.green.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SecaoGrafico(
                  titulo: 'Notas dos alunos',
                  subtitulo: 'Toque num aluno para ver a correção.',
                  icone: Icons.people_outline,
                  child: GraficoBarrasNotas(
                    itens: [
                      for (final n in ordenadas)
                        ItemMedia(
                          id: n.correcao.codigoVersao,
                          rotulo: n.correcao.nomeAluno,
                          subtitulo: '${n.correcao.acertos}/${n.correcao.totalQuestoes} acertos'
                              ' • ${n.correcao.codigoVersao}',
                          media: n.nota,
                          quantidade: 1,
                        ),
                    ],
                    mediaReferencia: media,
                    rotuloReferencia: 'Média da prova (${formatarNota(media)})',
                    mensagemVazio: 'Esta prova ainda não tem correções.',
                    onTapItem: (item) {
                      final nota = ordenadas.firstWhere(
                        (n) => n.correcao.codigoVersao == item.id,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalhesProvaCorrigidaView(
                            correcao: nota.correcao,
                            notaCorte: notaCorteDesempenho,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
