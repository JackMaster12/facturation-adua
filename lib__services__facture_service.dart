import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/format.dart';
import '../core/montant_en_lettres.dart';
import '../models/ordonnance.dart';

class FactureService {
  FactureService._();
  static final instance = FactureService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('factures');

  /// Crée la facture du mois. Retourne false si elle existe déjà.
  Future<bool> creer(String type, int mois, int annee) async {
    final id = idFacture(type, mois, annee);
    final ref = _col.doc(id);
    final d = await ref.get();
    if (d.exists) return false;
    unawaited(ref.set({
      'type': type,
      'mois': mois,
      'annee': annee,
      'numero': numeroFacture(mois, annee),
      'statut': 'en_cours',
      'creeLe': FieldValue.serverTimestamp(),
      'creePar': FirebaseAuth.instance.currentUser?.uid,
    }).catchError((_) {}));
    return true;
  }

  Stream<List<FactureData>> factures(String type, String statut) => _col
      .where('type', isEqualTo: type)
      .snapshots()
      .map((s) {
        final l = [for (final d in s.docs) FactureData.fromDoc(d)].where((f) => f.statut == statut).toList();
        l.sort((a, b) => (b.annee * 100 + b.mois).compareTo(a.annee * 100 + a.mois));
        return l;
      });

  Stream<List<FactureData>> toutesTerminees() => _col.snapshots().map((s) {
        final l = [for (final d in s.docs) FactureData.fromDoc(d)].where((f) => f.statut == 'terminee').toList();
        l.sort((a, b) => (b.annee * 100 + b.mois).compareTo(a.annee * 100 + a.mois));
        return l;
      });

  Stream<FactureData?> facture(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? FactureData.fromDoc(d) : null);

  CollectionReference<Map<String, dynamic>> _ords(String id) => _col.doc(id).collection('ordonnances');

  Stream<List<OrdonnanceData>> ordonnances(String id) => _ords(id).snapshots().map((s) {
        final l = [for (final d in s.docs) OrdonnanceData.fromDoc(d)];
        l.sort((a, b) {
          final c = a.enfant.toLowerCase().compareTo(b.enfant.toLowerCase());
          return c != 0 ? c : a.date.compareTo(b.date);
        });
        return l;
      });

  Future<List<OrdonnanceData>> ordonnancesUneFois(String id) async {
    final s = await _ords(id).get();
    return [for (final d in s.docs) OrdonnanceData.fromDoc(d)];
  }

  void enregistrerOrdonnance(String factureId, String? ordId, DateTime date, String numero, String enfant,
      List<LigneOrd> lignes) {
    final ref = ordId == null ? _ords(factureId).doc() : _ords(factureId).doc(ordId);
    final total = lignes.fold<int>(0, (s, l) => s + l.montant);
    unawaited(ref.set({
      'date': Timestamp.fromDate(date),
      'numero': numero,
      'enfant': enfant,
      'lignes': [for (final l in lignes) l.toMap()],
      'total': total,
      'majLe': FieldValue.serverTimestamp(),
    }).catchError((_) {}));
  }

  void supprimerOrdonnance(String factureId, String ordId) {
    unawaited(_ords(factureId).doc(ordId).delete().catchError((_) {}));
  }

  /// Arrête la facture : calcule le total, fige la date, passe en « terminee ».
  Future<({int total, String lettres, DateTime arreteLe, List<OrdonnanceData> ordonnances})> arreter(
      String id) async {
    final ords = await ordonnancesUneFois(id);
    final total = ords.fold<int>(0, (s, o) => s + o.total);
    final lettres = montantEnLettres(total);
    final maintenant = DateTime.now();
    unawaited(_col.doc(id).update({
      'statut': 'terminee',
      'total': total,
      'lettres': lettres,
      'arreteLe': Timestamp.fromDate(maintenant),
      'nbOrdonnances': ords.length,
    }).catchError((_) {}));
    return (total: total, lettres: lettres, arreteLe: maintenant, ordonnances: ords);
  }

  void rouvrir(String id) {
    unawaited(_col.doc(id).update({'statut': 'en_cours'}).catchError((_) {}));
  }

  Future<void> supprimer(String id) async {
    final s = await _ords(id).get();
    final batch = _db.batch();
    for (final d in s.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_col.doc(id));
    unawaited(batch.commit().catchError((_) {}));
  }
}
