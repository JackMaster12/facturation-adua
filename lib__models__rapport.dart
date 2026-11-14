import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/format.dart';

class LigneRapport {
  LigneRapport({required this.label, required this.montant});
  final String label;
  final int montant;

  Map<String, dynamic> toMap() => {'label': label, 'montant': montant};

  factory LigneRapport.fromMap(Map<String, dynamic> m) =>
      LigneRapport(label: (m['label'] ?? '') as String, montant: ((m['montant'] ?? 0) as num).toInt());
}

class MoisRapport {
  MoisRapport({required this.mois, required this.annee, required this.lignes});
  final int mois;
  final int annee;
  final List<LigneRapport> lignes;

  int get total => lignes.fold(0, (s, l) => s + l.montant);
  String get libelle => numeroFacture(mois, annee);

  Map<String, dynamic> toMap() => {
        'mois': mois,
        'annee': annee,
        'lignes': [for (final l in lignes) l.toMap()],
      };

  factory MoisRapport.fromMap(Map<String, dynamic> m) => MoisRapport(
        mois: ((m['mois'] ?? 1) as num).toInt(),
        annee: ((m['annee'] ?? 2026) as num).toInt(),
        lignes: [
          for (final e in (m['lignes'] ?? []) as List) LigneRapport.fromMap(Map<String, dynamic>.from(e as Map))
        ],
      );
}

/// Rapport rédigé à la main, enregistré dans Firestore.
class RapportData {
  RapportData({required this.id, required this.mois, required this.message, this.creeLe});
  final String id;
  final List<MoisRapport> mois;
  final String message;
  final DateTime? creeLe;

  String get titre => titreRapport(mois);

  factory RapportData.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ts = m['creeLe'];
    return RapportData(
      id: d.id,
      mois: [
        for (final e in (m['mois'] ?? []) as List) MoisRapport.fromMap(Map<String, dynamic>.from(e as Map))
      ],
      message: (m['message'] ?? '') as String,
      creeLe: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// « OCTOBRE 2026 » ou « AOÛT 2026 à OCTOBRE 2026 »
String titreRapport(List<MoisRapport> mois) {
  if (mois.isEmpty) return 'Rapport vide';
  final tries = [...mois]..sort((a, b) => (a.annee * 100 + a.mois).compareTo(b.annee * 100 + b.mois));
  final a = tries.first.libelle;
  final b = tries.last.libelle;
  return a == b ? a : '$a à $b';
}
