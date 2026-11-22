import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';

// Gráficos feitos só com widgets do Flutter (sem pacote de gráficos):
// notas vão de 0 a 10, então a escala é fixa.

String formatarNota(double? valor) =>
    valor == null ? '—' : valor.toStringAsFixed(1).replaceAll('.', ',');

/// Verde: aprovado; laranja: até 2 pontos abaixo do corte; vermelho: abaixo.
Color corDaNota(double nota, {double notaCorte = notaCorteDesempenho}) {
  if (nota >= notaCorte) return Colors.green.shade600;
  if (nota >= notaCorte - 2) return Colors.orange.shade700;
  return Colors.red.shade600;
}

String formatarData(DateTime? data) {
  if (data == null) return '—';
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

/// Card com título, usado em volta de cada gráfico.
class SecaoGrafico extends StatelessWidget {
  const SecaoGrafico({
    super.key,
    required this.titulo,
    required this.icone,
    required this.child,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitulo!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Mensagem exibida no lugar de um gráfico sem dados.
class GraficoVazio extends StatelessWidget {
  const GraficoVazio({super.key, this.mensagem = 'Sem notas para os filtros selecionados.'});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Legenda: cores da nota + linha de referência (se houver).
class LegendaGrafico extends StatelessWidget {
  const LegendaGrafico({super.key, this.rotuloReferencia, this.notaCorte = notaCorteDesempenho});

  final String? rotuloReferencia;
  final double notaCorte;

  Widget _item(Widget marcador, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marcador,
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _quadrado(Color cor) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2)),
      );

  @override
  Widget build(BuildContext context) {
    final corte = formatarNota(notaCorte);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _item(_quadrado(corDaNota(notaCorte, notaCorte: notaCorte)), '≥ $corte'),
        _item(_quadrado(corDaNota(notaCorte - 1, notaCorte: notaCorte)), 'abaixo de $corte'),
        _item(_quadrado(corDaNota(0, notaCorte: notaCorte)), 'crítico'),
        if (rotuloReferencia != null)
          _item(
            Container(width: 3, height: 12, color: Colors.black87),
            rotuloReferencia!,
          ),
      ],
    );
  }
}

/// Barras horizontais de 0 a 10, uma por item. Boa para nomes longos
/// (turmas, alunos, provas) e funciona bem no celular.
///
/// [mediaReferencia] desenha uma linha vertical em todas as barras
/// (ex.: média geral). [ItemMedia.referencia] desenha a linha só naquela barra.
class GraficoBarrasNotas extends StatelessWidget {
  const GraficoBarrasNotas({
    super.key,
    required this.itens,
    this.mediaReferencia,
    this.rotuloReferencia,
    this.onTapItem,
    this.notaCorte = notaCorteDesempenho,
    this.mensagemVazio = 'Sem notas para os filtros selecionados.',
  });

  final List<ItemMedia> itens;
  final double? mediaReferencia;
  final String? rotuloReferencia;
  final void Function(ItemMedia item)? onTapItem;
  final double notaCorte;
  final String mensagemVazio;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return GraficoVazio(mensagem: mensagemVazio);

    final temReferencia =
        mediaReferencia != null || itens.any((i) => i.referencia != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LegendaGrafico(
          notaCorte: notaCorte,
          rotuloReferencia: temReferencia ? (rotuloReferencia ?? 'Referência') : null,
        ),
        const SizedBox(height: 12),
        for (final item in itens)
          _LinhaBarra(
            item: item,
            referencia: item.referencia ?? mediaReferencia,
            notaCorte: notaCorte,
            onTap: onTapItem == null ? null : () => onTapItem!(item),
          ),
        const _EixoNotas(),
      ],
    );
  }
}

class _LinhaBarra extends StatelessWidget {
  const _LinhaBarra({
    required this.item,
    required this.referencia,
    required this.notaCorte,
    this.onTap,
  });

