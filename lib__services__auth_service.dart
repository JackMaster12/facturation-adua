import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class UserProfile {
  UserProfile({required this.uid, required this.nom, required this.email, required this.role, required this.actif});
  final String uid;
  final String nom;
  final String email;
  final String role; // 'admin' ou 'utilisateur'
  final bool actif;

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return UserProfile(
      uid: d.id,
      nom: (m['nom'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      role: (m['role'] ?? 'utilisateur') as String,
      actif: (m['actif'] ?? true) as bool,
    );
  }
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  Stream<UserProfile?> profileStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UserProfile.fromDoc(d) : null);

  /// Vrai tant qu'aucun administrateur n'a été créé (premier lancement).
  Future<bool> needsSetup() async {
    final d = await _db.collection('config').doc('setup').get();
    return !d.exists;
  }

  /// Premier lancement : crée l'administrateur principal (une seule fois).
  /// Les règles Firestore refusent cette opération si config/setup existe déjà.
  Future<void> createFirstAdmin({required String nom, required String email, required String password}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = cred.user!.uid;
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(uid), {
      'nom': nom.trim(),
      'email': email.trim(),
      'role': 'admin',
      'actif': true,
      'creeLe': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('config').doc('setup'), {'adminUid': uid, 'creeLe': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  /// Administrateur : crée un compte utilisateur sans se déconnecter,
  /// grâce à une seconde instance Firebase.
  Future<void> createUser({required String nom, required String email, required String password}) async {
    FirebaseApp secondary;
    try {
      secondary = Firebase.app('secondaire');
    } catch (_) {
      secondary = await Firebase.initializeApp(name: 'secondaire', options: Firebase.app().options);
    }
    final auth2 = FirebaseAuth.instanceFor(app: secondary);
    final cred = await auth2.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = cred.user!.uid;
    await auth2.signOut();
    await _db.collection('users').doc(uid).set({
      'nom': nom.trim(),
      'email': email.trim(),
      'role': 'utilisateur',
      'actif': true,
      'creeLe': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setActif(String uid, bool actif) =>
      _db.collection('users').doc(uid).update({'actif': actif});
}
