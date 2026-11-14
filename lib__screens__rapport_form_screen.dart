import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../models/rapport.dart';
import '../services/auth_service.dart';
import '../services/rapport_service.dart';
import 'rapports_ecrits_screen.dart';

class _LigneEdit {
  _LigneEdit({String label = '', String montant = ''})
      : label = TextEditingController(text: label),
        montant = TextEditingController(text: montant);
  final TextEditingController label;
  final TextEditingController montant;
}

class _MoisEdit {
  _MoisEdit(this.mois, this.annee, this.lignes);
  int mois;
  int annee;
  final List<_LigneEdit> lignes;
}

class RapportFormScreen extends StatefulWidget {
  const RapportFormScreen({super.key, required this.profil, this.rapport});
  final UserProfile profil;
  final RapportData? rapport;

  @override
  State<RapportFormScreen> createState() => _RapportFormScreenState();
}

class _RapportFormScreenState extends State<RapportFormScreen> {
  final List<_MoisEdit> _mois = [];
  final _message = TextEditingController();
  final _nb = TextEditingController();

  _MoisEdit _nouveau(int index) {
    final base = DateTime.now();
    final k = base.year * 12 + base.month - 1 + index;
    return _MoisEdit(k % 12 + 1, k ~/ 12, [_LigneEdit(label: 'Ordonnances enfants'), _LigneEdit(label: 'Sur commande')]);
  }

  @override
  void initState() {
    super.initState();
    final r = widget.rapport;
    if (r != null) {
      for (final m in r.mois) {
        _mois.add(_MoisEdit(m.mois, m.annee,
            [for (final l in m.lignes) _LigneEdit(label: l.label, montant: '${l.montant}')]));
      }
      _message.text = r.message;
    } else {
      _mois.add(_nouveau(0));
    }
    _nb.text = '${_mois.length}';
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _changerNombre(String v) {
    final n = parseEntier(v);
    if (n < 1 || n > 36) return;
    setState(() {
      while (_mois.length < n) {
        _mois.add(_nouveau(_mois.length));
      }
      while (_mois.length > n) {
        _mois.removeLast();
      }
    });
  }

  List<MoisRapport>? _construire() {
    final res = <MoisRapport>[];
    for (final m in _mois) {
      final lignes = <LigneRapport>[];
      for (final l in m.lignes) {
        final montant = parseEntier(l.montant.text);
        final label = l.label.text.trim();
        if (label.isEmpty && montant == 0) continue;
        if (label.isEmpty) {
          _msg('Saisir le nom de la facture pour ${numeroFacture(m.mois, m.annee)}.');
          return null;
        }
        if (montant <= 0) continue; // ligne laissée à zéro : ignorée
        lignes.add(LigneRapport(label: label, montant: montant));
      }
      if (lignes.isEmpty) {
        _msg('Aucun montant saisi pour ${numeroFacture(m.mois, m.annee)}.');
        return null;
      }
      res.add(MoisRapport(mois: m.mois, annee: m.annee, lignes: lignes));
    }
    return res;
  }

  Future<void> _enregistrer({required bool pdf}) async {
    final mois = _construire();
    if (mois == null) return;
    RapportService.instance.enregistrer(widget.rapport?.id, mois, _message.text.trim());
    if (pdf) {
      await partagerRapportEcrit(
          context, RapportData(id: widget.rapport?.id ?? '', mois: mois, message: _message.text.trim()));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce rapport ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    RapportService.instance.supprimer(widget.rapport!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final annees = [for (var y = DateTime.now().year - 4; y <= DateTime.now().year + 1; y++) y];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rapport == null ? 'Nouveau rapport' : 'Modifier le rapport'),
        actions: [
          if (widget.rapport != null && widget.profil.isAdmin)
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _supprimer),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _nb,
          keyboardType: TextInputType.number,
          onChanged: _changerNombre,
          decoration: const InputDecoration(labelText: 'Nombre de mois du rapport', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _mois.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mois ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      value: _mois[i].mois,
                      decoration: const InputDecoration(labelText: 'Mois', border: OutlineInputBorder()),
                      items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(moisFr[m - 1]))],
                      onChanged: (v) => setState(() => _mois[i].mois = v ?? _mois[i].mois),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: annees.contains(_mois[i].annee) ? _mois[i].annee : null,
                      decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
                      items: [for (final y in annees) DropdownMenuItem(value: y, child: Text('$y'))],
                      onChanged: (v) => setState(() => _mois[i].annee = v ?? _mois[i].annee),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                for (var j = 0; j < _mois[i].lignes.length; j++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _mois[i].lignes[j].label,
                          decoration: const InputDecoration(labelText: 'Facture', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _mois[i].lignes[j].montant,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder()),
                        ),
                      ),
                    ]),
                  ),
                Row(children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _mois[i].lignes.add(_LigneEdit())),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une facture'),
                  ),
                  const Spacer(),
                  Text('Total : ${formatMontant(_mois[i].lignes.fold<int>(0, (s, l) => s + parseEntier(l.montant.text)))}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Message sous le tableau (facultatif)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _enregistrer(pdf: true),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Padding(padding: EdgeInsets.all(12), child: Text('Enregistrer et créer le PDF')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _enregistrer(pdf: false),
          child: const Padding(padding: EdgeInsets.all(12), child: Text('Enregistrer seulement')),
        ),
      ]),
    );
  }
}
