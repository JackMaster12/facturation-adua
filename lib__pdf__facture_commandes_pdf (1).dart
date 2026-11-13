import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/entreprise.dart';
import '../core/format.dart';
import '../core/hash.dart';
import '../models/ordonnance.dart';
import 'facture_ordonnances_pdf.dart' show paginer;

const double _marge = 28;
const double _contenuH = 755;
const double _enteteH = 150;
const double _colH = 32;
const double _largeur = 530;
const double _wUnite = 90, _wQte = 52, _wPu = 90, _wMont = 102;
const double _wDes = _largeur - _wUnite - _wQte - _wPu - _wMont;
const double _titreH = 36; // titre de commande (avec un espace au-dessus)

class _Ligne {
  _Ligne(this.type, this.h, {this.keep = false, this.cells = const [], this.texte = ''});
  final String type; // titre | colonnes | ligne | sousTotal
  final double h;
  bool keep;
  final List<String> cells; // désignation, unité, quantité, prix unitaire, montant
  final String texte;
}

double _hauteur(String des, String unite) {
  final a = des.isEmpty ? 1 : ((des.length + 23) ~/ 24);
  final b = unite.isEmpty ? 1 : ((unite.length + 11) ~/ 12);
  return (a > b ? a : b) * 14.0 + 6;
}

pw.TextStyle _st(pw.Font f, {double size = 12}) => pw.TextStyle(font: f, fontSize: size);

