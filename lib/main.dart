import 'package:flutter/material.dart';
import 'splash_page.dart';

void main() {
  runApp(const LikoraApp());
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
