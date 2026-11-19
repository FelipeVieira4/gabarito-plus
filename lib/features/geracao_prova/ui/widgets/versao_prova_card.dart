import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/geracao_prova/data/versao_prova.dart';

/// Versão de um aluno: questões na ordem dele, alternativa correta em
/// destaque e atalho para o gabarito.
class VersaoProvaCard extends StatelessWidget {
  const VersaoProvaCard({super.key, required this.versao, required this.onVerGabarito});

  final VersaoProva versao;
  final VoidCallback onVerGabarito;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(child: Text(versao.aluno.nome[0])),
        title: Text(versao.aluno.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Código da versão: ${versao.codigo}'),
        children: [
          ...versao.questoes.asMap().entries.map((entry) {
            final numero = entry.key + 1;
            final questaoEmbaralhada = entry.value;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questão $numero',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                  Text(questaoEmbaralhada.questao.enunciado),
                  const SizedBox(height: 4),
                  ...questaoEmbaralhada.alternativas.asMap().entries.map((alt) {
                    final letra = String.fromCharCode(65 + alt.key);
                    final correta = alt.key == questaoEmbaralhada.respostaCorreta;
                    return Text(
                      '$letra) ${alt.value}',
                      style: TextStyle(
                        color: correta ? Colors.green[700] : null,
                        fontWeight: correta ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onVerGabarito,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Ver Gabarito'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
