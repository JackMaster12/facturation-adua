// Configuration Firebase du projet « facturation-adua » (application Android com.adua.facturation_adua).
// Ces identifiants ne sont pas secrets : la sécurité repose sur les règles Firestore.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'AIzaSyBDbloWN2NwP9YXrvQY-0JGZDXa3x8G4Hg',
        appId: '1:775838801788:android:2b2180f16793a975d60ef9',
        messagingSenderId: '775838801788',
        projectId: 'facturation-adua',
        storageBucket: 'facturation-adua.firebasestorage.app',
      );
}
