import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/entreprise.dart';
import '../core/format.dart';
import '../core/hash.dart';
import '../models/ordonnance.dart';
import 'outils_pdf.dart';

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

class _U {
  _U(this.type, this.h, {this.keep = false, this.texte = '', this.ord, this.dateKey = '', this.numero = 0});
  final String type; // bandeau | ord | totalEnfant
  final double h;
  bool keep;
  final String texte;
  final OrdonnanceData? ord;
  final String dateKey;
  final int numero;
}

double _hauteurTexte(String t) {
  final n = t.isEmpty ? 1 : ((t.length + _carParLigne - 1) ~/ _carParLigne);
  return n * 14.0 + 6;
}

const double _ecartOrd = 4; // bande entre deux ordonnances : forme le double trait

/// Hauteur des produits d'une ordonnance, sans le double trait de séparation.
double _hauteurProduits(OrdonnanceData o) {
  if (o.lignes.isEmpty) return 20;
  var h = 0.0;
  for (final l in o.lignes) {
    h += _hauteurTexte(l.produit);
  }
  return h;
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
  // L'en-tête s'agrandit si le récepteur a des informations supplémentaires.
  final nbInfos = recepteurInfosLignes.length;
  final enteteH = _enteteH + (nbInfos > 2 ? (nbInfos - 2) * 14.0 : 0.0);
  final gras = pw.Font.helveticaBold();
  final grasItalique = pw.Font.helveticaBoldOblique();
  final numero = numeroFacture(facture.mois, facture.annee);
  final titre = 'FACTURE SUR ORDONNANCES ENFANTS N° $numero';

  // Ordre chronologique : enfants selon leur ordonnance la plus ancienne, ordonnances par date croissante.
  final tri = trierOrdonnancesSaisie(ordonnances);
  final numeros = numerosOrdonnances(ordonnances);
  final enfants = <String>[];
  final groupes = <String, List<OrdonnanceData>>{};
  for (final o in tri) {
    if (!groupes.containsKey(o.enfant)) {
      enfants.add(o.enfant);
      groupes[o.enfant] = [];
    }
    groupes[o.enfant]!.add(o);
  }

  final lignes = <_U>[];
  for (final e in enfants) {
    lignes.add(_U('bandeau', 22, keep: true, texte: e));
    var totEnfant = 0;
    for (final o in groupes[e]!) {
      totEnfant += o.total;
      lignes.add(_U('ord', _hauteurProduits(o) + _ecartOrd, ord: o, dateKey: '$e|${formatDate(o.date)}', numero: numeros[o.id] ?? 0));
    }
    lignes.last.keep = true;
    lignes.add(_U('totalEnfant', 22, texte: 'TOTAL $e : ${formatMontant(totEnfant)} FCFA'));
  }

  // Hauteur du bloc final.
  final motsH = hauteurMontantEnLettres(lettres);
  const sigH = 80.0;
  const totalGenH = 32.0;
  final fin = totalGenH + 14 + motsH + 14 + sigH + 6;

  final pages = paginer(
    [for (final l in lignes) l.h],
    [for (final l in lignes) l.keep],
    _contenuH - enteteH - _colH - _cadreH,
    _contenuH - _colH - _cadreH,
    fin,
  );

  final contenuQr = [
    numero,
    for (final o in tri) '${o.enfant}/${numeros[o.id]}/${formatDate(o.date)}/${o.total}',
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
        height: enteteH,
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
                for (final t in recepteurInfosLignes) pw.Text(t, style: _st(normal)),
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

  pw.Widget ligne(_U l) {
    if (l.type == 'bandeau') {
      return enveloppe(
        l.h,
        pw.Container(
          alignment: pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3),
          child: pw.Text(l.texte, style: _st(gras)),
        ),
        fond: PdfColors.grey300,
      );
    }
    return enveloppe(
      l.h,
      pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3),
        child: pw.Text(l.texte, style: _st(gras)),
      ),
    );
  }

  const bordBas = pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6)));
  const bordDroite = pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.6)));
  const bordDroiteBas =
      pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.6), bottom: pw.BorderSide(width: 0.6)));

  // Une ordonnance : cellule du numéro fusionnée sur toutes ses lignes de produits.
  pw.Widget blocOrd(_U u) {
    final o = u.ord!;
    final reste = _largeur - _wDate - _wNum;
    final produits = <pw.Widget>[];
    if (o.lignes.isEmpty) {
      produits.add(pw.SizedBox(width: reste, height: u.h - _ecartOrd));
    }
    for (var k = 0; k < o.lignes.length; k++) {
      final l = o.lignes[k];
      final h = _hauteurTexte(l.produit);
      produits.add(pw.Container(
        width: reste,
        height: h,
        decoration: k == o.lignes.length - 1 ? null : bordBas,
        child: pw.Row(children: [
          cellule(l.produit, _wProd, h: h),
          cellule(l.quantite.toString(), _wQte, al: pw.Alignment.centerRight, h: h),
          cellule(formatMontant(l.montant), _wMont, last: true, al: pw.Alignment.centerRight, h: h),
        ]),
      ));
    }
    final hp = u.h - _ecartOrd;
    return pw.Column(children: [
      pw.Container(
        width: _largeur - _wDate,
        height: hp,
        decoration: bordBas,
        child: pw.Row(children: [
          pw.Container(
            width: _wNum,
            height: hp,
            alignment: pw.Alignment.center,
            decoration: bordDroite,
            child: pw.Text('${u.numero}', style: _st(normal)),
          ),
          pw.Column(children: produits),
        ]),
      ),
      // Deuxième trait, juste sous le premier : séparation visible entre deux ordonnances.
      pw.Container(
        width: _largeur - _wDate,
        height: _ecartOrd,
        decoration: bordBas,
        child: pw.Row(children: [
          pw.Container(width: _wNum, height: _ecartOrd, decoration: bordDroite),
          pw.Container(width: _wProd, height: _ecartOrd, decoration: bordDroite),
          pw.Container(width: _wQte, height: _ecartOrd, decoration: bordDroite),
        ]),
      ),
    ]);
  }

  // Une date : cellule fusionnée sur toutes les ordonnances consécutives de cette date.
  pw.Widget blocDate(List<_U> l) {
    var h = 0.0;
    for (final u in l) {
      h += u.h;
    }
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        width: _wDate,
        height: h,
        alignment: pw.Alignment.center,
        decoration: bordDroiteBas,
        child: pw.Text(formatDate(l.first.ord!.date), style: _st(normal)),
      ),
      pw.Column(children: [for (final u in l) blocOrd(u)]),
    ]);
  }

  List<pw.Widget> contenuPage(List<int> idx) {
    final w = <pw.Widget>[];
    var i = 0;
    while (i < idx.length) {
      final u = lignes[idx[i]];
      if (u.type != 'ord') {
        w.add(ligne(u));
        i++;
        continue;
      }
      var j = i;
      while (j < idx.length && lignes[idx[j]].type == 'ord' && lignes[idx[j]].dateKey == u.dateKey) {
        j++;
      }
      w.add(blocDate([for (var k = i; k < j; k++) lignes[idx[k]]]));
      i = j;
    }
    return w;
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
        blocMontantEnLettres(lettres: lettres, normal: normal, grasItalique: grasItalique, largeur: _largeur),
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
        ...contenuPage(pages[p]),
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
