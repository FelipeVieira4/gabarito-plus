import 'package:flutter/material.dart';

/// Menu de 3 pontos com "Editar" e "Excluir".
class MenuOpcoes extends StatelessWidget {
  final String tooltip;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const MenuOpcoes({
    super.key,
    required this.tooltip,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: (valor) {
        if (valor == 'editar') onEditar();
        if (valor == 'excluir') onExcluir();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'editar',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Editar'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'excluir',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Excluir'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Pergunta se deseja excluir. Retorna true se confirmou.
Future<bool> confirmarExclusao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return resultado ?? false;
}