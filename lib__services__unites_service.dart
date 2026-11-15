import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> _unitesParDefaut = [
  'Boîte',
  'Boîte/10',
  'Boîte/20',
  'Boîte/30',
  'Boîte/50',
  'Boîte/100',
  'Plaquette',
  'Rouleau',
  'Flacon',
  'Tube',
  'Sachet',
  'Ampoule',
  'Carton',
  'Paquet',
  'Pièce',
];

/// Remplit la liste des unités la toute première fois (si elle est vide).
/// Les identifiants sont fixes : aucun doublon, même si deux téléphones le font en même temps.
Future<void> semerUnites() async {
  try {
    final col = FirebaseFirestore.instance.collection('unites');
    final s = await col.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 6));
    if (s.docs.isNotEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < _unitesParDefaut.length; i++) {
      batch.set(col.doc('unite-${(i + 1).toString().padLeft(2, '0')}'), {
        'nom': _unitesParDefaut[i],
        'creeLe': FieldValue.serverTimestamp(),
      });
    }
    unawaited(batch.commit().catchError((_) {}));
  } catch (_) {}
}
