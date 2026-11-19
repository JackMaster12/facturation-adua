/// Clé de comparaison d'un nom : sans majuscules, sans accents, espaces simplifiés.
/// « Boîte / 10 », « boite/10 » et « BOÎTE/10 » donnent la même clé.
String cleNom(String s) {
  const de = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const vers = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? vers[i] : c);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'\s*/\s*'), '/')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// « PARACETAMOL 500 MG » -> « Paracetamol 500 mg » : tout en minuscules, sauf la 1re lettre.
String premiereMajuscule(String s) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}
