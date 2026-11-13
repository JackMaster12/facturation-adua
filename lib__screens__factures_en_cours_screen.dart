import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/ordonnance.dart';
import '../services/facture_service.dart';
import 'facture_ordonnances_screen.dart';

class FacturesEnCoursScreen extends StatelessWidget {
  const FacturesEnCoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Factures en cours : ordonnances')),
      body: StreamBuilder<List<FactureData>>(
        stream: FactureService.instance.factures('ordonnances', 'en_cours'),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final l = snap.data!;
          if (l.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Aucune facture en cours.')));
          }
          return ListView(children: [
            for (final f in l)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('Facture ${numeroFacture(f.mois, f.annee)}'),
                subtitle: const Text('En cours'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => FactureOrdonnancesScreen(factureId: f.id))),
              ),
          ]);
        },
      ),
    );
  }
}
