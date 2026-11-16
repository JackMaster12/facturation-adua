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
