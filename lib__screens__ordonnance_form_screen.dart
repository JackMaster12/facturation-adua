import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../models/ordonnance.dart';
import '../services/facture_service.dart';
import '../widgets/selecteur_nom.dart';

class _LigneEdit {
  _LigneEdit({this.produit = '', String qte = '1', String montant = ''})
      : qte = TextEditingController(text: qte),
        montant = TextEditingController(text: montant);
  String produit;
  final TextEditingController qte;
  final TextEditingController montant;
}

class OrdonnanceFormScreen extends StatefulWidget {
  const OrdonnanceFormScreen({super.key, required this.facture, this.ordonnance});
  final FactureData facture;
  final OrdonnanceData? ordonnance;

  @override
  State<OrdonnanceFormScreen> createState() => _OrdonnanceFormScreenState();
}

class _OrdonnanceFormScreenState extends State<OrdonnanceFormScreen> {
  late final TextEditingController _date;
  late final TextEditingController _numero;
  String _enfant = '';
  final List<_LigneEdit> _lignes = [];

  @override
  void initState() {
    super.initState();
    final o = widget.ordonnance;
    _date = TextEditingController(text: formatDate(o?.date ?? DateTime.now()));
    _numero = TextEditingController(text: o?.numero ?? '');
    _enfant = o?.enfant ?? '';
    if (o != null) {
      for (final l in o.lignes) {
        _lignes.add(_LigneEdit(produit: l.produit, qte: '${l.quantite}', montant: '${l.montant}'));
      }
    }
    if (_lignes.isEmpty) _lignes.add(_LigneEdit());
  }

  int get _total => _lignes.fold(0, (s, l) => s + parseEntier(l.montant.text));

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _enregistrer() {
    final d = parseDate(_date.text);
    if (d == null) return _msg('Date invalide. Écrire par exemple 23/10/2026.');
    if (_numero.text.trim().isEmpty) return _msg('Saisir le numéro d\'ordonnance.');
    if (_enfant.isEmpty) return _msg('Choisir l\'enfant.');
    final lignes = <LigneOrd>[];
    for (final l in _lignes) {
      if (l.produit.isEmpty && l.montant.text.trim().isEmpty) continue;
      if (l.produit.isEmpty) return _msg('Choisir le produit de chaque ligne.');
      final m = parseEntier(l.montant.text);
      if (m <= 0) return _msg('Saisir le montant de « ${l.produit} ».');
      lignes.add(LigneOrd(produit: l.produit, quantite: parseEntier(l.qte.text), montant: m));
    }
    if (lignes.isEmpty) return _msg('Ajouter au moins un produit.');
    FactureService.instance
        .enregistrerOrdonnance(widget.facture.id, widget.ordonnance?.id, d, _numero.text.trim(), _enfant, lignes);
    Navigator.pop(context);
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette ordonnance ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    FactureService.instance.supprimerOrdonnance(widget.facture.id, widget.ordonnance!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ordonnance == null ? 'Nouvelle ordonnance' : 'Modifier l\'ordonnance'),
        actions: [
          if (widget.ordonnance != null)
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _supprimer),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _date,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(labelText: 'Date (JJ/MM/AAAA)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _numero,
          decoration: const InputDecoration(labelText: 'N° d\'ordonnance', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        SelecteurNom(
          collection: 'beneficiaires',
          libelle: 'Enfant',
          valeur: _enfant,
          onChoisi: (v) => setState(() => _enfant = v),
        ),
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
                      collection: 'produits',
                      libelle: 'Produit',
                      valeur: _lignes[i].produit,
                      onChoisi: (v) => setState(() => _lignes[i].produit = v),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lignes[i].montant,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Montant (FCFA)', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _lignes.add(_LigneEdit())),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un produit'),
        ),
        const SizedBox(height: 8),
        Text('Total ordonnance : ${formatMontant(_total)} FCFA',
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
