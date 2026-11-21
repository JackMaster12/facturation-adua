import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/vente.dart';
import '../pdf/recu_pdf.dart';
import '../services/auth_service.dart';

/// Les dernières ventes : on peut réimprimer ou repartager un reçu.
class VentesHistoriqueScreen extends StatelessWidget {
  const VentesHistoriqueScreen({super.key, required this.profil});
  final UserProfile profil;

  void _detail(BuildContext context, VenteData v) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reçu N° ${v.numero}', style: Theme.of(ctx).textTheme.titleMedium),
            Text('${formatDate(v.date)}  ·  ${v.client}'),
            const SizedBox(height: 8),
            for (final l in v.lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text('${l.produit}  (${l.quantite} x ${formatMontant(l.prix)})')),
                  Text(formatMontant(l.montant)),
                ]),
              ),
            const Divider(),
            Text('TOTAL : ${formatMontant(v.total)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                    onPressed: () => imprimerRecu(context, v), icon: const Icon(Icons.print), label: const Text('Imprimer')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                    onPressed: () => partagerRecuImage(context, v),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Image')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                    onPressed: () => partagerRecuPdf(context, v),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF')),
              ),
            ]),
            if (profil.isAdmin)
              TextButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: const Text('Supprimer cette vente ?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    FirebaseFirestore.instance.collection('ventes').doc(v.id).delete().catchError((_) {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer la vente'),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des ventes')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('ventes').orderBy('date', descending: true).limit(100).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Erreur de lecture des données.'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final ventes = [for (final d in snap.data!.docs) VenteData.fromDoc(d)]
            ..sort((a, b) {
              final c = formatDateCle(b.date).compareTo(formatDateCle(a.date));
              return c != 0 ? c : b.numero.compareTo(a.numero);
            });
          if (ventes.isEmpty) return const Center(child: Text('Aucune vente enregistrée.'));
          final items = <Widget>[];
          for (var i = 0; i < ventes.length; i++) {
            final v = ventes[i];
            if (i == 0 || formatDateCle(ventes[i - 1].date) != formatDateCle(v.date)) {
              final totalJour = ventes
                  .where((x) => formatDateCle(x.date) == formatDateCle(v.date))
                  .fold<int>(0, (s, x) => s + x.total);
              items.add(Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(formatDate(v.date), style: const TextStyle(fontWeight: FontWeight.bold))),
                  Text('${formatMontant(totalJour)} FCFA'),
                ]),
              ));
            }
            items.add(ListTile(
              title: Text(v.client),
              subtitle: Text('N° ${v.numero}  ·  ${v.lignes.length} produit(s)'),
              trailing: Text(formatMontant(v.total), style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _detail(context, v),
            ));
          }
          return ListView(children: items);
        },
      ),
    );
  }
}

/// Clé de comparaison d'un jour : 20261121.
int formatDateCle(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
