import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/entreprise.dart';
import '../core/format.dart';
import '../core/hash.dart';
import '../models/ordonnance.dart';

// ---- Dimensions (en points PDF) -------------------------------------------
const double _marge = 28;
const double _contenuH = 755; // hauteur utile sans le pied de page
const double _enteteH = 150; // en-tête de la 1re page (émetteur, récepteur, QR, titre)
const double _colH = 32; // ligne des titres de colonnes
const double _cadreH = 8; // épaisseur du double cadre (haut + bas)
const double _largeur = 530; // largeur intérieure du tableau
const double _wDate = 68, _wNum = 80, _wQte = 56, _wMont = 90;
const double _wProd = _largeur - _wDate - _wNum - _wQte - _wMont;
const int _carParLigne = 30; // estimation prudente des caractères par ligne (produits)

/// Découpe les lignes en pages. [h] = hauteur de chaque ligne, [keep] = vrai si
/// la ligne ne doit pas être séparée de la suivante. [fin] = hauteur du bloc final
/// (total général, montant en lettres, signatures). Retourne les indices par page.
List<List<int>> paginer(List<double> h, List<bool> keep, double cap1, double capN, double fin) {
  final blocs = <List<int>>[];
  var cur = <int>[];
  for (var i = 0; i < h.length; i++) {
    cur.add(i);
    if (!keep[i]) {
      blocs.add(cur);
      cur = <int>[];
    }
  }
  if (cur.isNotEmpty) blocs.add(cur);

  final pages = <List<int>>[<int>[]];
  var used = 0.0;
  var cap = cap1;
  for (final b in blocs) {
    var bh = 0.0;
    for (final i in b) {
      bh += h[i];
    }
    if (used + bh > cap && pages.last.isNotEmpty) {
      pages.add(<int>[]);
      used = 0;
      cap = capN;
    }
    pages.last.addAll(b);
    used += bh;
  }
  if (used + fin > cap) {
    if (blocs.isNotEmpty && pages.last.length > blocs.last.length) {
      final n = blocs.last.length;
      final p = pages.last;
      final deplace = p.sublist(p.length - n);
      p.removeRange(p.length - n, p.length);
      pages.add(deplace);
    } else {
      pages.add(<int>[]);
    }
  }
  return pages;
}

class _Ligne {
  _Ligne(this.type, this.h, {this.keep = false, this.cells = const [], this.texte = ''});
  final String type; // bandeau | ligne | totalEnfant
  final double h;
  bool keep;
  final List<String> cells; // date, numéro, produit, quantité, montant
  final String texte;
}

double _hauteurTexte(String t) {
  final n = t.isEmpty ? 1 : ((t.length + _carParLigne - 1) ~/ _carParLigne);
  return n * 14.0 + 6;
}

pw.TextStyle _st(pw.Font f, {double size = 12}) => pw.TextStyle(font: f, fontSize: size);

