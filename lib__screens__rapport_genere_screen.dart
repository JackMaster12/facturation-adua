import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/format.dart';
import '../models/ordonnance.dart';
import '../models/rapport.dart';
import '../pdf/rapport_pdf.dart';
import '../services/facture_service.dart';

class RapportGenereScreen extends StatefulWidget {
  const RapportGenereScreen({super.key});

  @override
  State<RapportGenereScreen> createState() => _RapportGenereScreenState();
}

class _RapportGenereScreenState extends State<RapportGenereScreen> {
  final _now = DateTime.now();
  late int _m1 = _now.month;
  late int _a1 = _now.year;
  late int _m2 = _now.month;
  late int _a2 = _now.year;
  final _message = TextEditingController();
  bool _occupe = false;

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _generer() async {
    final debut = _a1 * 12 + _m1 - 1;
    final fin = _a2 * 12 + _m2 - 1;
    if (fin < debut) return _msg('La période est à l\'envers : le mois de fin précède le mois de début.');
    if (fin - debut > 35) return _msg('Période trop longue (36 mois maximum).');
    setState(() => _occupe = true);
    try {
      final toutes = await FactureService.instance.terminees();
      final mois = <MoisRapport>[];
      for (var k = debut; k <= fin; k++) {
        final m = k % 12 + 1;
        final a = k ~/ 12;
        final lignes = <LigneRapport>[];
        final ord = toutes.where((f) => f.type == 'ordonnances' && f.mois == m && f.annee == a);
        final cmd = toutes.where((f) => f.type != 'ordonnances' && f.mois == m && f.annee == a);
        if (ord.isNotEmpty) {
          lignes.add(LigneRapport(label: 'Ordonnances enfants', montant: ord.fold<int>(0, (s, f) => s + f.total)));
        }
        if (cmd.isNotEmpty) {
          lignes.add(LigneRapport(label: 'Sur commande', montant: cmd.fold<int>(0, (s, f) => s + f.total)));
        }
        if (lignes.isNotEmpty) mois.add(MoisRapport(mois: m, annee: a, lignes: lignes));
      }
      if (mois.isEmpty) {
        _msg('Aucune facture terminée sur cette période.');
        return;
      }
      final octets = await genererPdfRapport(
        mois: mois,
        message: _message.text,
        date: DateTime.now(),
        manuel: false,
      );
      await Printing.sharePdf(
          bytes: octets, filename: 'Rapport-${titreRapport(mois).replaceAll(' ', '-')}.pdf');
    } catch (e) {
      _msg('Impossible de créer le rapport : $e');
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Widget _mois(String titre, int m, int a, void Function(int, int) change) {
    final annees = [for (var y = _now.year - 3; y <= _now.year + 1; y++) y];
    return Row(children: [
      Expanded(
        flex: 3,
        child: DropdownButtonFormField<int>(
          value: m,
          decoration: InputDecoration(labelText: '$titre : mois', border: const OutlineInputBorder()),
          items: [for (var i = 1; i <= 12; i++) DropdownMenuItem(value: i, child: Text(moisFr[i - 1]))],
          onChanged: (v) => setState(() => change(v ?? m, a)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: DropdownButtonFormField<int>(
          value: a,
          decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
          items: [for (final y in annees) DropdownMenuItem(value: y, child: Text('$y'))],
          onChanged: (v) => setState(() => change(m, v ?? a)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Générer un rapport')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Le rapport reprend uniquement les factures terminées de la période choisie.'),
        const SizedBox(height: 16),
        _mois('Début', _m1, _a1, (m, a) {
          _m1 = m;
          _a1 = a;
        }),
        const SizedBox(height: 12),
        _mois('Fin', _m2, _a2, (m, a) {
          _m2 = m;
          _a2 = a;
        }),
        const SizedBox(height: 16),
        TextField(
          controller: _message,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Message sous le tableau (facultatif)',
            hintText: 'Ex. ordre de virement sur un autre compte bancaire…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _occupe ? null : _generer,
          icon: const Icon(Icons.picture_as_pdf),
          label: Padding(padding: const EdgeInsets.all(12), child: Text(_occupe ? 'Création…' : 'Générer le PDF')),
        ),
      ]),
    );
  }
}
