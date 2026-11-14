import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/entreprise.dart';
import '../core/format.dart';
import '../core/hash.dart';
import '../core/montant_en_lettres.dart';
import '../models/rapport.dart';
import 'facture_ordonnances_pdf.dart' show paginer;

const double _marge = 28;
const double _contenuH = 755;
const double _enteteH = 175;
const double _colH = 26;
const double _largeur = 530;
const double _wMois = 100, _wFact = 125, _wMont = 95;
const double _wLettre = _largeur - _wMois - _wFact - _wMont;
final PdfColor _rouge = PdfColor.fromInt(0xFFFF0000);

class _R {
  _R(this.bloc, this.type, this.h, this.cells, {this.keep = true, this.dernier = false});
  final int bloc;
  final String type; // ligne | total | general
  final double h;
  final List<String> cells; // mois, facture, montant, lettres
  bool keep;
  bool dernier; // dernière ligne de son bloc
}

double _haut(String lettres, String label, {double base = 12, double hmin = 22}) {
  final a = lettres.isEmpty ? 1 : ((lettres.length + 31) ~/ 32);
  final b = label.isEmpty ? 1 : ((label.length + 17) ~/ 18);
  final n = a > b ? a : b;
  final h = n * (base + 3) + 7;
  return h < hmin ? hmin : h;
}

pw.TextStyle _st(pw.Font f, {double size = 12, PdfColor? couleur}) =>
    pw.TextStyle(font: f, fontSize: size, color: couleur ?? PdfColors.black);

