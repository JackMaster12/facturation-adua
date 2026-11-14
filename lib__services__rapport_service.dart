import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/rapport.dart';

class RapportService {
  RapportService._();
  static final instance = RapportService._();

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('rapports');

  Stream<List<RapportData>> liste() => _col.snapshots().map((s) {
        final l = [for (final d in s.docs) RapportData.fromDoc(d)];
        l.sort((a, b) => (b.creeLe ?? DateTime.now()).compareTo(a.creeLe ?? DateTime.now()));
        return l;
      });

  /// Crée (id == null) ou met à jour un rapport rédigé. L'enregistrement est immédiat.
  void enregistrer(String? id, List<MoisRapport> mois, String message) {
    final ref = id == null ? _col.doc() : _col.doc(id);
    final donnees = <String, dynamic>{
      'mois': [for (final m in mois) m.toMap()],
      'message': message,
      'majLe': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      donnees['creeLe'] = FieldValue.serverTimestamp();
      donnees['creePar'] = FirebaseAuth.instance.currentUser?.uid;
    }
    unawaited(ref.set(donnees, SetOptions(merge: true)).catchError((_) {}));
  }

  void supprimer(String id) {
    unawaited(_col.doc(id).delete().catchError((_) {}));
  }
}
