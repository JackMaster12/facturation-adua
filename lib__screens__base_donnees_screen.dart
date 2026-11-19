import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _selectionActive = false;
  final Set<String> _selection = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibles = [];

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection(widget.collection);

  /// Lit la liste : d'abord le téléphone (instantané, marche hors connexion), puis le serveur si le cache est vide.
  Future<QuerySnapshot<Map<String, dynamic>>> _lireTout() async {
    try {
      final c = await _col.get(const GetOptions(source: Source.cache));
      if (c.docs.isNotEmpty) return c;
    } catch (_) {}
    return _col.get().timeout(const Duration(seconds: 4));
  }

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
      final existants = await _lireTout();
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
    var minuscules = widget.collection == 'produits';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter plusieurs'),
        content: StatefulBuilder(
          builder: (ctx, setL) => SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: c,
                autofocus: true,
                minLines: 6,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: widget.libelle,
                  hintText: 'Un nom par ligne.\nCollez ici votre liste.',
                  border: const OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: minuscules,
                onChanged: (v) => setL(() => minuscules = v ?? false),
                title: const Text('Écrire en minuscules, 1re lettre majuscule seulement'),
                subtitle: const Text('PARACETAMOL 500 MG devient Paracetamol 500 mg'),
              ),
            ]),
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
      var nom = ligne.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (minuscules) nom = premiereMajuscule(nom);
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
      final s = await _lireTout();
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

  /// Copie toute la liste (un nom par ligne) dans le presse-papiers.
  Future<void> _copier() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final s = await _lireTout();
      final noms = [for (final d in s.docs) (d.data()[widget.champ] ?? '') as String]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await Clipboard.setData(ClipboardData(text: noms.join('\n')));
      messenger.showSnackBar(SnackBar(content: Text('${noms.length} nom(s) copié(s). Vous pouvez les coller où vous voulez.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Copie impossible : $e')));
    }
  }

  /// Met tous les noms de la liste en minuscules avec la 1re lettre majuscule (administrateur).
  Future<void> _convertir() async {
    final messenger = ScaffoldMessenger.of(context);
    final s = await _lireTout();
    final aChanger = [
      for (final d in s.docs)
        if (premiereMajuscule((d.data()[widget.champ] ?? '') as String) != (d.data()[widget.champ] ?? ''))
          d,
    ];
    if (aChanger.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Tous les noms sont déjà dans ce format.')));
      return;
    }
    final exemples = aChanger
        .take(3)
        .map((d) => '${d.data()[widget.champ]}  ->  ${premiereMajuscule(d.data()[widget.champ] as String)}')
        .join('\n');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer l\'écriture ?'),
        content: Text('${aChanger.length} nom(s) seront écrits en minuscules avec la 1re lettre majuscule.\n\n'
            '$exemples\n\nLes sigles (SRO, ATPE…) perdront leurs majuscules : vous pourrez les corriger un par un. '
            'Les factures déjà saisies gardent leur ancienne écriture.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Changer')),
        ],
      ),
    );
    if (ok != true) return;
    for (var i = 0; i < aChanger.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in aChanger.skip(i).take(400)) {
        batch.update(d.reference, {widget.champ: premiereMajuscule(d.data()[widget.champ] as String)});
      }
      unawaited(batch.commit().catchError((_) {}));
    }
    messenger.showSnackBar(SnackBar(content: Text('${aChanger.length} nom(s) modifié(s).')));
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

  void _quitterSelection() => setState(() {
        _selectionActive = false;
        _selection.clear();
      });

  /// Supprime d'un coup tous les éléments cochés (administrateur seulement).
  Future<void> _supprimerSelection() async {
    final n = _selection.length;
    if (n == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la sélection ?'),
        content: Text('$n élément(s) seront supprimés de la liste. '
            'Les factures déjà saisies ne changent pas. Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer ($n)')),
        ],
      ),
    );
    if (ok != true) return;
    final messenger = ScaffoldMessenger.of(context);
    final ids = _selection.toList();
    for (var i = 0; i < ids.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.skip(i).take(400)) {
        batch.delete(_col.doc(id));
      }
      unawaited(batch.commit().catchError((_) {}));
    }
    _quitterSelection();
    messenger.showSnackBar(SnackBar(content: Text('$n supprimé(s).')));
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
        if (admin)
          _selectionActive
              ? Container(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.close), tooltip: 'Quitter', onPressed: _quitterSelection),
                    Expanded(child: Text('${_selection.length} sélectionné(s)')),
                    TextButton(
                      onPressed: () => setState(() {
                        if (_selection.length >= _visibles.length) {
                          _selection.clear();
                        } else {
                          _selection.addAll(_visibles.map((d) => d.id));
                        }
                      }),
                      child: Text(_selection.length >= _visibles.length && _visibles.isNotEmpty
                          ? 'Tout décocher'
                          : 'Tout cocher'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      tooltip: 'Supprimer la sélection',
                      onPressed: _selection.isEmpty ? null : _supprimerSelection,
                    ),
                  ]),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _selectionActive = true),
                      icon: const Icon(Icons.checklist),
                      label: const Text('Sélectionner et supprimer plusieurs'),
                    ),
                  ),
                ),
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
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: TextButton.icon(
              onPressed: _copier,
              icon: const Icon(Icons.copy),
              label: const Text('Copier toute la liste'),
            ),
          ),
        ),
        if (admin && widget.collection == 'produits')
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: TextButton.icon(
                onPressed: _convertir,
                icon: const Icon(Icons.text_fields),
                label: const Text('Mettre en 1re lettre majuscule'),
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
              _visibles = docs;
              if (docs.isEmpty) return const Center(child: Text('Aucun élément.'));
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  if (admin && _selectionActive) {
                    return CheckboxListTile(
                      value: _selection.contains(d.id),
                      onChanged: (v) => setState(() => v == true ? _selection.add(d.id) : _selection.remove(d.id)),
                      title: Text(d.data()[widget.champ] as String? ?? ''),
                    );
                  }
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
