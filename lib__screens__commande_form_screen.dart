import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../models/ordonnance.dart';
import '../services/facture_service.dart';
import '../services/unites_service.dart';
import '../widgets/a_revoir.dart';
import '../widgets/selecteur_nom.dart';

class _LigneEdit {
  _LigneEdit({this.produit = '', this.unite = '', String qte = '1', String montant = ''})
      : qte = TextEditingController(text: qte),
        montant = TextEditingController(text: montant);
  String produit;
  String unite;
  final TextEditingController qte;
  final TextEditingController montant;
  final FocusNode fQte = FocusNode();
  final FocusNode fMontant = FocusNode();
  final GlobalKey<SelecteurNomState> cle = GlobalKey<SelecteurNomState>();
  final GlobalKey<SelecteurNomState> cleUnite = GlobalKey<SelecteurNomState>();
}

class CommandeFormScreen extends StatefulWidget {
  const CommandeFormScreen({super.key, required this.facture, this.commande});
  final FactureData facture;
  final CommandeData? commande;

  @override
  State<CommandeFormScreen> createState() => _CommandeFormScreenState();
}

class _CommandeFormScreenState extends State<CommandeFormScreen> {
  late final TextEditingController _date;
  late final TextEditingController _libelle;
  bool _aRevoir = false;
  final TextEditingController _note = TextEditingController();
  final List<_LigneEdit> _lignes = [];
  final FocusNode _fDate = FocusNode();

  void _apres(VoidCallback f) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) f();
      });

  void _focusQte(_LigneEdit l) {
    l.qte.selection = TextSelection(baseOffset: 0, extentOffset: l.qte.text.length);
    l.fQte.requestFocus();
  }

  /// Nouvelle ligne de produit : la liste des produits s'ouvre aussitôt, prête pour la saisie.
  void _nouvelleLigne() {
    final l = _LigneEdit();
    setState(() => _lignes.add(l));
    _apres(() => l.cle.currentState?.ouvrir());
  }

  @override
  void initState() {
    super.initState();
    final c = widget.commande;
    _date = TextEditingController(text: formatDate(c?.date ?? DateTime.now()));
    _libelle = TextEditingController(text: c?.libelle ?? '');
    _aRevoir = c?.aRevoir ?? false;
    _note.text = c?.noteRevoir ?? '';
    if (c != null) {
      for (final l in c.lignes) {
        _lignes.add(_LigneEdit(produit: l.produit, unite: l.unite, qte: '${l.quantite}', montant: '${l.montant}'));
      }
    }
    if (_lignes.isEmpty) _lignes.add(_LigneEdit());
    semerUnites();
  }

  int get _total => _lignes.fold(0, (s, l) => s + parseEntier(l.montant.text));

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  String _pu(_LigneEdit l) {
    final q = parseEntier(l.qte.text);
    final m = parseEntier(l.montant.text);
    if (q <= 0 || m <= 0) return 'Prix unitaire : —';
    return 'Prix unitaire : ${formatMontant((m / q).round())} FCFA';
  }

  void _enregistrer() {
    final d = parseDate(_date.text);
    if (d == null) return _msg('Date invalide. Écrire par exemple 05/10/2026.');
    if (_libelle.text.trim().isEmpty) return _msg('Saisir le libellé de la commande (ex. CONSOMMABLES).');
    final lignes = <LigneCmd>[];
    for (final l in _lignes) {
      if (l.produit.isEmpty && l.montant.text.trim().isEmpty) continue;
      if (l.produit.isEmpty) return _msg('Choisir le produit de chaque ligne.');
      final q = parseEntier(l.qte.text);
      final m = parseEntier(l.montant.text);
      if (q <= 0) return _msg('Saisir la quantité de « ${l.produit} ».');
      if (m <= 0) return _msg('Saisir le montant de « ${l.produit} ».');
      lignes.add(LigneCmd(produit: l.produit, unite: l.unite.trim(), quantite: q, montant: m));
    }
    if (lignes.isEmpty) return _msg('Ajouter au moins un produit.');
    FactureService.instance
        .enregistrerCommande(widget.facture.id, widget.commande?.id, d, _libelle.text.trim().toUpperCase(), lignes,
            aRevoir: _aRevoir, note: _note.text);
    Navigator.pop(context);
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette commande ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    FactureService.instance.supprimerCommande(widget.facture.id, widget.commande!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.commande == null ? 'Nouvelle commande' : 'Modifier la commande'),
        actions: [
          if (widget.commande != null)
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _supprimer),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _libelle,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _fDate.requestFocus(),
          decoration: const InputDecoration(
              labelText: 'Libellé de la commande', hintText: 'ex. CONSOMMABLES', border: OutlineInputBorder()),
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
        ChampARevoir(valeur: _aRevoir, note: _note, onChange: (v) => setState(() => _aRevoir = v)),
        const SizedBox(height: 20),
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
                        setState(() => l.produit = v);
                        // Enchaînement : unité si elle est vide, sinon quantité.
                        _apres(() => l.unite.isEmpty ? l.cleUnite.currentState?.ouvrir() : _focusQte(l));
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
                SelecteurNom(
                  key: _lignes[i].cleUnite,
                  collection: 'unites',
                  libelle: 'Unité',
                  valeur: _lignes[i].unite,
                  onChoisi: (v) {
                    final l = _lignes[i];
                    setState(() => l.unite = v);
                    _apres(() => _focusQte(l));
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _lignes[i].qte,
                      focusNode: _lignes[i].fQte,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _lignes[i].fMontant.requestFocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lignes[i].montant,
                      focusNode: _lignes[i].fMontant,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      // Entrée : ligne suivante (nouveau produit) si le montant est rempli, sinon on ferme le clavier.
                      onSubmitted: (_) {
                        if (i == _lignes.length - 1 && parseEntier(_lignes[i].montant.text) > 0) {
                          _nouvelleLigne();
                        } else {
                          FocusScope.of(context).unfocus();
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Montant total (FCFA)', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: Text(_pu(_lignes[i]))),
              ]),
            ),
          ),
        TextButton.icon(
          onPressed: _nouvelleLigne,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un produit'),
        ),
        const SizedBox(height: 8),
        Text('Sous-total de la commande : ${formatMontant(_total)} FCFA',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _enregistrer,
          child: const Padding(padding: EdgeInsets.all(12), child: Text('Enregistrer')),
        ),
      ]),
    );
  }
}
