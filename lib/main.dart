import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env for Gemini API keys)
  try {
    await dotenv.load(fileName: '.env');
    if (kDebugMode) {
      debugPrint('[Env] Successfully loaded .env file');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Env] Notice: .env file not loaded or empty: $e');
    }
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Debug-only emulator connection: enabled via --dart-define=USE_EMULATORS=true
  // Strictly inactive in release builds due to kDebugMode guard.
  const useEmulators = bool.fromEnvironment('USE_EMULATORS', defaultValue: false);
  if (kDebugMode && useEmulators) {
    debugPrint('[Emulator] 🛠️ Connecting to local Firebase Emulators (Auth: 9099, Firestore: 8080)...');
    FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  }

  runApp(
    const ProviderScope(
      child: SmartMediApp(),
    ),
  );
}