  final ItemMedia item;
  final double? referencia;
  final double notaCorte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = corDaNota(item.media, notaCorte: notaCorte);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatarNota(item.media),
                  style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 14),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 14,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final largura = constraints.maxWidth;
                  final fracao = (item.media / 10).clamp(0.0, 1.0);
                  final ref = referencia;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 2,
                        height: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 2,
                        height: 10,
                        width: largura * fracao,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      if (ref != null)
                        Positioned(
                          left: (largura * (ref / 10).clamp(0.0, 1.0) - 1.5)
                              .clamp(0.0, largura > 3 ? largura - 3 : 0.0),
                          top: 0,
                          width: 3,
                          height: 14,
                          child: Tooltip(
                            message: formatarNota(ref),
                            child: Container(color: Colors.black87),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (item.subtitulo != null) ...[
              const SizedBox(height: 3),
              Text(
                item.subtitulo!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EixoNotas extends StatelessWidget {
  const _EixoNotas();

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(fontSize: 10, color: Colors.grey.shade600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final n in [0, 2, 4, 6, 8, 10]) Text('$n', style: estilo),
        ],
      ),
    );
  }
}

/// Colunas verticais em sequência (ex.: notas do aluno prova a prova).
/// Rola na horizontal quando há muitas colunas.
class GraficoColunasNotas extends StatelessWidget {
  const GraficoColunasNotas({
    super.key,
    required this.itens,
    this.rotuloReferencia,
    this.onTapItem,
    this.notaCorte = notaCorteDesempenho,
    this.altura = 180,
  });

  final List<ItemMedia> itens;
  final String? rotuloReferencia;
  final void Function(ItemMedia item)? onTapItem;
  final double notaCorte;
  final double altura;

  static const _larguraColuna = 72.0;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const GraficoVazio();

    final temReferencia = itens.any((i) => i.referencia != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LegendaGrafico(
          notaCorte: notaCorte,
          rotuloReferencia: temReferencia ? rotuloReferencia : null,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final item in itens)
                _Coluna(
                  item: item,
                  altura: altura,
                  largura: _larguraColuna,
                  notaCorte: notaCorte,
                  rotuloReferencia: rotuloReferencia ?? 'Referência',
                  onTap: onTapItem == null ? null : () => onTapItem!(item),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna({
    required this.item,
    required this.altura,
    required this.largura,
    required this.notaCorte,
    required this.rotuloReferencia,
    this.onTap,
  });

  final ItemMedia item;
  final double altura;
  final double largura;
  final double notaCorte;
  final String rotuloReferencia;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = corDaNota(item.media, notaCorte: notaCorte);
    final alturaBarra = altura * (item.media / 10).clamp(0.0, 1.0);
    final ref = item.referencia;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: largura,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatarNota(item.media),
              style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 13),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: altura,
              width: largura,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    bottom: 0,
                    top: 0,
                    width: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    height: alturaBarra,
                    width: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  if (ref != null)
                    Positioned(
                      bottom: (altura * (ref / 10).clamp(0.0, 1.0) - 1.5)
                          .clamp(0.0, altura - 3),
                      height: 3,
                      width: 40,
                      child: Tooltip(
                        message: '$rotuloReferencia: ${formatarNota(ref)}',
                        child: Container(color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.rotulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de indicadores (KPIs) no topo das telas.
class IndicadoresResumo extends StatelessWidget {
  const IndicadoresResumo({super.key, required this.itens});

  final List<IndicadorResumo> itens;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas = constraints.maxWidth >= 600 ? itens.length : 2;
        const espaco = 12.0;
        final largura = (constraints.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final item in itens) SizedBox(width: largura, child: item),
          ],
        );
      },
    );
  }
}

class IndicadorResumo extends StatelessWidget {
  const IndicadorResumo({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.icone,
    required this.cor,
    this.maxLinhasValor = 1,
  });

  final String rotulo;
  final String valor;
  final IconData icone;
  final Color cor;

  /// Mais de 1 quando o valor é um nome (ex.: nome da turma).
  final int maxLinhasValor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cor.withValues(alpha: 0.15),
            child: Icon(icone, size: 20, color: cor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  valor,
                  maxLines: maxLinhasValor,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
