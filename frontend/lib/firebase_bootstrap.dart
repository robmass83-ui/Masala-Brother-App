import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'core/config/app_config.dart';
import 'firebase_options.example.dart' as opts;

Future<FirebaseBootstrapResult> bootstrapFirebase() async {
  if (AppConfig.demoAuth || !opts.DefaultFirebaseOptions.isConfigured) {
    debugPrint(
      'Firebase in modalità DEMO '
      '(dart-define DEMO_AUTH o options non configurati).',
    );
    return FirebaseBootstrapResult.demo;
  }

  try {
    await Firebase.initializeApp(
      options: opts.DefaultFirebaseOptions.currentPlatform,
    );

    if (AppConfig.useFirebaseEmulator) {
      final host = kIsWeb ? 'localhost' : '10.0.2.2';
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      debugPrint('Emulatori Firebase su $host');
    }

    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    return FirebaseBootstrapResult.ready;
  } catch (e, st) {
    debugPrint('Firebase init error: $e\n$st');
    return FirebaseBootstrapResult.demo;
  }
}

enum FirebaseBootstrapResult { ready, demo }