Future<Uint8List> genererPdfRapport({
  required List<MoisRapport> mois,
  required String message,
  required DateTime date,
  required bool manuel,
}) async {
  final normal = pw.Font.times();
  final gras = pw.Font.timesBold();
  final tries = [...mois]..sort((a, b) => (a.annee * 100 + a.mois).compareTo(b.annee * 100 + b.mois));
  final titre = 'RAPPORT : ${titreRapport(tries)}';
  final totalGeneral = tries.fold<int>(0, (s, m) => s + m.total);

  final rows = <_R>[];
  for (var b = 0; b < tries.length; b++) {
    final m = tries[b];
    final lignes = m.lignes.where((l) => l.label.trim().isNotEmpty || l.montant > 0).toList();
    for (var i = 0; i < lignes.length; i++) {
      final l = lignes[i];
      final lettres = nombreEnLettres(l.montant);
      rows.add(_R(b, 'ligne', _haut(lettres, l.label), [i == 0 ? m.libelle : '', l.label, formatMontant(l.montant), lettres]));
    }
    final lt = nombreEnLettres(m.total);
    rows.add(_R(b, 'total', _haut(lt, 'Total du mois'), ['', 'Total du mois', formatMontant(m.total), lt], dernier: true));
  }
  final lg = nombreEnLettres(totalGeneral);
  final bGen = tries.length;
  rows.add(_R(bGen, 'general', _haut(lg, 'Total général', base: 16, hmin: 30) + 4, ['', 'Total général', formatMontant(totalGeneral), lg],
      dernier: true));

  // Une page ne coupe jamais un mois : toutes les lignes d'un bloc restent ensemble.
  for (var i = 0; i < rows.length; i++) {
    rows[i].keep = !rows[i].dernier;
  }

  final msg = message.trim();
  final msgH = msg.isEmpty ? 0.0 : ((msg.length + 84) ~/ 85) * 15.0 + 22;
  const sigH = 80.0;
  final fin = msgH + 14 + sigH + 6;

  final hauteurs = [
    for (final r in rows) r.h + (r.dernier ? 4 + 10 : 0) // épaisseur du trait + espace sous le bloc
  ];
  final pages = paginer(
    hauteurs,
    [for (final r in rows) r.keep],
    _contenuH - _enteteH - _colH - 6,
    _contenuH - _colH - 6,
    fin,
  );

  final code = empreinte([
    titre,
    for (final m in tries) '${m.libelle}/${m.total}',
    '$totalGeneral',
  ].join(';'));
  final qrData = 'ADUA | RAPPORT | ${titreRapport(tries)} | ${formatMontant(totalGeneral)} FCFA | '
      '${manuel ? 'saisie manuelle | ' : ''}genere le ${formatDate(date)} | $code';

  pw.Widget cellule(String t, double w, double h, pw.Font f,
      {bool last = false, pw.Alignment al = pw.Alignment.centerLeft, double size = 12, PdfColor? couleur}) {
    return pw.Container(
      width: w,
      height: h,
      alignment: al,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      decoration: last ? null : const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.6))),
      child: pw.Text(t, style: _st(f, size: size, couleur: couleur)),
    );
  }

  pw.Widget entete() => pw.SizedBox(
        height: _enteteH,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Émetteur : $emetteurNom', style: _st(gras)),
                pw.Text('Adresse : $emetteurAdresse · Tél : $emetteurTel', style: _st(normal)),
                pw.Text('NIF : $emetteurNif', style: _st(normal)),
                pw.Text('Compte bancaire : $emetteurBanque', style: _st(normal)),
                pw.SizedBox(height: 10),
                pw.Text('Récepteur : $recepteurNom', style: _st(gras)),
                pw.Text('Adresse : $recepteurAdresse', style: _st(normal)),
              ]),
            ),
            pw.SizedBox(
              width: 130,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Text('Généré le ${formatDate(date)}', style: _st(normal)),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrData, width: 90, height: 90, drawText: false),
              ]),
            ),
          ]),
          pw.Spacer(),
          pw.Center(child: pw.Text(titre, style: _st(gras, size: 14))),
          pw.SizedBox(height: 8),
        ]),
      );

  pw.Widget titres() => pw.Container(
        width: _largeur,
        height: _colH,
        decoration: pw.BoxDecoration(color: PdfColors.grey200, border: pw.Border.all(width: 0.8)),
        child: pw.Row(children: [
          cellule('Mois', _wMois, _colH, gras, al: pw.Alignment.center),
          cellule('Factures', _wFact, _colH, gras, al: pw.Alignment.center),
          cellule('Montants (FCFA)', _wMont, _colH, gras, al: pw.Alignment.center),
          cellule('Montant en lettre', _wLettre, _colH, gras, al: pw.Alignment.center, last: true),
        ]),
      );

  pw.Widget ligne(_R r) {
    final g = r.type == 'ligne' ? normal : gras;
    final gen = r.type == 'general';
    return pw.Container(
      width: _largeur - 6,
      height: r.h - (gen ? 4 : 0),
      decoration: r.dernier ? null : const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
      child: pw.Row(children: [
        cellule(r.cells[0], _wMois - 3, r.h - (gen ? 4 : 0), r.type == 'ligne' ? gras : g),
        cellule(r.cells[1], _wFact, r.h - (gen ? 4 : 0), g, size: gen ? 14 : 12),
        cellule(r.cells[2], _wMont, r.h - (gen ? 4 : 0), g,
            al: pw.Alignment.centerRight, size: gen ? 16 : 12),
        cellule(r.cells[3], _wLettre - 3, r.h - (gen ? 4 : 0), g,
            last: true, couleur: gen ? _rouge : null),
      ]),
    );
  }

  // Contour extérieur épais et foncé pour chaque mois (et pour le total général).
  pw.Widget bloc(List<_R> l) => pw.Column(children: [
        pw.Container(
          width: _largeur,
          padding: const pw.EdgeInsets.all(1),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 2, color: PdfColors.black)),
          child: pw.Column(children: [for (final r in l) ligne(r)]),
        ),
        pw.SizedBox(height: 10),
      ]);

  pw.Widget bas() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (msg.isNotEmpty)
          pw.Container(
            width: _largeur,
            height: msgH,
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Message : ', style: _st(gras)),
                pw.TextSpan(text: msg, style: _st(normal)),
              ]),
            ),
          ),
        pw.SizedBox(height: 14),
        pw.SizedBox(
          height: sigH,
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 20),
              child: pw.Text('LE GERANT',
                  style: pw.TextStyle(font: gras, fontSize: 12, decoration: pw.TextDecoration.underline)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 20),
              child: pw.Text('LE CLIENT',
                  style: pw.TextStyle(font: gras, fontSize: 12, decoration: pw.TextDecoration.underline)),
            ),
          ]),
        ),
      ]);

  final doc = pw.Document(title: titre, author: emetteurNom);
  final n = pages.length;
  for (var p = 0; p < n; p++) {
    final corps = <pw.Widget>[if (p == 0) entete(), titres(), pw.SizedBox(height: 6)];
    // Regrouper les lignes consécutives d'un même bloc.
    var courant = <_R>[];
    int? numBloc;
    for (final i in pages[p]) {
      final r = rows[i];
      if (numBloc != null && r.bloc != numBloc) {
        corps.add(bloc(courant));
        courant = <_R>[];
      }
      numBloc = r.bloc;
      courant.add(r);
    }
    if (courant.isNotEmpty) corps.add(bloc(courant));
    if (p == n - 1) corps.add(bas());
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(_marge),
      build: (ctx) => pw.Column(children: [
        pw.SizedBox(
          height: _contenuH,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: corps),
        ),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('DEPOT PHARMACEUTIQUE ADUA - ONG GRYK ZINDER', style: _st(normal, size: 10)),
          pw.Text('Page ${p + 1}/$n', style: _st(normal, size: 10)),
        ]),
      ]),
    ));
  }
  return doc.save();
}