Future<Uint8List> genererPdfOrdonnances({
  required FactureData facture,
  required List<OrdonnanceData> ordonnances,
  required int total,
  required String lettres,
  required DateTime arreteLe,
}) async {
  final normal = pw.Font.helvetica();
  final gras = pw.Font.helveticaBold();
  final numero = numeroFacture(facture.mois, facture.annee);
  final titre = 'FACTURE SUR ORDONNANCES ENFANTS N° $numero';

  // Regroupement par enfant, puis par date et numéro.
  final tri = [...ordonnances]..sort((a, b) {
      final c = a.enfant.toLowerCase().compareTo(b.enfant.toLowerCase());
      if (c != 0) return c;
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.numero.compareTo(b.numero);
    });

  final lignes = <_Ligne>[];
  String? courant;
  int totEnfant = 0;
  void clore() {
    if (courant == null) return;
    lignes.last.keep = true;
    lignes.add(_Ligne('totalEnfant', 22, texte: 'TOTAL $courant : ${formatMontant(totEnfant)} FCFA'));
  }

  for (final o in tri) {
    if (o.enfant != courant) {
      clore();
      courant = o.enfant;
      totEnfant = 0;
      lignes.add(_Ligne('bandeau', 22, keep: true, texte: o.enfant));
    }
    totEnfant += o.total;
    var premiere = true;
    for (final l in o.lignes) {
      lignes.add(_Ligne('ligne', _hauteurTexte(l.produit), cells: [
        premiere ? formatDate(o.date) : '',
        premiere ? o.numero : '',
        l.produit,
        l.quantite.toString(),
        formatMontant(l.montant),
      ]));
      premiere = false;
    }
    if (o.lignes.isEmpty) {
      lignes.add(_Ligne('ligne', 20, cells: [formatDate(o.date), o.numero, '', '', '0']));
    }
  }
  clore();

  // Hauteur du bloc final.
  final phrase = 'Arrêtée la présente facture à la somme de : $lettres.';
  final lignesPhrase = (phrase.length + 69) ~/ 70;
  final motsH = lignesPhrase * 15.0 + 8;
  const sigH = 80.0;
  const totalGenH = 32.0;
  final fin = totalGenH + 14 + motsH + 14 + sigH + 6;

  final pages = paginer(
    [for (final l in lignes) l.h],
    [for (final l in lignes) l.keep],
    _contenuH - _enteteH - _colH - _cadreH,
    _contenuH - _colH - _cadreH,
    fin,
  );

  final contenuQr = [
    numero,
    for (final o in tri) '${o.enfant}/${o.numero}/${formatDate(o.date)}/${o.total}',
  ].join(';');
  final code = empreinte('$contenuQr;$total');
  final qrData = 'ADUA | ORDONNANCES | $numero | ${formatMontant(total)} FCFA | '
      'arretee le ${formatDate(arreteLe)} | $code';

  pw.Widget cellule(String t, double w, {bool last = false, bool gras_ = false, pw.Alignment al = pw.Alignment.centerLeft, double? h}) {
    return pw.Container(
      width: w,
      height: h,
      alignment: al,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      decoration: last ? null : const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.6))),
      child: pw.Text(t, style: _st(gras_ ? gras : normal)),
    );
  }

  pw.Widget enveloppe(double h, pw.Widget child, {PdfColor? fond}) => pw.Container(
        height: h,
        decoration: pw.BoxDecoration(
          color: fond,
          border: const pw.Border(bottom: pw.BorderSide(width: 0.6)),
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

  pw.Widget titresColonnes() => enveloppe(
        _colH,
        pw.Row(children: [
          cellule('Date', _wDate, gras_: true, al: pw.Alignment.center, h: _colH),
          cellule('N° d\'ordonnance', _wNum, gras_: true, al: pw.Alignment.center, h: _colH),
          cellule('Produits', _wProd, gras_: true, al: pw.Alignment.center, h: _colH),
          cellule('Quantité', _wQte, gras_: true, al: pw.Alignment.center, h: _colH),
          cellule('Montant (FCFA)', _wMont, last: true, gras_: true, al: pw.Alignment.center, h: _colH),
        ]),
        fond: PdfColors.grey200,
      );

  pw.Widget ligne(_Ligne l) {
    switch (l.type) {
      case 'bandeau':
        return enveloppe(
          l.h,
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3),
            child: pw.Text(l.texte, style: _st(gras)),
          ),
          fond: PdfColors.grey300,
        );
      case 'totalEnfant':
        return enveloppe(
          l.h,
          pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3),
            child: pw.Text(l.texte, style: _st(gras)),
          ),
        );
      default:
        return enveloppe(
          l.h,
          pw.Row(children: [
            cellule(l.cells[0], _wDate, h: l.h),
            cellule(l.cells[1], _wNum, h: l.h),
            cellule(l.cells[2], _wProd, h: l.h),
            cellule(l.cells[3], _wQte, al: pw.Alignment.centerRight, h: l.h),
            cellule(l.cells[4], _wMont, last: true, al: pw.Alignment.centerRight, h: l.h),
          ]),
        );
    }
  }

  // Double cadre : un cadre épais extérieur, un cadre fin intérieur.
  pw.Widget cadre(List<pw.Widget> enfants) => pw.Container(
        width: _largeur + 8,
        padding: const pw.EdgeInsets.all(2),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
        child: pw.Container(
          width: _largeur,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
          child: pw.Column(children: enfants),
        ),
      );

  pw.Widget bas() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(height: 14),
        pw.SizedBox(
          height: motsH,
          child: pw.Text(phrase, style: _st(normal)),
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
    final derniere = p == n - 1;
    final corps = <pw.Widget>[
      if (p == 0) entete(),
      cadre([
        titresColonnes(),
        for (final i in pages[p]) ligne(lignes[i]),
        if (derniere)
          pw.Container(
            height: totalGenH,
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Text('TOTAL GÉNÉRAL : ${formatMontant(total)} FCFA', style: _st(gras, size: 16)),
          ),
      ]),
      if (derniere) bas(),
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
          pw.Text('FACTURE SUR ORDONNANCES ENFANTS : $numero', style: _st(normal, size: 10)),
          pw.Text('Page ${p + 1}/$n', style: _st(normal, size: 10)),
        ]),
      ]),
    ));
  }
  return doc.save();
}
