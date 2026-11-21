import 'package:cloud_firestore/cloud_firestore.dart';

class LigneVente {
  LigneVente({required this.produit, required this.quantite, required this.prix});
  final String produit;
  final int quantite;
  final int prix; // prix unitaire en FCFA

  int get montant => quantite * prix;

  Map<String, dynamic> toMap() => {'produit': produit, 'quantite': quantite, 'prix': prix, 'montant': montant};

  factory LigneVente.fromMap(Map<String, dynamic> m) => LigneVente(
        produit: (m['produit'] ?? '') as String,
        quantite: ((m['quantite'] ?? 0) as num).toInt(),
        prix: ((m['prix'] ?? 0) as num).toInt(),
      );
}

class VenteData {
  VenteData({required this.id, required this.numero, required this.date, required this.client, required this.lignes});
  final String id;
  final String numero;
  final DateTime date;
  final String client;
  final List<LigneVente> lignes;

  int get total => lignes.fold(0, (s, l) => s + l.montant);

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'date': Timestamp.fromDate(date),
        'client': client,
        'lignes': [for (final l in lignes) l.toMap()],
        'total': total,
      };

  factory VenteData.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ts = m['date'];
    final raw = (m['lignes'] ?? []) as List;
    return VenteData(
      id: d.id,
      numero: (m['numero'] ?? '') as String,
      date: ts is Timestamp ? ts.toDate() : DateTime.now(),
      client: (m['client'] ?? '') as String,
      lignes: [for (final e in raw) LigneVente.fromMap(Map<String, dynamic>.from(e as Map))],
    );
  }
}

/// Numéro de reçu : année-mois-jour puis heure, par exemple 261121-143205.
String numeroRecu(DateTime d) {
  String d2(int n) => n.toString().padLeft(2, '0');
  return '${d2(d.year % 100)}${d2(d.month)}${d2(d.day)}-${d2(d.hour)}${d2(d.minute)}${d2(d.second)}';
}
