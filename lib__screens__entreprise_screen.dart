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
  final List<(TextEditingController, TextEditingController)> _infos = [];

  static const _suggestions = ['Numéro', 'NIF', 'Téléphone', 'E-mail', 'RCCM', 'Compte bancaire'];

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
    for (final i in Entreprise.courant.recepteurInfos) {
      _infos.add((TextEditingController(text: i.libelle), TextEditingController(text: i.valeur)));
    }
    if (mounted) setState(() => _charge = true);
  }

  void _enregistrer() {
    final m = <String, dynamic>{for (final k in _champs.keys) k: _c[k]!.text.trim()};
    m['largeurRecu'] = Entreprise.courant.largeurRecu; // réglé dans l'écran de vente : à conserver
    m['recepteurInfos'] = [
      for (final i in _infos)
        if (i.$1.text.trim().isNotEmpty || i.$2.text.trim().isNotEmpty)
          {'libelle': i.$1.text.trim(), 'valeur': i.$2.text.trim()},
    ];
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
              const SizedBox(height: 8),
              Text('Autres informations du récepteur', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('Ajoutez ce que vous voulez (numéro, NIF…). Une information dont la valeur est vide '
                  'n\'apparaît pas sur les factures.'),
              const SizedBox(height: 8),
              for (var k = 0; k < _infos.length; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _infos[k].$1,
                        decoration: const InputDecoration(labelText: 'Intitulé', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _infos[k].$2,
                        decoration: const InputDecoration(labelText: 'Valeur', border: OutlineInputBorder()),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retirer',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _infos.removeAt(k)),
                    ),
                  ]),
                ),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text('+ $s'),
                    onPressed: () => setState(() => _infos.add((TextEditingController(text: s), TextEditingController()))),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Autre'),
                  onPressed: () => setState(() => _infos.add((TextEditingController(), TextEditingController()))),
                ),
              ]),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _enregistrer,
                child: const Padding(padding: EdgeInsets.all(12), child: Text('Enregistrer')),
              ),
            ]),
    );
  }
}
