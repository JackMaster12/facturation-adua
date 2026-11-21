import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dates.dart';
import '../core/format.dart';
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
  bool _outils = false; // ruban d'outils déroulé ou non
  bool _sansPrix = false;
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
    final avecPrix = widget.collection == 'produits';
    final prixActuel = doc?.data()?['prix'];
    final cp = TextEditingController(text: prixActuel is num && prixActuel > 0 ? '${prixActuel.toInt()}' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc == null ? 'Ajouter' : 'Modifier'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            autofocus: true,
            textCapitalization:
                widget.collection == 'beneficiaires' ? TextCapitalization.words : TextCapitalization.sentences,
            textInputAction: avecPrix ? TextInputAction.next : TextInputAction.done,
            decoration: InputDecoration(labelText: widget.libelle),
          ),
          if (avecPrix) ...[
            const SizedBox(height: 12),
            TextField(
              controller: cp,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix de vente (FCFA)', hintText: 'facultatif'),
            ),
          ],
        ]),
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
    final prix = parseEntier(cp.text);
    if (doc == null) {
      unawaited(_col.add({
        widget.champ: nom,
        if (avecPrix && prix > 0) 'prix': prix,
        'creeLe': FieldValue.serverTimestamp(),
      }).then((_) {}, onError: (_) {}));
    } else {
      unawaited(doc.reference.update({
        widget.champ: nom,
        if (avecPrix) 'prix': prix > 0 ? prix : FieldValue.delete(),
      }).catchError((_) {}));
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
                  hintText: widget.collection == 'produits'
                      ? 'Un produit par ligne.\nAvec le prix : Nom ; Prix\n(ou collez deux colonnes d\'un tableau)'
                      : 'Un nom par ligne.\nCollez ici votre liste.',
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
    final prix = <String, int>{};
    final vus = <String>{};
    for (final ligne in c.text.split('\n')) {
      // « Nom ; Prix » ou « Nom [tabulation] Prix » (copié d'un tableau) : le prix est facultatif.
      final morceaux = ligne.split(RegExp(r'[;\t]'));
      var nom = morceaux.first.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (minuscules) nom = premiereMajuscule(nom);
      if (nom.isEmpty || !vus.add(cleNom(nom))) continue;
      saisis.add(nom);
      if (widget.collection == 'produits' && morceaux.length > 1) {
        final p = parseEntier(morceaux[1]);
        if (p > 0) prix[cleNom(nom)] = p;
      }
    }
    if (saisis.isEmpty) return;
    await _ajouterNoms(saisis, prix: prix);
  }

  /// Ajoute les noms qui ne sont pas déjà dans la liste (doublons ignorés).
  /// Si un prix est fourni (produits), il est enregistré ; pour un produit déjà présent, l'administrateur le met à jour.
  Future<void> _ajouterNoms(List<String> saisis, {Map<String, int>? prix}) async {
    final messenger = ScaffoldMessenger.of(context);
    final admin = widget.profil.isAdmin;
    try {
      final existants = <String, DocumentReference<Map<String, dynamic>>>{};
      final s = await _lireTout();
      for (final d in s.docs) {
        existants[cleNom((d.data()[widget.champ] ?? '') as String)] = d.reference;
      }
      final nouveaux = <String>[];
      final majPrix = <(DocumentReference<Map<String, dynamic>>, int)>[];
      final vus = <String>{};
      for (final n in saisis) {
        final k = cleNom(n);
        if (existants.containsKey(k)) {
          final p = prix?[k];
          if (admin && p != null) majPrix.add((existants[k]!, p));
          continue;
        }
        if (!vus.add(k)) continue;
        nouveaux.add(n);
      }
      for (var i = 0; i < nouveaux.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final nom in nouveaux.skip(i).take(400)) {
          final p = prix?[cleNom(nom)];
          batch.set(_col.doc(), {
            widget.champ: nom,
            if (p != null) 'prix': p,
            'creeLe': FieldValue.serverTimestamp(),
          });
        }
        unawaited(batch.commit().catchError((_) {}));
      }
      for (var i = 0; i < majPrix.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final m in majPrix.skip(i).take(400)) {
          batch.update(m.$1, {'prix': m.$2});
        }
        unawaited(batch.commit().catchError((_) {}));
      }
      messenger.showSnackBar(SnackBar(
          content: Text('${nouveaux.length} ajouté(s)'
              '${majPrix.isNotEmpty ? ', ${majPrix.length} prix mis à jour' : ''}'
              '${saisis.length - nouveaux.length - majPrix.length > 0 ? ', ${saisis.length - nouveaux.length - majPrix.length} déjà présent(s)' : ''}.')));
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
    final produits = widget.collection == 'produits';
    Widget outil(IconData ic, String t, VoidCallback f) => OutlinedButton.icon(
          onPressed: () {
            setState(() => _outils = false);
            f();
          },
          icon: Icon(ic, size: 18),
          label: Text(t),
        );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(children: [
        if (admin && _selectionActive)
          Container(
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
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _recherche,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Rechercher', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _outils = !_outils),
              icon: Icon(_outils ? Icons.expand_less : Icons.expand_more),
              label: const Text('Outils'),
            ),
          ]),
        ),
        // Ruban d'outils : caché par défaut, il se déroule avec le bouton « Outils ».
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _outils
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    outil(Icons.playlist_add, 'Ajouter plusieurs', _importer),
                    outil(Icons.copy, 'Copier la liste', _copier),
                    if (admin)
                      outil(Icons.checklist, 'Sélectionner et supprimer', () => setState(() => _selectionActive = true)),
                    if (admin && produits) outil(Icons.text_fields, '1re lettre majuscule', _convertir),
                    if (produits)
                      outil(Icons.inventory_2_outlined, 'Ajouter les ${produitsCourants.length} produits courants',
                          _ajouterCourants),
                    if (produits)
                      FilterChip(
                        label: const Text('Sans prix'),
                        selected: _sansPrix,
                        onSelected: (v) => setState(() => _sansPrix = v),
                      ),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (produits && _sansPrix)
          const Padding(
            padding: EdgeInsets.only(left: 14, bottom: 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('Produits sans prix uniquement')),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _col.orderBy(widget.champ).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Erreur de lecture des données.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final q = _recherche.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((d) {
                final okNom = ((d.data()[widget.champ] ?? '') as String).toLowerCase().contains(q);
                final p = d.data()['prix'];
                final sans = !(p is num && p > 0);
                return okNom && (!(produits && _sansPrix) || sans);
              }).toList();
              _visibles = docs;
              if (docs.isEmpty) return const Center(child: Text('Aucun élément.'));
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final p = d.data()['prix'];
                  final prixTexte = produits && p is num && p > 0 ? '${formatMontant(p.toInt())} FCFA' : null;
                  if (admin && _selectionActive) {
                    return CheckboxListTile(
                      value: _selection.contains(d.id),
                      onChanged: (v) => setState(() => v == true ? _selection.add(d.id) : _selection.remove(d.id)),
                      title: Text(d.data()[widget.champ] as String? ?? ''),
                      subtitle: prixTexte == null ? null : Text(prixTexte),
                    );
                  }
                  return ListTile(
                    title: Text(d.data()[widget.champ] as String? ?? ''),
                    subtitle: prixTexte == null ? null : Text(prixTexte),
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
