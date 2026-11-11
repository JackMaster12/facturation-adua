import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class BaseDonneesScreen extends StatelessWidget {
  const BaseDonneesScreen({super.key, required this.profil});
  final UserProfile profil;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Base de données'),
          bottom: const TabBar(tabs: [Tab(text: 'Bénéficiaires'), Tab(text: 'Produits')]),
        ),
        body: TabBarView(children: [
          _ListeNoms(collection: 'beneficiaires', champ: 'nom', libelle: 'Nom de l\'enfant', profil: profil),
          _ListeNoms(collection: 'produits', champ: 'nom', libelle: 'Nom du produit', profil: profil),
        ]),
      ),
    );
  }
}

/// Liste simple (enfants ou produits) : tout le monde ajoute,
/// seul l'administrateur modifie et supprime.
class _ListeNoms extends StatefulWidget {
  const _ListeNoms({required this.collection, required this.champ, required this.libelle, required this.profil});
  final String collection;
  final String champ;
  final String libelle;
  final UserProfile profil;

  @override
  State<_ListeNoms> createState() => _ListeNomsState();
}

class _ListeNomsState extends State<_ListeNoms> {
  final _recherche = TextEditingController();

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection(widget.collection);

  Future<void> _editer({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final c = TextEditingController(text: doc?.data()?[widget.champ] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc == null ? 'Ajouter' : 'Modifier'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: widget.libelle),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    final nom = c.text.trim();
    if (ok != true || nom.isEmpty) return;
    if (doc == null) {
      await _col.add({widget.champ: nom, 'creeLe': FieldValue.serverTimestamp()});
    } else {
      await doc.reference.update({widget.champ: nom});
    }
  }

  Future<void> _supprimer(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final nom = doc.data()?[widget.champ] ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('« $nom » sera supprimé de la liste. Les factures déjà saisies ne changent pas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.profil.isAdmin;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _recherche,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'Rechercher', border: OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _col.orderBy(widget.champ).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Erreur de lecture des données.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final q = _recherche.text.trim().toLowerCase();
              final docs = snap.data!.docs
                  .where((d) => ((d.data()[widget.champ] ?? '') as String).toLowerCase().contains(q))
                  .toList();
              if (docs.isEmpty) return const Center(child: Text('Aucun élément.'));
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  return ListTile(
                    title: Text(d.data()[widget.champ] as String? ?? ''),
                    trailing: admin
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editer(doc: d)),
                            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _supprimer(d)),
                          ])
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
