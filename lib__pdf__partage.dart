import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/entreprise.dart';
import '../core/format.dart';
import '../core/montant_en_lettres.dart';
import '../models/ordonnance.dart';
import '../services/facture_service.dart';
import 'facture_commandes_pdf.dart';
import 'facture_ordonnances_pdf.dart';

/// Génère le PDF d'une facture terminée et ouvre le partage (WhatsApp, e-mail, enregistrement…).
Future<void> partagerFacture(BuildContext context, FactureData f) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Entreprise.charger();
    final arretee = f.arreteLe ?? DateTime.now();
    final nom = numeroFacture(f.mois, f.annee).replaceAll(' ', '-');
    if (f.type == 'ordonnances') {
      final ords = await FactureService.instance.ordonnancesUneFois(f.id);
      final total = ords.fold<int>(0, (s, o) => s + o.total);
      final octets = await genererPdfOrdonnances(
        facture: f,
        ordonnances: ords,
        total: total,
        lettres: montantEnLettres(total),
        arreteLe: arretee,
      );
      await Printing.sharePdf(bytes: octets, filename: 'Facture-ordonnances-$nom.pdf');
    } else {
      final cmds = await FactureService.instance.commandesUneFois(f.id);
      final total = cmds.fold<int>(0, (s, c) => s + c.total);
      final octets = await genererPdfCommandes(
        facture: f,
        commandes: cmds,
        total: total,
        lettres: montantEnLettres(total),
        arreteLe: arretee,
      );
      await Printing.sharePdf(bytes: octets, filename: 'Facture-commandes-$nom.pdf');
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Impossible de créer le PDF : $e')));
  }
}
