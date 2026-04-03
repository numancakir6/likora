import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exception}');
    debugPrint('${details.stack}');
  };

  if (!kIsWeb && Platform.isIOS) {
    try {
      debugPrint('Firebase init start');
      await Firebase.initializeApp().timeout(const Duration(seconds: 6));
      debugPrint('Firebase init OK');
    } catch (e, st) {
      debugPrint('Firebase init FAILED: $e');
      debugPrint('$st');
    }
  }

  runZonedGuarded(() {
    runApp(const LikoraApp());
  }, (e, st) {
    debugPrint('runZonedGuarded error: $e');
    debugPrint('$st');
  });
}

class LikoraApp extends StatelessWidget {
  const LikoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashPage(),
    );
  }
}
