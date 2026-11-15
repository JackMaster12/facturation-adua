import 'package:pdf/widgets.dart' as pw;

/// Coupe un texte en lignes de [max] caractères au plus, sans couper les mots.
List<String> coupeMots(String t, int max) {
  final lignes = <String>[];
  var cur = '';
  for (final mot in t.split(' ')) {
    if (cur.isEmpty) {
      cur = mot;
    } else if (cur.length + 1 + mot.length <= max) {
      cur = '$cur $mot';
    } else {
      lignes.add(cur);
      cur = mot;
    }
  }
  if (cur.isNotEmpty) lignes.add(cur);
  return lignes;
}

const double _hLigneLettres = 19;
const double _hPhrase = 18;

/// Hauteur du bloc « Arrêtée la présente facture à la somme de : … ».
double hauteurMontantEnLettres(String lettres) => _hPhrase + coupeMots('$lettres.', 62).length * _hLigneLettres + 6;

/// Phrase d'arrêt, puis le montant en lettres en gras, italique, souligné de pointillés.
pw.Widget blocMontantEnLettres({
  required String lettres,
  required pw.Font normal,
  required pw.Font grasItalique,
  required double largeur,
}) {
  final lignes = coupeMots('$lettres.', 62);
  return pw.SizedBox(
    height: hauteurMontantEnLettres(lettres),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(
        height: _hPhrase,
        child: pw.Text('Arrêtée la présente facture à la somme de :', style: pw.TextStyle(font: normal, fontSize: 12)),
      ),
      for (final l in lignes)
        pw.Container(
          width: largeur,
          height: _hLigneLettres,
          alignment: pw.Alignment.centerLeft,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.9, style: pw.BorderStyle.dotted)),
          ),
          child: pw.Text(l, style: pw.TextStyle(font: grasItalique, fontSize: 12)),
        ),
    ]),
  );
}
