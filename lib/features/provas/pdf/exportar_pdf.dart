import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

enum _AcaoPdf { imprimir, compartilhar }

/// Pergunta se o professor quer imprimir ou salvar/compartilhar o PDF e
/// executa. [gerar] só é chamado depois da escolha.
Future<void> exportarPdf(
  BuildContext context, {
  required String nomeArquivo,
  required Future<Uint8List> Function() gerar,
}) async {
  final acao = await showModalBottomSheet<_AcaoPdf>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Imprimir'),
            subtitle: const Text('Abre a visualização e envia para a impressora'),
            onTap: () => Navigator.pop(context, _AcaoPdf.imprimir),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Salvar / compartilhar PDF'),
            subtitle: const Text('Salva o arquivo ou envia por outro app'),
            onTap: () => Navigator.pop(context, _AcaoPdf.compartilhar),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (acao == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    switch (acao) {
      case _AcaoPdf.imprimir:
        await Printing.layoutPdf(name: nomeArquivo, onLayout: (_) => gerar());
      case _AcaoPdf.compartilhar:
        final navigator = Navigator.of(context, rootNavigator: true);
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Expanded(child: Text('Gerando PDF...')),
                ],
              ),
            ),
          ),
        );
        Uint8List bytes;
        try {
          bytes = await gerar();
        } finally {
          navigator.pop();
        }
        await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Não foi possível gerar o PDF: $e')),
    );
  }
}

/// Nome de arquivo seguro a partir de um texto livre.
String nomeArquivoPdf(String texto) {
  final limpo = texto
      .trim()
      .replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return '${limpo.isEmpty ? 'prova' : limpo}.pdf';
}
