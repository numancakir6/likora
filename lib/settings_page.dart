import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const String soundKey = 'settings_sound_on';
  static const String musicKey = 'settings_music_on';
  static const String vibrationKey = 'settings_vibration_on';

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static Future<bool> isSoundOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(soundKey) ?? true;
  }

  static Future<bool> isMusicOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(musicKey) ?? true;
  }

  static Future<bool> isVibrationOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(vibrationKey) ?? true;
  }

  static Future<void> vibrateTap() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(vibrationKey) ?? true)) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> vibrateLight() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(vibrationKey) ?? true)) return;
    await HapticFeedback.lightImpact();
  }
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _soundOn = true;
  bool _musicOn = true;
  bool _vibrationOn = true;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _soundOn = prefs.getBool(SettingsPage.soundKey) ?? true;
      _musicOn = prefs.getBool(SettingsPage.musicKey) ?? true;
      _vibrationOn = prefs.getBool(SettingsPage.vibrationKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setSound(bool value) async {
    if (value) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SettingsPage.soundKey, value);
      await SfxService.playClick();
      await SettingsPage.vibrateTap();
      if (!mounted) return;
      setState(() => _soundOn = value);
      return;
    }

    await SfxService.playClick(ignoreSetting: true);
    await SettingsPage.vibrateTap();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsPage.soundKey, value);
    if (!mounted) return;
    setState(() => _soundOn = value);
  }

  Future<void> _setMusic(bool value) async {
    await SfxService.playClick();
    await SettingsPage.vibrateTap();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsPage.musicKey, value);
    await MusicService.setEnabled(value);
    if (!mounted) return;
    setState(() => _musicOn = value);
  }

  Future<void> _setVibration(bool value) async {
    await SfxService.playClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsPage.vibrationKey, value);
    if (!mounted) return;
    setState(() => _vibrationOn = value);

    if (value) {
      await HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0415),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: _SettingsBackgroundPainter(_controller.value),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await SfxService.playClick();
                          await SettingsPage.vibrateTap();
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'AYARLAR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          children: [
                            _buildSettingTile(
                              icon: _soundOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              title: 'Ses',
                              value: _soundOn,
                              activeColor: const Color(0xFF00E676),
                              onChanged: _setSound,
                            ),
                            const SizedBox(height: 14),
                            _buildSettingTile(
                              icon: _musicOn
                                  ? Icons.music_note_rounded
                                  : Icons.music_off_rounded,
                              title: 'Müzik',
                              value: _musicOn,
                              activeColor: const Color(0xFF2979FF),
                              onChanged: _setMusic,
                            ),
                            const SizedBox(height: 14),
                            _buildSettingTile(
                              icon: _vibrationOn
                                  ? Icons.vibration_rounded
                                  : Icons.phonelink_ring_rounded,
                              title: 'Titreşim',
                              value: _vibrationOn,
                              activeColor: const Color(0xFFFF6D00),
                              onChanged: _setVibration,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.13),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: activeColor.withValues(alpha: 0.16),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: activeColor,
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsBackgroundPainter extends CustomPainter {
  final double progress;

  _SettingsBackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A0415),
          Color(0xFF10071D),
          Color(0xFF0A0415),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, bgPaint);

    final orbs = [
      (
        base: Offset(size.width * 0.18, size.height * 0.16),
        radius: 150.0,
        color: const Color(0xFFD500F9),
        dx: 18.0,
        dy: 14.0,
      ),
      (
        base: Offset(size.width * 0.84, size.height * 0.22),
        radius: 130.0,
        color: const Color(0xFF2979FF),
        dx: 16.0,
        dy: 12.0,
      ),
      (
        base: Offset(size.width * 0.22, size.height * 0.82),
        radius: 155.0,
        color: const Color(0xFFFF6D00),
        dx: 20.0,
        dy: 15.0,
      ),
      (
        base: Offset(size.width * 0.88, size.height * 0.76),
        radius: 140.0,
        color: const Color(0xFF00E676),
        dx: 14.0,
        dy: 18.0,
      ),
    ];

    for (int i = 0; i < orbs.length; i++) {
      final orb = orbs[i];
      final phase = (progress * 2 * pi) + i * 1.7;
      final cx = orb.base.dx + sin(phase) * orb.dx;
      final cy = orb.base.dy + cos(phase * 0.9) * orb.dy;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withValues(alpha: 0.20),
            orb.color.withValues(alpha: 0.05),
            orb.color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: orb.radius),
        );

      canvas.drawCircle(Offset(cx, cy), orb.radius, paint);
    }

    for (int i = 0; i < 8; i++) {
      final phase = progress * 2 * pi + i;
      final x =
          (size.width * (0.14 + (i * 0.09) % 0.72)) + sin(phase * 0.8) * 5;
      final y =
          (size.height * (0.16 + (i * 0.10) % 0.68)) + cos(phase * 0.7) * 6;

      final r = 2.0 + sin(phase * 1.2).abs() * 1.0;
      final color = [
        const Color(0xFF00E5FF),
        const Color(0xFFFFEA00),
        const Color(0xFFF50057),
        const Color(0xFFFFFFFF),
      ][i % 4];

      final dotPaint = Paint()..color = color.withValues(alpha: 0.14);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsBackgroundPainter oldDelegate) => true;
}
