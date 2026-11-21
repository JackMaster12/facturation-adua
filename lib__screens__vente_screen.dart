import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/entreprise.dart';
import '../core/format.dart';
import '../core/noms.dart';
import '../models/vente.dart';
import '../pdf/recu_pdf.dart';
import '../services/prix_service.dart';
import '../widgets/selecteur_nom.dart';

class _LigneV {
  _LigneV() : qte = TextEditingController(text: '1'), prix = TextEditingController();
  String produit = '';
  final TextEditingController qte;
  final TextEditingController prix;
  final FocusNode fQte = FocusNode();
  final FocusNode fPrix = FocusNode();
  final GlobalKey<SelecteurNomState> cle = GlobalKey<SelecteurNomState>();
  bool manuel = false; // prix modifié à la main

  int get q => parseEntier(qte.text);
  int get p => parseEntier(prix.text);
  int get montant => q * p;
}

/// Vente au comptoir : produit un reçu imprimable (ticket) ou partageable (WhatsApp).
class VenteScreen extends StatefulWidget {
  const VenteScreen({super.key});

  @override
  State<VenteScreen> createState() => _VenteScreenState();
}

class _VenteScreenState extends State<VenteScreen> {
  final _client = TextEditingController();
  final _date = TextEditingController(text: formatDate(DateTime.now()));
  final _fDate = FocusNode();
  final List<_LigneV> _lignes = [_LigneV()];
  Map<String, int> _prix = {};
  String? _id; // identifiant de la vente enregistrée (les actions suivantes mettent à jour la même vente)
  String? _numero;
  VenteData? _vente; // vente enregistrée (le reçu n'est proposé qu'après l'enregistrement)
  String _sigSauvee = '';
  int _largeur = Entreprise.courant.largeurRecu;

  @override
  void initState() {
    super.initState();
    chargerPrixProduits().then((m) {
      if (mounted) setState(() => _prix = m);
    });
    Entreprise.charger().then((_) {
      if (mounted) setState(() => _largeur = Entreprise.courant.largeurRecu);
    });
  }

