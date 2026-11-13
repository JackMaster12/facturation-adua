import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/ordonnance.dart';
import '../pdf/partage.dart';
import '../services/facture_service.dart';
import 'ordonnance_form_screen.dart';

class FactureOrdonnancesScreen extends StatelessWidget {
  const FactureOrdonnancesScreen({super.key, required this.factureId});
  final String factureId;

  Future<void> _arreter(BuildContext context, FactureData f, List<OrdonnanceData> ords) async {
    final total = ords.fold<int>(0, (s, o) => s + o.total);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arrêter la facture ?'),
        content: Text('${ords.length} ordonnance(s), total ${formatMontant(total)} FCFA.\n\n'
            'Après l\'arrêt, plus aucune modification n\'est possible (sauf par l\'administrateur).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arrêter')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await FactureService.instance.arreter(f.id);
    if (!context.mounted) return;
    final figee = FactureData(
      id: f.id,
      type: f.type,
      mois: f.mois,
      annee: f.annee,
      statut: 'terminee',
      total: r.total,
      arreteLe: r.arreteLe,
    );
    final nav = Navigator.of(context);
    await partagerFacture(context, figee);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FactureData?>(
      stream: FactureService.instance.facture(factureId),
      builder: (context, fs) {
        final f = fs.data;
        if (f == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('Facture')), body: const Center(child: CircularProgressIndicator()));
        }
        return StreamBuilder<List<OrdonnanceData>>(
          stream: FactureService.instance.ordonnances(factureId),
          builder: (context, os) {
            final ords = os.data ?? <OrdonnanceData>[];
            final total = ords.fold<int>(0, (s, o) => s + o.total);
            final items = <Widget>[];
            String? courant;
            for (final o in ords) {
              if (o.enfant != courant) {
                courant = o.enfant;
                final tEnfant = ords.where((x) => x.enfant == o.enfant).fold<int>(0, (s, x) => s + x.total);
                items.add(Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(o.enfant, style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text('${formatMontant(tEnfant)} FCFA'),
                  ]),
                ));
              }
              items.add(ListTile(
                title: Text('N° ${o.numero}  ·  ${formatDate(o.date)}'),
                subtitle: Text(o.lignes.map((l) => '${l.produit} ×${l.quantite}').join(', ')),
                trailing: Text('${formatMontant(o.total)}'),
                onTap: f.enCours
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OrdonnanceFormScreen(facture: f, ordonnance: o)))
                    : null,
              ));
            }
            return Scaffold(
              appBar: AppBar(title: Text('Facture ${numeroFacture(f.mois, f.annee)}')),
              body: Column(children: [
                Expanded(
                  child: ords.isEmpty
                      ? const Center(child: Text('Aucune ordonnance. Touchez « Nouvelle ordonnance ».'))
                      : ListView(children: items),
                ),
                Material(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('TOTAL : ${formatMontant(total)} FCFA',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (f.enCours)
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: ords.isEmpty ? null : () => _arreter(context, f, ords),
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Arrêter la facture'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => OrdonnanceFormScreen(facture: f))),
                              icon: const Icon(Icons.add),
                              label: const Text('Nouvelle ordonnance'),
                            ),
                          ),
                        ])
                      else
                        const Text('Facture terminée'),
                    ]),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}
