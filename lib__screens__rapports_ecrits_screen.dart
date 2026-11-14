import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/entreprise.dart';
import '../core/format.dart';
import '../models/rapport.dart';
import '../pdf/rapport_pdf.dart';
import '../services/auth_service.dart';
import '../services/rapport_service.dart';
import 'rapport_form_screen.dart';

Future<void> partagerRapportEcrit(BuildContext context, RapportData r) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Entreprise.charger();
    final octets = await genererPdfRapport(
      mois: r.mois,
      message: r.message,
      date: DateTime.now(),
      manuel: true,
    );
    await Printing.sharePdf(bytes: octets, filename: 'Rapport-${r.titre.replaceAll(' ', '-')}.pdf');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Impossible de créer le PDF : $e')));
  }
}

class RapportsEcritsScreen extends StatelessWidget {
  const RapportsEcritsScreen({super.key, required this.profil});
  final UserProfile profil;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports rédigés')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => RapportFormScreen(profil: profil))),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau rapport'),
      ),
      body: StreamBuilder<List<RapportData>>(
        stream: RapportService.instance.liste(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final l = snap.data!;
          if (l.isEmpty) {
            return const Center(
                child: Padding(padding: EdgeInsets.all(24), child: Text('Aucun rapport. Touchez « Nouveau rapport ».')));
          }
          return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            for (final r in l)
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text(r.titre),
                subtitle: Text('${r.mois.length} mois  ·  '
                    '${formatMontant(r.mois.fold<int>(0, (s, m) => s + m.total))} FCFA'),
                trailing: IconButton(
                  tooltip: 'Partager le PDF',
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => partagerRapportEcrit(context, r),
                ),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => RapportFormScreen(profil: profil, rapport: r))),
              ),
          ]);
        },
      ),
    );
  }
}
