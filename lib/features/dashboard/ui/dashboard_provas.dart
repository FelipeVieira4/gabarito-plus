import 'package:flutter/material.dart';
import 'package:gabarito_plus/features/correcao_prova/views/correcao/consulta_provas_corrigidas.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/configuracao_prova.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/consulta_provas_geradas.dart';
import 'package:gabarito_plus/features/professor/ui/profile_view.dart';

/// Menu de provas: gerar uma nova, consultar as geradas e ver as corrigidas.
class DashboardProvas extends StatelessWidget {
  const DashboardProvas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileView()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                // Trava a largura no desktop pra evitar cards gigantes
                constraints: const BoxConstraints(maxWidth: 900),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 1.3 : 1.0,
                  children: [
                    _buildMenuCard(
                      context,
                      'Gerar Provas',
                      Icons.auto_awesome,
                      Colors.green,
                      const ConfiguracaoProva(),
                    ),
                    _buildMenuCard(
                      context,
                      'Provas Geradas',
                      Icons.folder_open,
                      Colors.indigo,
                      const ConsultaProvasGeradasView(),
                    ),
                    _buildMenuCard(
                      context,
                      'Provas Corrigidas',
                      Icons.fact_check,
                      Colors.teal,
                      const ConsultaProvasCorrigidasView(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget destino,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destino),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
