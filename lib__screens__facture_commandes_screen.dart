import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/ordonnance.dart';
import '../pdf/partage.dart';
import '../services/facture_service.dart';
import 'commande_form_screen.dart';

class FactureCommandesScreen extends StatelessWidget {
  const FactureCommandesScreen({super.key, required this.factureId});
  final String factureId;

  Future<void> _arreter(BuildContext context, FactureData f, List<CommandeData> cmds) async {
    final total = cmds.fold<int>(0, (s, c) => s + c.total);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arrêter la facture ?'),
        content: Text('${cmds.length} commande(s), total ${formatMontant(total)} FCFA.\n\n'
            'Après l\'arrêt, plus aucune modification n\'est possible (sauf par l\'administrateur).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arrêter')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await FactureService.instance.arreterCommandes(f.id);
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
        return StreamBuilder<List<CommandeData>>(
          stream: FactureService.instance.commandes(factureId),
          builder: (context, cs) {
            final cmds = cs.data ?? <CommandeData>[];
            final total = cmds.fold<int>(0, (s, c) => s + c.total);
            return Scaffold(
              appBar: AppBar(title: Text('Commandes ${numeroFacture(f.mois, f.annee)}')),
              body: Column(children: [
                Expanded(
                  child: cmds.isEmpty
                      ? const Center(child: Text('Aucune commande. Touchez « Nouvelle commande ».'))
                      : ListView(children: [
                          for (var i = 0; i < cmds.length; i++)
                            ListTile(
                              title: Text('SOUS-TOTAL ${i + 1} : ${cmds[i].libelle}'),
                              subtitle: Text('${formatDate(cmds[i].date)}  ·  '
                                  '${cmds[i].lignes.map((l) => l.produit).join(', ')}'),
                              trailing: Text(formatMontant(cmds[i].total)),
                              onTap: f.enCours
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => CommandeFormScreen(facture: f, commande: cmds[i])))
                                  : null,
                            ),
                        ]),
                ),
                Material(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('TOTAL GÉNÉRAL : ${formatMontant(total)} FCFA',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (f.enCours)
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: cmds.isEmpty ? null : () => _arreter(context, f, cmds),
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Arrêter la facture'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => CommandeFormScreen(facture: f))),
                              icon: const Icon(Icons.add),
                              label: const Text('Nouvelle commande'),
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
