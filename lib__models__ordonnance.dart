import 'package:cloud_firestore/cloud_firestore.dart';

class LigneOrd {
  LigneOrd({required this.produit, required this.quantite, required this.montant});
  final String produit;
  final int quantite;
  final int montant;

  Map<String, dynamic> toMap() => {'produit': produit, 'quantite': quantite, 'montant': montant};

  factory LigneOrd.fromMap(Map<String, dynamic> m) => LigneOrd(
        produit: (m['produit'] ?? '') as String,
        quantite: ((m['quantite'] ?? 0) as num).toInt(),
        montant: ((m['montant'] ?? 0) as num).toInt(),
      );
}

class OrdonnanceData {
  OrdonnanceData({
    required this.id,
    required this.date,
    required this.numero,
    required this.enfant,
    required this.lignes,
  });
  final String id;
  final DateTime date;
  final String numero;
  final String enfant;
  final List<LigneOrd> lignes;

  int get total => lignes.fold(0, (s, l) => s + l.montant);

  factory OrdonnanceData.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ts = m['date'];
    final raw = (m['lignes'] ?? []) as List;
    return OrdonnanceData(
      id: d.id,
      date: ts is Timestamp ? ts.toDate() : DateTime.now(),
      numero: (m['numero'] ?? '') as String,
      enfant: (m['enfant'] ?? '') as String,
      lignes: [for (final e in raw) LigneOrd.fromMap(Map<String, dynamic>.from(e as Map))],
    );
  }
}

/// Facture (en-tête) lue dans Firestore.
class FactureData {
  FactureData({
    required this.id,
    required this.type,
    required this.mois,
    required this.annee,
    required this.statut,
    this.total = 0,
    this.arreteLe,
  });
  final String id;
  final String type;
  final int mois;
  final int annee;
  final String statut;
  final int total;
  final DateTime? arreteLe;

  bool get enCours => statut == 'en_cours';

  factory FactureData.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ts = m['arreteLe'];
    return FactureData(
      id: d.id,
      type: (m['type'] ?? 'ordonnances') as String,
      mois: ((m['mois'] ?? 1) as num).toInt(),
      annee: ((m['annee'] ?? 2026) as num).toInt(),
      statut: (m['statut'] ?? 'en_cours') as String,
      total: ((m['total'] ?? 0) as num).toInt(),
      arreteLe: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
