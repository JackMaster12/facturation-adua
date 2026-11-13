import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Champ qui ouvre une liste (enfants ou produits) avec recherche et ajout d'un nouveau nom.
class SelecteurNom extends StatelessWidget {
  const SelecteurNom({
    super.key,
    required this.collection,
    required this.libelle,
    required this.valeur,
    required this.onChoisi,
  });
  final String collection;
  final String libelle;
  final String valeur;
  final ValueChanged<String> onChoisi;

  Future<void> _ouvrir(BuildContext context) async {
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Feuille(collection: collection, libelle: libelle),
    );
    if (r != null && r.isNotEmpty) onChoisi(r);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _ouvrir(context),
      child: InputDecorator(
        decoration: InputDecoration(labelText: libelle, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.arrow_drop_down)),
        child: Text(valeur.isEmpty ? 'Choisir…' : valeur),
      ),
    );
  }
}

class _Feuille extends StatefulWidget {
  const _Feuille({required this.collection, required this.libelle});
  final String collection;
  final String libelle;

  @override
  State<_Feuille> createState() => _FeuilleState();
}

class _FeuilleState extends State<_Feuille> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _ajouter(String nom) {
    final n = nom.trim();
    if (n.isEmpty) return;
    unawaited(FirebaseFirestore.instance
        .collection(widget.collection)
        .add({'nom': n, 'creeLe': FieldValue.serverTimestamp()}).then((_) {}, onError: (_) {}));
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: h,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _q,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Rechercher : ${widget.libelle}', prefixIcon: const Icon(Icons.search)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection(widget.collection).snapshots(),
              builder: (context, snap) {
                final q = _q.text.trim().toLowerCase();
                final noms = <String>[
                  for (final d in snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    (d.data()['nom'] ?? '') as String,
                ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                final filtres = noms.where((n) => n.toLowerCase().contains(q)).toList();
                final existe = noms.any((n) => n.toLowerCase() == q);
                return ListView(children: [
                  if (q.isNotEmpty && !existe)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text('Ajouter « ${_q.text.trim()} »'),
                      onTap: () => _ajouter(_q.text),
                    ),
                  for (final n in filtres) ListTile(title: Text(n), onTap: () => Navigator.pop(context, n)),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
