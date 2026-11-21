import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_screen.dart';
import 'apprendre_screen.dart';
import 'base_donnees_screen.dart';
import 'factures_en_cours_screen.dart';
import 'factures_terminees_screen.dart';
import 'nouvelle_facture_screen.dart';
import 'rapport_genere_screen.dart';
import 'rapports_ecrits_screen.dart';
import 'vente_screen.dart';
import 'ventes_historique_screen.dart';

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

        void aller(Widget ecran) => Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));

        final sections = <_Section>[
          _Section('Ordonnances enfants', const Color(0xFF0B6E4F), [
            _Bouton('Nouvelle facture', Icons.add_circle_outline, () => aller(const NouvelleFactureScreen())),
            _Bouton('Facture en cours', Icons.child_care, () => aller(const FacturesEnCoursScreen())),
          ]),
          _Section('Factures sur commande', const Color(0xFF1565C0), [
            _Bouton('Nouvelle facture', Icons.add_box_outlined,
                () => aller(const NouvelleFactureScreen(type: 'commandes'))),
            _Bouton('Facture en cours', Icons.local_shipping_outlined,
                () => aller(const FacturesEnCoursScreen(type: 'commandes'))),
          ]),
          _Section('Ventes', const Color(0xFF00838F), [
            _Bouton('Vente', Icons.point_of_sale, () => aller(const VenteScreen())),
            _Bouton('Historique', Icons.receipt_long, () => aller(VentesHistoriqueScreen(profil: p))),
          ]),
          _Section('Documents', const Color(0xFFEF6C00), [
            _Bouton('Factures terminées', Icons.task_alt, () => aller(FacturesTermineesScreen(profil: p))),
            _Bouton('Générer un rapport', Icons.summarize_outlined, () => aller(const RapportGenereScreen())),
            _Bouton('Rédiger un rapport', Icons.edit_note, () => aller(RapportsEcritsScreen(profil: p))),
          ]),
          _Section('Données et formation', const Color(0xFF6A1B9A), [
            _Bouton('Base de données', Icons.storage_outlined, () => aller(BaseDonneesScreen(profil: p))),
            _Bouton('Apprendre', Icons.menu_book_outlined, () => aller(const ApprendreScreen())),
            if (p.isAdmin) _Bouton('Administration', Icons.admin_panel_settings_outlined, () => aller(const AdminScreen())),
          ]),
        ];

        final couleurs = Theme.of(context).colorScheme;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // En-tête : logo, nom de l'application, utilisateur connecté
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [couleurs.primary, couleurs.primary.withValues(alpha: 0.78)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/icone.png', width: 64, height: 64),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('FACTURATION ADUA',
                            style: TextStyle(color: couleurs.onPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Bonjour ${p.nom}',
                            style: TextStyle(color: couleurs.onPrimary.withValues(alpha: 0.9), fontSize: 14)),
                        Text(p.isAdmin ? 'Administrateur' : 'Utilisateur',
                            style: TextStyle(color: couleurs.onPrimary.withValues(alpha: 0.75), fontSize: 12)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Se déconnecter',
                      icon: Icon(Icons.logout, color: couleurs.onPrimary),
                      onPressed: AuthService.instance.signOut,
                    ),
                  ]),
                ),
                for (final s in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(color: s.couleur, borderRadius: BorderRadius.circular(12)),
                      child: Text(s.titre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [for (final b in s.boutons) _Carte(b, s.couleur)],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section {
  _Section(this.titre, this.couleur, this.boutons);
  final String titre;
  final Color couleur;
  final List<_Bouton> boutons;
}

class _Carte extends StatelessWidget {
  const _Carte(this.b, this.couleur);
  final _Bouton b;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: couleur.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: b.action,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: couleur,
              child: Icon(b.icon, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(b.titre, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _Bouton {
  _Bouton(this.titre, this.icon, this.action);
  final String titre;
  final IconData icon;
  final VoidCallback action;
}
