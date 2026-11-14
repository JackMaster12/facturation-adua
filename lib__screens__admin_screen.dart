import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/sauvegarde_service.dart';
import 'entreprise_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _nouveauCompte(BuildContext context) async {
    final nom = TextEditingController();
    final email = TextEditingController();
    final mdp = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau compte utilisateur'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
          TextField(controller: mdp, decoration: const InputDecoration(labelText: 'Mot de passe (8 caractères minimum)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (mdp.text.length < 8) throw 'Mot de passe trop court (8 caractères minimum).';
      await AuthService.instance.createUser(nom: nom.text, email: email.text, password: mdp.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte créé.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is String ? e : 'Création impossible : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nouveauCompte(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau compte'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('nom').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Informations de l\'entreprise'),
                subtitle: const Text('Émetteur, NIF, compte bancaire, client'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EntrepriseScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Sauvegarder les données'),
                subtitle: const Text('Crée un fichier à envoyer (WhatsApp, e-mail, Drive)'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(const SnackBar(content: Text('Préparation de la sauvegarde…')));
                  try {
                    await sauvegarderDonnees();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Sauvegarde impossible : $e')));
                  }
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Comptes. Un compte désactivé ne peut plus utiliser l\'application.'),
              ),
              for (final d in snap.data!.docs)
                ListTile(
                  title: Text(d.data()['nom'] as String? ?? ''),
                  subtitle: Text('${d.data()['email']} · ${d.data()['role'] == 'admin' ? 'administrateur' : 'utilisateur'}'),
                  trailing: d.data()['role'] == 'admin'
                      ? null
                      : Switch(
                          value: (d.data()['actif'] ?? true) as bool,
                          onChanged: (v) => AuthService.instance.setActif(d.id, v),
                        ),
                ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Paramètres de l\'entreprise et sauvegarde'),
                subtitle: Text('Prévus à la phase 5.'),
              ),
            ],
          );
        },
      ),
    );
  }
}
