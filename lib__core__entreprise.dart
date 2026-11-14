import 'package:cloud_firestore/cloud_firestore.dart';

/// Informations de l'entreprise et du client, modifiables par l'administrateur
/// (Administration > Informations de l'entreprise). Stockées dans parametres/entreprise.
class Entreprise {
  Entreprise({
    this.emetteurNom = 'Dépôt Pharmaceutique ADUA',
    this.emetteurAdresse = 'Zinder',
    this.emetteurTel = '96-45-67-13 // 93-45-67-13',
    this.emetteurNif = '37417/P',
    this.emetteurBanque = 'BAGRI N° 20467500001',
    this.recepteurNom = 'ONG GRYK',
    this.recepteurAdresse = 'Zinder',
  });

  String emetteurNom;
  String emetteurAdresse;
  String emetteurTel;
  String emetteurNif;
  String emetteurBanque;
  String recepteurNom;
  String recepteurAdresse;

  static Entreprise courant = Entreprise();

  Map<String, dynamic> toMap() => {
        'emetteurNom': emetteurNom,
        'emetteurAdresse': emetteurAdresse,
        'emetteurTel': emetteurTel,
        'emetteurNif': emetteurNif,
        'emetteurBanque': emetteurBanque,
        'recepteurNom': recepteurNom,
        'recepteurAdresse': recepteurAdresse,
      };

  factory Entreprise.fromMap(Map<String, dynamic> m) {
    final d = Entreprise();
    String lire(String k, String defaut) {
      final v = m[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : defaut;
    }

    return Entreprise(
      emetteurNom: lire('emetteurNom', d.emetteurNom),
      emetteurAdresse: lire('emetteurAdresse', d.emetteurAdresse),
      emetteurTel: lire('emetteurTel', d.emetteurTel),
      emetteurNif: lire('emetteurNif', d.emetteurNif),
      emetteurBanque: lire('emetteurBanque', d.emetteurBanque),
      recepteurNom: lire('recepteurNom', d.recepteurNom),
      recepteurAdresse: lire('recepteurAdresse', d.recepteurAdresse),
    );
  }

  /// Lit les paramètres avant de fabriquer un PDF. En cas de problème, les valeurs actuelles sont gardées.
  static Future<void> charger() async {
    try {
      final d = await FirebaseFirestore.instance
          .collection('parametres')
          .doc('entreprise')
          .get()
          .timeout(const Duration(seconds: 5));
      final m = d.data();
      if (d.exists && m != null) courant = Entreprise.fromMap(m);
    } catch (_) {}
  }
}

// Les PDF lisent ces valeurs : elles suivent donc les paramètres.
String get emetteurNom => Entreprise.courant.emetteurNom;
String get emetteurAdresse => Entreprise.courant.emetteurAdresse;
String get emetteurTel => Entreprise.courant.emetteurTel;
String get emetteurNif => Entreprise.courant.emetteurNif;
String get emetteurBanque => Entreprise.courant.emetteurBanque;
String get recepteurNom => Entreprise.courant.recepteurNom;
String get recepteurAdresse => Entreprise.courant.recepteurAdresse;
