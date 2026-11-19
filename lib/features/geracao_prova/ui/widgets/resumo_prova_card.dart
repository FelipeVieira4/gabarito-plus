import 'package:flutter/material.dart';

String _formatarData(DateTime data) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(data.day)}/${dois(data.month)}/${data.year}';
}

/// Resumo da prova que começa fechado (título e turma) e abre com os
/// detalhes, como os cards das versões de cada aluno.
class ResumoProvaCard extends StatelessWidget {
  const ResumoProvaCard({
    super.key,
    required this.titulo,
    required this.nomeTurma,
    required this.nomeAssunto,
    required this.totalQuestoes,
    required this.totalVersoes,
    required this.embaralharQuestoes,
    required this.embaralharAlternativas,
    this.codigo,
    this.criadaEm,
    this.editadaEm,
  });

  final String titulo;
  final String nomeTurma;
  final String nomeAssunto;
  final int totalQuestoes;
  final int totalVersoes;
  final bool embaralharQuestoes;
  final bool embaralharAlternativas;
  final String? codigo;
  final DateTime? criadaEm;
  final DateTime? editadaEm;

  @override
  Widget build(BuildContext context) {
    final cinza = TextStyle(color: Colors.grey.shade700);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const CircleAvatar(child: Icon(Icons.description)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(nomeTurma),
        children: [
          if (codigo != null) Text('Código: $codigo', style: cinza),
          Text('Assunto: $nomeAssunto', style: cinza),
          Text('$totalQuestoes questões · $totalVersoes versões', style: cinza),
          if (criadaEm != null)
            Text(
              'Criada em ${_formatarData(criadaEm!)}'
              '${editadaEm == null ? '' : ' · editada em ${_formatarData(editadaEm!)}'}',
              style: cinza,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _chip('Ordem das questões', embaralharQuestoes),
              _chip('Ordem das alternativas', embaralharAlternativas),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool ativo) {
    return Chip(
      avatar: Icon(
        ativo ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: ativo ? Colors.green : Colors.grey,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
