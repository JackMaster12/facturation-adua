import 'package:flutter/material.dart';

import '../core/noms.dart';
import '../data/apprendre_data.dart';

class ApprendreScreen extends StatefulWidget {
  const ApprendreScreen({super.key});

  @override
  State<ApprendreScreen> createState() => _ApprendreScreenState();
}

class _ApprendreScreenState extends State<ApprendreScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cle = cleNom(_q.text);
    final resultats = <(ThemeSante, Fiche)>[];
    if (cle.isNotEmpty) {
      for (final t in themesSante) {
        for (final f in t.fiches) {
          if (cleNom('${f.nom} ${f.famille} ${f.usage} ${t.titre}').contains(cle)) resultats.add((t, f));
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Apprendre')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        TextField(
          controller: _q,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Rechercher un produit ou une maladie',
          ),
        ),
        const SizedBox(height: 12),
        if (cle.isEmpty) ...[
          const _Avertissement(),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [for (final t in themesSante) _CarteTheme(t)],
          ),
        ] else if (resultats.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun résultat.')))
        else
          for (final r in resultats) _FicheTuile(r.$2, r.$1.couleur, theme: r.$1.titre),
      ]),
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text(avertissementApprendre, style: TextStyle(fontSize: 12.5))),
      ]),
    );
  }
}

class _CarteTheme extends StatelessWidget {
  const _CarteTheme(this.t);
  final ThemeSante t;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: t.couleur.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThemeSanteScreen(theme: t))),
        child: Column(children: [
          Container(
            width: double.infinity,
            color: t.couleur,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Text(t.titre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.icone, size: 38, color: t.couleur),
                const SizedBox(height: 4),
                Text('${t.fiches.length} produits', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class ThemeSanteScreen extends StatelessWidget {
  const ThemeSanteScreen({super.key, required this.theme});
  final ThemeSante theme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(theme.titre),
        backgroundColor: theme.couleur,
        foregroundColor: Colors.white,
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text(theme.intro, style: const TextStyle(fontSize: 15, height: 1.35)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade400),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 6),
              Text('Signes d\'alerte : orienter vers un médecin',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
            ]),
            const SizedBox(height: 6),
            for (final a in theme.alertes)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(a)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: theme.couleur, borderRadius: BorderRadius.circular(10)),
          child: const Text('Produits à connaître',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        for (final f in theme.fiches) _FicheTuile(f, theme.couleur),
        const SizedBox(height: 12),
        const _Avertissement(),
      ]),
    );
  }
}

class _FicheTuile extends StatelessWidget {
  const _FicheTuile(this.f, this.couleur, {this.theme});
  final Fiche f;
  final Color couleur;
  final String? theme;

  Widget _bloc(String titre, String texte) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titre, style: TextStyle(fontWeight: FontWeight.bold, color: couleur, fontSize: 13)),
          const SizedBox(height: 2),
          Text(texte, style: const TextStyle(height: 1.3)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: couleur.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.medication_outlined, color: couleur),
        title: Text(f.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(theme == null ? f.famille : '$theme · ${f.famille}', style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bloc('À quoi ça sert', f.usage),
          _bloc('Précautions', f.precautions),
          _bloc('Conseil au patient', f.conseil),
        ],
      ),
    );
  }
}
