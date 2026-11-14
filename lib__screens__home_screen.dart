import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_screen.dart';
import 'base_donnees_screen.dart';
import 'factures_en_cours_screen.dart';
import 'factures_terminees_screen.dart';
import 'nouvelle_facture_screen.dart';
import 'rapport_genere_screen.dart';
import 'rapports_ecrits_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<UserProfile?>(
      stream: AuthService.instance.profileStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final p = snap.data;
        if (p == null || !p.actif) {
          return Scaffold(
            appBar: AppBar(title: const Text('FACTURATION ADUA')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(p == null ? 'Profil introuvable.' : 'Ce compte est désactivé. Contactez l\'administrateur.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: AuthService.instance.signOut, child: const Text('Se déconnecter')),
                ]),
              ),
            ),
          );
        }

        void bientot(String nom) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$nom : prévu aux phases suivantes.')));

        final boutons = <_Bouton>[
          _Bouton('Nouvelle facture sur ordonnances enfants', Icons.add_circle_outline, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NouvelleFactureScreen()))),
          _Bouton('Facture en cours : ordonnances enfants', Icons.child_care, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacturesEnCoursScreen()))),
          _Bouton('Nouvelle facture sur commande', Icons.add_box_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NouvelleFactureScreen(type: 'commandes')))),
          _Bouton('Facture en cours : sur commande', Icons.local_shipping_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacturesEnCoursScreen(type: 'commandes')))),
          _Bouton('Factures terminées', Icons.task_alt, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacturesTermineesScreen(profil: p)))),
          _Bouton('Générer un rapport', Icons.summarize_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RapportGenereScreen()))),
          _Bouton('Rédiger un rapport', Icons.edit_note, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RapportsEcritsScreen(profil: p)))),
          _Bouton('Base de données', Icons.storage_outlined,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => BaseDonneesScreen(profil: p)))),
          if (p.isAdmin)
            _Bouton('Administration', Icons.admin_panel_settings_outlined,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()))),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('FACTURATION ADUA'),
            actions: [
              IconButton(
                tooltip: 'Se déconnecter',
                icon: const Icon(Icons.logout),
                onPressed: AuthService.instance.signOut,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Bonjour ${p.nom}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final b in boutons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    ),
                    onPressed: b.action,
                    icon: Icon(b.icon),
                    label: Text(b.titre, style: const TextStyle(fontSize: 16)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Bouton {
  _Bouton(this.titre, this.icon, this.action);
  final String titre;
  final IconData icon;
  final VoidCallback action;
}
