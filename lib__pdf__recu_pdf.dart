import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/entreprise.dart';
import '../core/format.dart';
import '../core/montant_en_lettres.dart';
import '../models/vente.dart';
import 'outils_pdf.dart' show coupeMots;

/// Reçu de vente au format ticket (imprimante thermique), largeur 58 ou 80 mm.
/// La hauteur est calculée d'après le contenu : le papier n'est pas gaspillé.
class RecuPdf {
  RecuPdf(this.octets, this.format);
  final Uint8List octets;
  final PdfPageFormat format;
}

Future<RecuPdf> genererRecu(VenteData v, {int largeurMm = 58}) async {
  final normal = pw.Font.helvetica();
  final gras = pw.Font.helveticaBold();
  final grasItalique = pw.Font.helveticaBoldOblique();

  final large = largeurMm >= 80;
  final larg = largeurMm * PdfPageFormat.mm;
  const marge = 6.0;
  final contenu = larg - 2 * marge;
  final t = large ? 9.5 : 8.0; // taille du texte
  final lh = t * 1.35; // hauteur d'une ligne
  // Nombre de caractères par ligne (estimation prudente de la largeur moyenne d'un caractère).
  // Le gras est plus large : on prévoit moins de caractères par ligne.
  int cars(double taille, {bool gras_ = false}) => (contenu / (taille * (gras_ ? 0.66 : 0.58))).floor();

  final rows = <({double h, pw.Widget w})>[];

  void texte(String s, {pw.Font? f, double? taille, pw.TextAlign al = pw.TextAlign.left}) {
    final tt = taille ?? t;
    final h = tt * 1.35;
    for (final l in coupeMots(s, cars(tt, gras_: f != null && f != normal))) {
      rows.add((
        h: h,
        w: pw.SizedBox(
          height: h,
          width: contenu,
          child: pw.Text(l, textAlign: al, style: pw.TextStyle(font: f ?? normal, fontSize: tt)),
        ),
      ));
    }
  }

  void deuxColonnes(String g, String d, {pw.Font? f, double? taille}) {
    final tt = taille ?? t;
    final h = tt * 1.35;
    rows.add((
      h: h,
      w: pw.SizedBox(
        height: h,
        width: contenu,
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(g, style: pw.TextStyle(font: f ?? normal, fontSize: tt)),
          pw.Text(d, style: pw.TextStyle(font: f ?? normal, fontSize: tt)),
        ]),
      ),
    ));
  }

  void trait() {
    rows.add((
      h: 8,
      w: pw.Container(
        height: 8,
        width: contenu,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.7, style: pw.BorderStyle.dashed)),
        ),
      ),
    ));
    rows.add((h: 4, w: pw.SizedBox(height: 4)));
  }

  // En-tête : le même que les factures (émetteur).
  texte(emetteurNom, f: gras, taille: t + 2, al: pw.TextAlign.center);
  texte(emetteurAdresse, al: pw.TextAlign.center);
  texte('Tél : $emetteurTel', al: pw.TextAlign.center);
  texte('NIF : $emetteurNif', al: pw.TextAlign.center);
  trait();

  texte('REÇU DE VENTE', f: gras, taille: t + 1, al: pw.TextAlign.center);
  texte('N° ${v.numero}', al: pw.TextAlign.center);
  texte('Date : ${formatDate(v.date)}');
  texte('Client : ${v.client}', f: gras);
  trait();

  for (final l in v.lignes) {
    texte(l.produit, f: gras);
    deuxColonnes('${l.quantite} x ${formatMontant(l.prix)}', formatMontant(l.montant));
    rows.add((h: 3, w: pw.SizedBox(height: 3)));
  }
  trait();

  deuxColonnes('TOTAL', '${formatMontant(v.total)} FCFA', f: gras, taille: t + 2);
  rows.add((h: 6, w: pw.SizedBox(height: 6)));
  texte('Arrêté le présent reçu à la somme de :');
  texte('${montantEnLettres(v.total)}.', f: grasItalique);
  trait();
  texte('Merci de votre confiance.', al: pw.TextAlign.center);

  final hauteur = rows.fold<double>(0, (s, r) => s + r.h) + 2 * marge + lh * 2;
  final format = PdfPageFormat(larg, hauteur);
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(marge),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [for (final r in rows) r.w]),
  ));
  return RecuPdf(await doc.save(), format);
}

String _nomFichier(VenteData v) => 'Recu-${v.numero}';

/// Imprimer : ouvre la fenêtre d'impression d'Android (imprimante installée, ou « Enregistrer au format PDF »).
Future<void> imprimerRecu(BuildContext context, VenteData v) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Entreprise.charger();
    final r = await genererRecu(v, largeurMm: Entreprise.courant.largeurRecu);
    await Printing.layoutPdf(onLayout: (_) async => r.octets, name: _nomFichier(v), format: r.format);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Impression impossible : $e')));
  }
}

/// Partager le reçu en PDF (WhatsApp, e-mail, application de l'imprimante…).
Future<void> partagerRecuPdf(BuildContext context, VenteData v) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Entreprise.charger();
    final r = await genererRecu(v, largeurMm: Entreprise.courant.largeurRecu);
    await Printing.sharePdf(bytes: r.octets, filename: '${_nomFichier(v)}.pdf');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Partage impossible : $e')));
  }
}

/// Partager le reçu en image (s'affiche directement dans la conversation WhatsApp).
Future<void> partagerRecuImage(BuildContext context, VenteData v) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Entreprise.charger();
    final r = await genererRecu(v, largeurMm: Entreprise.courant.largeurRecu);
    await for (final page in Printing.raster(r.octets, dpi: 220)) {
      final png = await page.toPng();
      final dossier = await getTemporaryDirectory();
      final f = File('${dossier.path}/${_nomFichier(v)}.png');
      await f.writeAsBytes(png);
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')], text: 'Reçu ${v.numero}');
      break;
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Partage impossible : $e')));
  }
}
