import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/entreprise.dart';

class EntrepriseScreen extends StatefulWidget {
  const EntrepriseScreen({super.key});

  @override
  State<EntrepriseScreen> createState() => _EntrepriseScreenState();
}

class _EntrepriseScreenState extends State<EntrepriseScreen> {
  final Map<String, TextEditingController> _c = {};
  bool _charge = false;

  static const _champs = <String, String>{
    'emetteurNom': 'Émetteur : nom',
    'emetteurAdresse': 'Émetteur : adresse',
    'emetteurTel': 'Émetteur : téléphone',
    'emetteurNif': 'Émetteur : NIF',
    'emetteurBanque': 'Émetteur : compte bancaire',
    'recepteurNom': 'Récepteur (client) : nom',
    'recepteurAdresse': 'Récepteur : adresse',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Entreprise.charger();
    final m = Entreprise.courant.toMap();
    for (final k in _champs.keys) {
      _c[k] = TextEditingController(text: m[k] as String? ?? '');
    }
    if (mounted) setState(() => _charge = true);
  }

  void _enregistrer() {
    final m = {for (final k in _champs.keys) k: _c[k]!.text.trim()};
    Entreprise.courant = Entreprise.fromMap(m);
    unawaited(FirebaseFirestore.instance
        .collection('parametres')
        .doc('entreprise')
        .set(Entreprise.courant.toMap())
        .catchError((_) {}));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations enregistrées.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informations de l\'entreprise')),
      body: !_charge
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Ces informations apparaissent en haut des factures et des rapports.'),
              const SizedBox(height: 12),
              for (final e in _champs.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _c[e.key],
                    decoration: InputDecoration(labelText: e.value, border: const OutlineInputBorder()),
                  ),
                ),
              FilledButton(
                onPressed: _enregistrer,
                child: const Padding(padding: EdgeInsets.all(12), child: Text('Enregistrer')),
              ),
            ]),
    );
  }
}
