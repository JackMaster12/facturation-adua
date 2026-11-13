/// Lit « 23/10/2026 » (séparateurs / . - acceptés). Retourne null si invalide.
DateTime? parseDate(String s) {
  final p = s.trim().split(RegExp(r'[/.\-\s]+'));
  if (p.length != 3) return null;
  final j = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  var a = int.tryParse(p[2]);
  if (j == null || m == null || a == null) return null;
  if (a < 100) a += 2000;
  if (m < 1 || m > 12 || j < 1 || j > 31) return null;
  final d = DateTime(a, m, j);
  if (d.month != m || d.day != j) return null;
  return d;
}

/// Garde uniquement les chiffres : « 12 500 » -> 12500. Vide -> 0.
int parseEntier(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
