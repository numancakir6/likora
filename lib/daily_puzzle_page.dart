import 'package:flutter/material.dart';

import 'audio_service.dart';
import 'settings_page.dart';

class DailyPuzzlePage extends StatelessWidget {
  const DailyPuzzlePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderPage(
      title: "GÜNLÜK BULMACA",
      icon: Icons.extension_outlined,
      color: const Color(0xFFFF6D00),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _PlaceholderPage({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0415),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () async {
            await SfxService.playClick();
            await SettingsPage.vibrateTap();
            if (!context.mounted) return;
            Navigator.pop(context);
          },
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                border: Border.all(color: color.withOpacity(0.35), width: 2),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.25), blurRadius: 30),
                ],
              ),
              child: Icon(icon, color: color, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Yakında burada olacak...",
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
