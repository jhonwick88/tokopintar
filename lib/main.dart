import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';
import 'dart:developer' as dev;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Resilient Firebase initialization block.
  // Attempts to load credentials, falling back to local mock databases
  // if files/keys are not yet configured in the workspace.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    dev.log('Firebase initialized successfully.');
    
    // Attempt anonymous authentication to secure Firestore rules
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      dev.log('Firebase Anonymous Auth success: ${userCredential.user?.uid}');
    } catch (authError) {
      dev.log('Firebase Anonymous Auth failed: $authError');
    }
  } catch (e) {
    dev.log('Firebase initialization failed: $e. Operating in Mock Offline Mode.');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Toko Pintar POS',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
