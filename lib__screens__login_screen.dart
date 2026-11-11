import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _busy = false;
  bool? _setup; // null = chargement
  String? _erreur;

  @override
  void initState() {
    super.initState();
    AuthService.instance.needsSetup().then((v) {
      if (mounted) setState(() => _setup = v);
    }).catchError((_) {
      if (mounted) setState(() => _setup = false);
    });
  }

  Future<void> _valider() async {
    setState(() {
      _busy = true;
      _erreur = null;
    });
    try {
      if (_mdp.text.length < 8) throw 'Le mot de passe doit contenir au moins 8 caractères.';
      if (_setup == true) {
        if (_nom.text.trim().isEmpty) throw 'Saisissez votre nom.';
        await AuthService.instance.createFirstAdmin(nom: _nom.text, email: _email.text, password: _mdp.text);
      } else {
        await AuthService.instance.signIn(_email.text, _mdp.text);
      }
    } catch (e) {
      setState(() => _erreur = e is String ? e : 'Connexion impossible. Vérifiez l\'e-mail, le mot de passe et le réseau.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_setup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final premier = _setup == true;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.receipt_long, size: 64),
                  const SizedBox(height: 8),
                  const Text('FACTURATION ADUA',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(premier ? 'Premier lancement : créez le compte administrateur principal.' : 'Connexion',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (premier) ...[
                    TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mdp,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe (8 caractères minimum)', border: OutlineInputBorder()),
                  ),
                  if (_erreur != null) Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _valider,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(premier ? 'Créer l\'administrateur' : 'Se connecter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
