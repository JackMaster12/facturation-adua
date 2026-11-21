import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/noms.dart';

/// Prix des produits (champ « prix » de la collection produits), indexés par nom simplifié (cleNom).
/// Lit d'abord le téléphone, donc fonctionne aussi hors connexion.
Future<Map<String, int>> chargerPrixProduits() async {
  final col = FirebaseFirestore.instance.collection('produits');
  QuerySnapshot<Map<String, dynamic>>? s;
  try {
    final c = await col.get(const GetOptions(source: Source.cache));
    if (c.docs.isNotEmpty) s = c;
  } catch (_) {}
  if (s == null) {
    try {
      s = await col.get().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
  final r = <String, int>{};
  for (final d in s?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
    final m = d.data();
    final p = m['prix'];
    if (p is num && p > 0) r[cleNom((m['nom'] ?? '') as String)] = p.toInt();
  }
  return r;
}
