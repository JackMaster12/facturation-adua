import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/noms.dart';
import '../data/produits_courants.dart';
import '../services/auth_service.dart';
import '../services/unites_service.dart';

class BaseDonneesScreen extends StatefulWidget {
  const BaseDonneesScreen({super.key, required this.profil});
  final UserProfile profil;

  @override
  State<BaseDonneesScreen> createState() => _BaseDonneesScreenState();
}

class _BaseDonneesScreenState extends State<BaseDonneesScreen> {
  @override
  void initState() {
    super.initState();
    semerUnites();
  }

  @override
  Widget build(BuildContext context) {
    final profil = widget.profil;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Base de données'),
          bottom: const TabBar(tabs: [Tab(text: 'Bénéficiaires'), Tab(text: 'Produits'), Tab(text: 'Unités')]),
        ),
        body: TabBarView(children: [
          _ListeNoms(collection: 'beneficiaires', champ: 'nom', libelle: 'Nom de l\'enfant', profil: profil),
          _ListeNoms(collection: 'produits', champ: 'nom', libelle: 'Nom du produit', profil: profil),
          _ListeNoms(collection: 'unites', champ: 'nom', libelle: 'Unité (ex. Boîte/10)', profil: profil),
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
    final nom = c.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (ok != true || nom.isEmpty) return;
    // Refuser un nom déjà présent (majuscules, accents et espaces ignorés).
    try {
      final existants = await _col.get().timeout(const Duration(seconds: 6));
      final cle = cleNom(nom);
      final doublon = existants.docs.any((d) => d.id != doc?.id && cleNom((d.data()[widget.champ] ?? '') as String) == cle);
      if (doublon) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« $nom » existe déjà dans la liste.')));
        }
        return;
      }
    } catch (_) {}
    if (doc == null) {
      unawaited(_col.add({widget.champ: nom, 'creeLe': FieldValue.serverTimestamp()}).then((_) {}, onError: (_) {}));
    } else {
      unawaited(doc.reference.update({widget.champ: nom}).catchError((_) {}));
    }
  }

  /// Colle une liste (un nom par ligne) : ajoute tout d'un coup, sans doublons.
  Future<void> _importer() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter plusieurs'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: c,
            autofocus: true,
            minLines: 8,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: widget.libelle,
              hintText: 'Un nom par ligne.\nCollez ici votre liste.',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (ok != true) return;
    final saisis = <String>[];
    final vus = <String>{};
    for (final ligne in c.text.split('\n')) {
      final nom = ligne.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (nom.isEmpty || !vus.add(cleNom(nom))) continue;
      saisis.add(nom);
    }
    if (saisis.isEmpty) return;
    await _ajouterNoms(saisis);
  }

  /// Ajoute les noms qui ne sont pas déjà dans la liste (doublons ignorés).
  Future<void> _ajouterNoms(List<String> saisis) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final existants = <String>{};
      final s = await _col.get().timeout(const Duration(seconds: 8));
      for (final d in s.docs) {
        existants.add(cleNom((d.data()[widget.champ] ?? '') as String));
      }
      final nouveaux = <String>[];
      final vus = <String>{};
      for (final n in saisis) {
        final k = cleNom(n);
        if (existants.contains(k) || !vus.add(k)) continue;
        nouveaux.add(n);
      }
      for (var i = 0; i < nouveaux.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final nom in nouveaux.skip(i).take(400)) {
          batch.set(_col.doc(), {widget.champ: nom, 'creeLe': FieldValue.serverTimestamp()});
        }
        unawaited(batch.commit().catchError((_) {}));
      }
      messenger.showSnackBar(SnackBar(
          content: Text('${nouveaux.length} ajouté(s)'
              '${saisis.length > nouveaux.length ? ', ${saisis.length - nouveaux.length} déjà présent(s)' : ''}.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ajout impossible : $e')));
    }
  }

  Future<void> _ajouterCourants() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produits courants'),
        content: Text('Ajouter ${produitsCourants.length} produits pharmaceutiques courants (médicaments, '
            'perfusions, consommables) ? Les noms déjà présents seront ignorés. '
            'Vous pourrez ensuite en corriger ou en ajouter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (ok == true) await _ajouterNoms(produitsCourants);
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
    if (ok == true) unawaited(doc.reference.delete().catchError((_) {}));
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
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: TextButton.icon(
              onPressed: _importer,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Ajouter plusieurs (coller une liste)'),
            ),
          ),
        ),
        if (widget.collection == 'produits')
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: TextButton.icon(
                onPressed: _ajouterCourants,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text('Ajouter les ${produitsCourants.length} produits courants'),
              ),
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