Future<Uint8List> genererPdfCommandes({
  required FactureData facture,
  required List<CommandeData> commandes,
  required int total,
  required String lettres,
  required DateTime arreteLe,
}) async {
  final normal = pw.Font.helvetica();
  final gras = pw.Font.helveticaBold();
  final numero = numeroFacture(facture.mois, facture.annee);
  final titre = 'FACTURE SUR COMMANDE N° $numero';
  final cmds = trierCommandes(commandes);

  final lignes = <_Ligne>[];
  for (var i = 0; i < cmds.length; i++) {
    final c = cmds[i];
    lignes.add(_Ligne('titre', _titreH,
        keep: true, texte: 'COMMANDE INFIRMERIE GRYK ${c.libelle} N° ${formatDate(c.date)}'));
    lignes.add(_Ligne('colonnes', _colH, keep: true));
    for (final l in c.lignes) {
      lignes.add(_Ligne('ligne', _hauteur(l.produit, l.unite), cells: [
        l.produit,
        l.unite,
        l.quantite.toString(),
        formatMontant(l.prixUnitaire),
        formatMontant(l.montant),
      ]));
    }
    if (c.lignes.isEmpty) {
      lignes.add(_Ligne('ligne', 20, cells: ['', '', '', '', '']));
    }
    lignes.last.keep = true;
    lignes.add(_Ligne('sousTotal', 22, texte: 'SOUS-TOTAL ${i + 1}', cells: [formatMontant(c.total)]));
  }

  final phrase = 'Arrêtée la présente facture à la somme de : $lettres.';
  final motsH = ((phrase.length + 69) ~/ 70) * 15.0 + 8;
  const sigH = 80.0;
  const totalGenH = 36.0;
  final fin = totalGenH + 14 + motsH + 14 + sigH + 6;

  final pages = paginer(
    [for (final l in lignes) l.h],
    [for (final l in lignes) l.keep],
    _contenuH - _enteteH - 6,
    _contenuH - _colH - 6, // place réservée pour répéter les titres de colonnes
    fin,
  );

  final code = empreinte([
    numero,
    for (final c in cmds) '${c.libelle}/${formatDate(c.date)}/${c.total}',
    '$total',
  ].join(';'));
  final qrData = 'ADUA | COMMANDES | $numero | ${formatMontant(total)} FCFA | '
      'arretee le ${formatDate(arreteLe)} | $code';

  pw.Widget cellule(String t, double w,
      {bool last = false, bool g = false, pw.Alignment al = pw.Alignment.centerLeft, double? h}) {
    return pw.Container(
      width: w,
      height: h,
      alignment: al,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      decoration: last ? null : const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.6))),
      child: pw.Text(t, style: _st(g ? gras : normal)),
    );
  }

  // Ligne de tableau à simple trait : côtés et bas ; le haut seulement pour les titres de colonnes.
  pw.Widget boite(double h, pw.Widget child, {bool haut = false, PdfColor? fond}) => pw.Container(
        width: _largeur,
        height: h,
        decoration: pw.BoxDecoration(
          color: fond,
          border: haut
              ? const pw.Border(
                  left: pw.BorderSide(width: 0.6),
                  right: pw.BorderSide(width: 0.6),
                  bottom: pw.BorderSide(width: 0.6),
                  top: pw.BorderSide(width: 0.6),
                )
              : const pw.Border(
                  left: pw.BorderSide(width: 0.6),
                  right: pw.BorderSide(width: 0.6),
                  bottom: pw.BorderSide(width: 0.6),
                ),
        ),
        child: child,
      );

  pw.Widget entete() => pw.SizedBox(
        height: _enteteH,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Émetteur : $emetteurNom', style: _st(gras)),
                pw.Text('Adresse : $emetteurAdresse', style: _st(normal)),
                pw.Text('Tél : $emetteurTel', style: _st(normal)),
                pw.SizedBox(height: 10),
                pw.Text('Récepteur : $recepteurNom', style: _st(gras)),
                pw.Text('Adresse : $recepteurAdresse', style: _st(normal)),
              ]),
            ),
            pw.SizedBox(
              width: 130,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Text('Arrêtée le ${formatDate(arreteLe)}', style: _st(normal)),
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

  pw.Widget colonnes() => boite(
        _colH,
        pw.Row(children: [
          cellule('Désignation', _wDes, g: true, al: pw.Alignment.center, h: _colH),
          cellule('Unité', _wUnite, g: true, al: pw.Alignment.center, h: _colH),
          cellule('Quantité', _wQte, g: true, al: pw.Alignment.center, h: _colH),
          cellule('Prix unitaire', _wPu, g: true, al: pw.Alignment.center, h: _colH),
          cellule('Montant (FCFA)', _wMont, last: true, g: true, al: pw.Alignment.center, h: _colH),
        ]),
        haut: true,
        fond: PdfColors.grey200,
      );

  pw.Widget rendre(_Ligne l) {
    switch (l.type) {
      case 'titre':
        return pw.Container(
          width: _largeur,
          height: l.h,
          alignment: pw.Alignment.bottomLeft,
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(l.texte, style: _st(gras)),
        );
      case 'colonnes':
        return colonnes();
      case 'sousTotal':
        return boite(
          l.h,
          pw.Row(children: [
            pw.Container(
              width: _largeur - _wMont,
              height: l.h,
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.6))),
              child: pw.Text(l.texte, style: _st(gras)),
            ),
            cellule(l.cells[0], _wMont, last: true, g: true, al: pw.Alignment.centerRight, h: l.h),
          ]),
        );
      default:
        return boite(
          l.h,
          pw.Row(children: [
            cellule(l.cells[0], _wDes, h: l.h),
            cellule(l.cells[1], _wUnite, h: l.h),
            cellule(l.cells[2], _wQte, al: pw.Alignment.centerRight, h: l.h),
            cellule(l.cells[3], _wPu, al: pw.Alignment.centerRight, h: l.h),
            cellule(l.cells[4], _wMont, last: true, al: pw.Alignment.centerRight, h: l.h),
          ]),
        );
    }
  }

  pw.Widget bas() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Total général détaché du dernier tableau.
        pw.Container(
          width: _largeur,
          height: totalGenH,
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Text('TOTAL GÉNÉRAL : ${formatMontant(total)} FCFA', style: _st(gras, size: 16)),
        ),
        pw.SizedBox(height: 14),
        pw.SizedBox(height: motsH, child: pw.Text(phrase, style: _st(normal))),
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
    final idx = pages[p];
    final corps = <pw.Widget>[
      if (p == 0) entete(),
      // Page de suite qui commence au milieu d'une commande : on répète les titres de colonnes.
      if (p > 0 && idx.isNotEmpty && (lignes[idx.first].type == 'ligne' || lignes[idx.first].type == 'sousTotal'))
        colonnes(),
      for (final i in idx) rendre(lignes[i]),
      if (p == n - 1) bas(),
    ];
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(_marge),
      build: (ctx) => pw.Column(children: [
        pw.SizedBox(
          height: _contenuH,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: corps),
        ),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('FACTURE SUR COMMANDE : $numero', style: _st(normal, size: 10)),
          pw.Text('Page ${p + 1}/$n', style: _st(normal, size: 10)),
        ]),
      ]),
    ));
  }
  return doc.save();
}