  int get _total => _lignes.fold(0, (s, l) => s + l.montant);

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _apres(VoidCallback f) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) f();
      });

  void _focusQte(_LigneV l) {
    l.qte.selection = TextSelection(baseOffset: 0, extentOffset: l.qte.text.length);
    l.fQte.requestFocus();
  }

  void _nouvelleLigne() {
    final l = _LigneV();
    setState(() => _lignes.add(l));
    _apres(() => l.cle.currentState?.ouvrir());
  }

  void _nouvelleVente() {
    setState(() {
      _client.clear();
      _date.text = formatDate(DateTime.now());
      _lignes
        ..clear()
        ..add(_LigneV());
      _id = null;
      _numero = null;
      _vente = null;
      _sigSauvee = '';
    });
  }

  /// Résumé de la saisie : sert à savoir si le formulaire a changé depuis l'enregistrement.
  String _signature() =>
      '${_date.text.trim()}|${_client.text.trim()}|${[for (final l in _lignes) '${l.produit}/${l.q}/${l.p}'].join(';')}';

  void _choisirLargeur(int mm) {
    setState(() => _largeur = mm);
    Entreprise.courant.largeurRecu = mm;
    // Mémorisé pour les prochaines fois (si le compte n'a pas le droit d'écrire les paramètres, c'est ignoré).
    unawaited(FirebaseFirestore.instance
        .collection('parametres')
        .doc('entreprise')
        .set({'largeurRecu': mm}, SetOptions(merge: true)).catchError((_) {}));
  }

  /// Vérifie la saisie, enregistre la vente (une seule fois) et retourne ses données.
  VenteData? _preparer() {
    final d = parseDate(_date.text);
    if (d == null) {
      _msg('Date invalide. Écrire par exemple 21/11/2026.');
      return null;
    }
    final lignes = <LigneVente>[];
    for (final l in _lignes) {
      if (l.produit.isEmpty && l.prix.text.trim().isEmpty) continue;
      if (l.produit.isEmpty) {
        _msg('Choisir le produit de chaque ligne.');
        return null;
      }
      if (l.q <= 0) {
        _msg('Saisir la quantité de « ${l.produit} ».');
        return null;
      }
      if (l.p <= 0) {
        _msg('Saisir le prix de « ${l.produit} ».');
        return null;
      }
      lignes.add(LigneVente(produit: l.produit, quantite: l.q, prix: l.p));
    }
    if (lignes.isEmpty) {
      _msg('Ajouter au moins un produit.');
      return null;
    }
    final col = FirebaseFirestore.instance.collection('ventes');
    _id ??= col.doc().id;
    final maintenant = DateTime.now();
    // La date du reçu est celle choisie ; le numéro vient de l'instant de la saisie.
    _numero ??= numeroRecu(maintenant);
    final client = _client.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final v = VenteData(
      id: _id!,
      numero: _numero!,
      date: d,
      client: client.isEmpty ? 'Client comptant' : client,
      lignes: lignes,
    );
    unawaited(col.doc(_id).set({
      ...v.toMap(),
      'creeLe': FieldValue.serverTimestamp(),
      'creePar': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true)).then((_) {}, onError: (_) {
      if (mounted) {
        _msg('Le reçu est prêt, mais la vente n\'a pas pu être enregistrée dans l\'historique '
            '(règles Firebase à publier).');
      }
    }));
    return v;
  }

  /// Bouton « Enregistrer la vente » : vérifie la saisie, enregistre, puis propose le reçu.
  void _enregistrer() {
    final v = _preparer();
    if (v == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _vente = v;
      _sigSauvee = _signature();
    });
    _msg('Vente enregistrée. Vous pouvez imprimer ou partager le reçu.');
  }

  Future<void> _agir(Future<void> Function(BuildContext, VenteData) action) async {
    final v = _vente;
    if (v == null) return;
    await action(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final sauvee = _vente != null && _signature() == _sigSauvee;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vente'),
        actions: [
          IconButton(tooltip: 'Nouvelle vente', icon: const Icon(Icons.restart_alt), onPressed: _nouvelleVente),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _client,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _fDate.requestFocus(),
          decoration: const InputDecoration(
              labelText: 'Client', hintText: 'Nom du client (facultatif)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _date,
          focusNode: _fDate,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            final l = _lignes.first;
            if (l.produit.isEmpty) l.cle.currentState?.ouvrir();
          },
          decoration: const InputDecoration(labelText: 'Date (JJ/MM/AAAA)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Papier du reçu :  '),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 58, label: Text('58 mm')),
              ButtonSegment(value: 80, label: Text('80 mm')),
            ],
            selected: {_largeur},
            onSelectionChanged: (s) => _choisirLargeur(s.first),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Produits', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < _lignes.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: SelecteurNom(
                      key: _lignes[i].cle,
                      collection: 'produits',
                      libelle: 'Produit',
                      valeur: _lignes[i].produit,
                      onChoisi: (v) {
                        final l = _lignes[i];
                        setState(() {
                          l.produit = v;
                          l.manuel = false;
                          final p = _prix[cleNom(v)];
                          if (p != null) l.prix.text = '$p'; // prix du catalogue, modifiable
                        });
                        _apres(() => _focusQte(l));
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retirer la ligne',
                    icon: const Icon(Icons.close),
                    onPressed: _lignes.length == 1 ? null : () => setState(() => _lignes.removeAt(i)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _lignes[i].qte,
                      focusNode: _lignes[i].fQte,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _lignes[i].fPrix.requestFocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lignes[i].prix,
                      focusNode: _lignes[i].fPrix,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() => _lignes[i].manuel = true),
                      onSubmitted: (_) {
                        if (i == _lignes.length - 1 && _lignes[i].p > 0) {
                          _nouvelleLigne();
                        } else {
                          FocusScope.of(context).unfocus();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Prix unitaire (FCFA)',
                        border: const OutlineInputBorder(),
                        helperText: _lignes[i].produit.isNotEmpty && _prix[cleNom(_lignes[i].produit)] == null
                            ? 'Pas de prix dans la base'
                            : null,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Montant : ${formatMontant(_lignes[i].montant)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        TextButton.icon(
          onPressed: _nouvelleLigne,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un produit'),
        ),
        const SizedBox(height: 90),
      ]),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('TOTAL : ${formatMontant(_total)} FCFA',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (!sauvee)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _enregistrer,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_vente == null ? 'Enregistrer la vente' : 'Mettre à jour la vente'),
                    ),
                  ),
                )
              else ...[
                Text('✔ Vente enregistrée · Reçu N° ${_vente!.numero}',
                    style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _agir(imprimerRecu),
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _agir(partagerRecuImage),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Image'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _agir(partagerRecuPdf),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                ]),
                TextButton.icon(
                  onPressed: _nouvelleVente,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle vente'),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
