import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';

dynamic _json(dynamic v) {
  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is Map) return {for (final e in v.entries) e.key.toString(): _json(e.value)};
  if (v is List) return [for (final e in v) _json(e)];
  return v;
}

/// Exporte toutes les données (enfants, produits, factures, rapports, paramètres)
/// dans un fichier JSON, puis ouvre le partage (WhatsApp, e-mail, Drive…).
Future<void> sauvegarderDonnees() async {
  final db = FirebaseFirestore.instance;
  final sortie = <String, dynamic>{
    'application': 'FACTURATION ADUA',
    'sauvegardeLe': DateTime.now().toIso8601String(),
  };
  for (final c in ['beneficiaires', 'produits', 'rapports', 'parametres']) {
    final s = await db.collection(c).get();
    sortie[c] = {for (final d in s.docs) d.id: _json(d.data())};
  }
  final factures = <String, dynamic>{};
  final fs = await db.collection('factures').get();
  for (final d in fs.docs) {
    final m = Map<String, dynamic>.from(_json(d.data()) as Map);
    for (final sous in ['ordonnances', 'commandes']) {
      final s = await d.reference.collection(sous).get();
      m[sous] = {for (final x in s.docs) x.id: _json(x.data())};
    }
    factures[d.id] = m;
  }
  sortie['factures'] = factures;

  final dossier = await getTemporaryDirectory();
  final nom = 'sauvegarde-adua-${formatDate(DateTime.now()).replaceAll('/', '-')}.json';
  final fichier = File('${dossier.path}/$nom');
  await fichier.writeAsString(const JsonEncoder.withIndent('  ').convert(sortie));
  await Share.shareXFiles([XFile(fichier.path, mimeType: 'application/json')],
      subject: 'Sauvegarde FACTURATION ADUA');
}
