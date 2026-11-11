/// Convertit un montant entier en lettres, en français, suivi de « francs CFA ».
/// Règles : soixante et onze, quatre-vingts / quatre-vingt-un, deux cents / deux cent un,
/// mille invariable, millions et milliards avec « s ».
const List<String> _unites = [
  'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
  'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
  'dix-sept', 'dix-huit', 'dix-neuf',
];

const Map<int, String> _dizaines = {
  20: 'vingt', 30: 'trente', 40: 'quarante', 50: 'cinquante', 60: 'soixante',
};

String _moinsDeCent(int n, {required bool terminal}) {
  if (n < 20) return _unites[n];
  if (n < 70) {
    final base = _dizaines[(n ~/ 10) * 10]!;
    final u = n % 10;
    if (u == 0) return base;
    if (u == 1) return '$base et un';
    return '$base-${_unites[u]}';
  }
  if (n < 80) {
    final u = n - 60; // 10 à 19
    if (u == 11) return 'soixante et onze';
    return 'soixante-${_unites[u]}';
  }
  final u = n - 80; // 0 à 19
  if (u == 0) return terminal ? 'quatre-vingts' : 'quatre-vingt';
  return 'quatre-vingt-${_unites[u]}';
}

String _moinsDeMille(int n, {required bool terminal}) {
  final h = n ~/ 100;
  final r = n % 100;
  if (h == 0) return _moinsDeCent(r, terminal: terminal);
  final cent = h == 1 ? 'cent' : '${_unites[h]} cent${(r == 0 && terminal) ? 's' : ''}';
  if (r == 0) return cent;
  return '$cent ${_moinsDeCent(r, terminal: terminal)}';
}

String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Nombre en lettres, sans l'unité monétaire. Ex. 1250 -> « Mille deux cent cinquante ».
String nombreEnLettres(int n) {
  if (n < 0) return 'Moins ${nombreEnLettres(-n).toLowerCase()}';
  if (n == 0) return 'Zéro';
  final parts = <String>[];
  final milliards = n ~/ 1000000000;
  final millions = (n ~/ 1000000) % 1000;
  final milliers = (n ~/ 1000) % 1000;
  final reste = n % 1000;
  if (milliards > 0) {
    parts.add('${_moinsDeMille(milliards, terminal: true)} milliard${milliards > 1 ? 's' : ''}');
  }
  if (millions > 0) {
    parts.add('${_moinsDeMille(millions, terminal: true)} million${millions > 1 ? 's' : ''}');
  }
  if (milliers > 0) {
    parts.add(milliers == 1 ? 'mille' : '${_moinsDeMille(milliers, terminal: false)} mille');
  }
  if (reste > 0) {
    parts.add(_moinsDeMille(reste, terminal: true));
  }
  return _majuscule(parts.join(' '));
}

/// Montant en lettres avec l'unité. Ex. 10000 -> « Dix mille francs CFA. »
String montantEnLettres(int n) => '${nombreEnLettres(n)} francs CFA';
