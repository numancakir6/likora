import 'package:flutter/material.dart';

class GamePage extends StatelessWidget {
  final int level;
  final int mapNumber;

  const GamePage({
    super.key,
    required this.level,
    required this.mapNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0415),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Map $mapNumber - Level $level'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Level Tamamlandı'),
        ),
      ),
    );
  }
}
