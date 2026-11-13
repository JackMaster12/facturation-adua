import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/facture_service.dart';
import 'facture_ordonnances_screen.dart';

class NouvelleFactureScreen extends StatefulWidget {
  const NouvelleFactureScreen({super.key});

  @override
  State<NouvelleFactureScreen> createState() => _NouvelleFactureScreenState();
}

class _NouvelleFactureScreenState extends State<NouvelleFactureScreen> {
  int _mois = DateTime.now().month;
  int _annee = DateTime.now().year;
  bool _occupe = false;

  Future<void> _creer() async {
    setState(() => _occupe = true);
    final id = idFacture('ordonnances', _mois, _annee);
    try {
      final cree = await FactureService.instance.creer('ordonnances', _mois, _annee);
      if (!mounted) return;
      if (!cree) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Une facture existe déjà pour ce mois. Ouverture de cette facture.')));
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FactureOrdonnancesScreen(factureId: id)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _occupe = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final annees = [for (var a = DateTime.now().year - 2; a <= DateTime.now().year + 1; a++) a];
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle facture : ordonnances')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Une seule facture mensuelle pour tous les enfants.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _mois,
            decoration: const InputDecoration(labelText: 'Mois', border: OutlineInputBorder()),
            items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(moisFr[m - 1]))],
            onChanged: (v) => setState(() => _mois = v ?? _mois),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _annee,
            decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
            items: [for (final a in annees) DropdownMenuItem(value: a, child: Text('$a'))],
            onChanged: (v) => setState(() => _annee = v ?? _annee),
          ),
          const SizedBox(height: 20),
          Text('Numéro : ${numeroFacture(_mois, _annee)}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _occupe ? null : _creer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(_occupe ? 'Création…' : 'Créer la facture')),
          ),
        ]),
      ),
    );
  }
}
