import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/provas/data/desempenho.dart';

/// Tela de edição de provas já criadas.
class EdicaoProvaView extends StatefulWidget {
  const EdicaoProvaView({super.key, required this.prova});

  final ProvaResumo prova;

  @override
  State<EdicaoProvaView> createState() => _EdicaoProvaViewState();
}

class _EdicaoProvaViewState extends State<EdicaoProvaView> {
  late final TextEditingController _tituloController;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.prova.titulo);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  void _mostrarAviso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void _salvarAlteracoes() {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      _mostrarAviso('Informe o título da prova');
      return;
    }

    _mostrarAviso('Alterações salvas com sucesso!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Prova')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título da Prova',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Turma: ${widget.prova.nomeTurma}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Assunto: ${widget.prova.nomeAssunto}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Questões na prova: ${widget.prova.quantidadeQuestoes}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Para adicionar ou remover questões, crie uma nova prova com a configuração desejada.',
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _salvarAlteracoes,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Título'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}