import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/ordonnance.dart';
import '../pdf/partage.dart';
import '../services/auth_service.dart';
import '../services/facture_service.dart';

class FacturesTermineesScreen extends StatelessWidget {
  const FacturesTermineesScreen({super.key, required this.profil});
  final UserProfile profil;

  Future<void> _supprimer(BuildContext context, FactureData f) async {
    final numero = numeroFacture(f.mois, f.annee);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la facture ?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pour confirmer, retapez : $numero'),
          const SizedBox(height: 8),
          TextField(controller: c, textCapitalization: TextCapitalization.characters),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim().toUpperCase() == numero), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) await FactureService.instance.supprimer(f.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Factures terminées')),
      body: StreamBuilder<List<FactureData>>(
        stream: FactureService.instance.toutesTerminees(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final l = snap.data!;
          if (l.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Aucune facture terminée.')));
          }
          return ListView(children: [
            for (final f in l)
              ListTile(
                leading: Icon(f.type == 'ordonnances' ? Icons.child_care : Icons.local_shipping_outlined),
                title: Text('${f.type == 'ordonnances' ? 'Ordonnances' : 'Commande'} ${numeroFacture(f.mois, f.annee)}'),
                subtitle: Text('${formatMontant(f.total)} FCFA'
                    '${f.arreteLe == null ? '' : '  ·  arrêtée le ${formatDate(f.arreteLe!)}'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (f.type == 'ordonnances')
                    IconButton(
                        tooltip: 'Partager le PDF',
                        icon: const Icon(Icons.picture_as_pdf),
                        onPressed: () => partagerFacture(context, f)),
                  if (profil.isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rouvrir') FactureService.instance.rouvrir(f.id);
                        if (v == 'supprimer') _supprimer(context, f);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rouvrir', child: Text('Rouvrir')),
                        PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                      ],
                    ),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
