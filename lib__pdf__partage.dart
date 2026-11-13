import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/format.dart';
import '../core/montant_en_lettres.dart';
import '../models/ordonnance.dart';
import '../services/facture_service.dart';
import 'facture_ordonnances_pdf.dart';

/// Génère le PDF d'une facture terminée et ouvre le partage (WhatsApp, e-mail, enregistrement…).
Future<void> partagerFacture(BuildContext context, FactureData f) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ords = await FactureService.instance.ordonnancesUneFois(f.id);
    final total = ords.fold<int>(0, (s, o) => s + o.total);
    final octets = await genererPdfOrdonnances(
      facture: f,
      ordonnances: ords,
      total: total,
      lettres: montantEnLettres(total),
      arreteLe: f.arreteLe ?? DateTime.now(),
    );
    await Printing.sharePdf(bytes: octets, filename: 'Facture-ordonnances-${numeroFacture(f.mois, f.annee).replaceAll(' ', '-')}.pdf');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Impossible de créer le PDF : $e')));
  }
}
