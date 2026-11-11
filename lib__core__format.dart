const List<String> moisFr = [
  'JANVIER', 'FÉVRIER', 'MARS', 'AVRIL', 'MAI', 'JUIN',
  'JUILLET', 'AOÛT', 'SEPTEMBRE', 'OCTOBRE', 'NOVEMBRE', 'DÉCEMBRE',
];

/// 1250000 -> « 1 250 000 »
String formatMontant(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Date au format français court : 23/10/2026
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Numéro de facture : « OCTOBRE 2026 »
String numeroFacture(int mois, int annee) => '${moisFr[mois - 1]} $annee';

/// Identifiant fixe d'une facture : ORD-2026-10 ou CMD-2026-10
String idFacture(String type, int mois, int annee) =>
    '${type == 'ordonnances' ? 'ORD' : 'CMD'}-$annee-${mois.toString().padLeft(2, '0')}';
