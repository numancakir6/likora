import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_service.dart';
import 'settings_page.dart';

enum FeedbackType { bug, suggestion, other }

enum FeedbackStatus { pending, reviewed }

class UserFeedbackItem {
  final String id;
  final FeedbackType type;
  final String title;
  final String message;
  final int ts;
  final FeedbackStatus status;
  final String? adminNote;

  const UserFeedbackItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.ts,
    required this.status,
    this.adminNote,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'message': message,
        'ts': ts,
        'status': status.name,
        'adminNote': adminNote,
      };

  factory UserFeedbackItem.fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] as String?) ?? 'other';
    final statusName = (json['status'] as String?) ?? 'pending';

    return UserFeedbackItem(
      id: (json['id'] as String?) ?? '',
      type: FeedbackType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => FeedbackType.other,
      ),
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      status: FeedbackStatus.values.firstWhere(
        (e) => e.name == statusName,
        orElse: () => FeedbackStatus.pending,
      ),
      adminNote: json['adminNote'] as String?,
    );
  }
}

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage>
    with SingleTickerProviderStateMixin {
  static const String _prefsKey = 'likora_contact_items_v1';

  late final AnimationController _controller;
  late final FeedbackService _feedbackService;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();

  StreamSubscription? _sub;

  FeedbackType _type = FeedbackType.bug;
  bool _includeDeviceInfo = true;
  bool _sending = false;
  bool _loading = true;

  List<UserFeedbackItem> _items = const [];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _feedbackService = FeedbackService();

    _load().then((_) {
      _sub = _feedbackService.watchMine(type: 'contact').listen((snap) {
        for (final d in snap.docs) {
          final data = d.data();
          _applyAdminResult(
            id: d.id,
            status: data['status'] as String?,
            note: data['adminNote'] as String?,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    if (!mounted) return;

    if (raw == null || raw.trim().isEmpty) {
      setState(() {
        _items = const [];
        _loading = false;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((e) => UserFeedbackItem.fromJson(e.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => b.ts.compareTo(a.ts));

        setState(() {
          _items = list;
          _loading = false;
        });
      } else {
        setState(() {
          _items = const [];
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  Future<void> _save(List<UserFeedbackItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _applyAdminResult({
    required String id,
    required String? status,
    String? note,
  }) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final current = _items[idx];
    final nextStatus = (status == null || status == 'pending')
        ? current.status
        : FeedbackStatus.reviewed;
    final nextNote = note ?? current.adminNote;

    if (current.status == nextStatus && current.adminNote == nextNote) return;

    final updated = UserFeedbackItem(
      id: current.id,
      type: current.type,
      title: current.title,
      message: current.message,
      ts: current.ts,
      status: nextStatus,
      adminNote: nextNote,
    );

    final next = List<UserFeedbackItem>.from(_items)..[idx] = updated;

    if (!mounted) return;
    setState(() => _items = next);
    await _save(next);
  }

  bool _isDuplicate(String title, String message) {
    final t = title.trim().toLowerCase();
    final m = message.trim().toLowerCase();

    if (t.isEmpty || m.isEmpty) return false;

    return _items.any(
      (e) =>
          e.title.trim().toLowerCase() == t &&
          e.message.trim().toLowerCase() == m,
    );
  }

  String _newId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return 'L$ms${(ms % 100000).toString().padLeft(5, '0')}';
  }

  String _typeLabel(FeedbackType t) {
    switch (t) {
      case FeedbackType.bug:
        return 'HATA';
      case FeedbackType.suggestion:
        return 'ÖNERİ';
      case FeedbackType.other:
        return 'DİĞER';
    }
  }

  IconData _typeIcon(FeedbackType t) {
    switch (t) {
      case FeedbackType.bug:
        return Icons.bug_report_rounded;
      case FeedbackType.suggestion:
        return Icons.lightbulb_rounded;
      case FeedbackType.other:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _typeColor(FeedbackType t) {
    switch (t) {
      case FeedbackType.bug:
        return const Color(0xFFFF6D00);
      case FeedbackType.suggestion:
        return const Color(0xFF00E676);
      case FeedbackType.other:
        return const Color(0xFFD500F9);
    }
  }

  String _formatDate(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _buildPayload(String title, String message) {
    final b = StringBuffer();
    b.writeln('[KAYNAK] LIKORA');
    b.writeln('[BÖLÜM] İLETİŞİM');
    b.writeln('[${_typeLabel(_type)}] $title');
    b.writeln('');
    b.writeln(message.trim());

    if (_includeDeviceInfo) {
      b.writeln('\n---');
      b.writeln('Platform: ${kIsWeb ? 'WEB' : defaultTargetPlatform.name}');
      b.writeln('Uygulama: Likora');
      b.writeln('Tarih: ${DateTime.now().toIso8601String()}');
    }

    return b.toString();
  }

  Future<void> _showResultDialog({
    required bool ok,
    required String title,
    required String message,
  }) async {
    final accent = ok ? const Color(0xFF00E676) : const Color(0xFFFF6D00);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'contact_result',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: MediaQuery.of(ctx).size.width * 0.84,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.13),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: accent.withOpacity(0.18),
                          border: Border.all(color: accent.withOpacity(0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          ok
                              ? Icons.check_rounded
                              : Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Tamam',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final v = Curves.easeOut.transform(anim.value);
        return Opacity(
          opacity: v,
          child: Transform.scale(
            scale: 0.94 + (0.06 * v),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();

    final title = _titleCtrl.text.trim();
    final message = _msgCtrl.text.trim();

    if (kIsWeb || !Platform.isIOS) {
      await _showResultDialog(
        ok: false,
        title: 'ŞU AN KAPALI',
        message: 'İletişim sistemi şu an sadece iOS sürümünde aktif.',
      );
      return;
    }
    if (title.isEmpty) {
      await _showResultDialog(
        ok: false,
        title: 'EKSİK BİLGİ',
        message: 'Başlık boş olamaz.',
      );
      return;
    }

    if (message.isEmpty || message.length < 10) {
      await _showResultDialog(
        ok: false,
        title: 'EKSİK BİLGİ',
        message: 'Açıklama en az 10 karakter olmalı.',
      );
      return;
    }

    if (_isDuplicate(title, message)) {
      await _showResultDialog(
        ok: false,
        title: 'TEKRAR MESAJ',
        message: 'Bu geri bildirimi daha önce göndermişsin.',
      );
      return;
    }

    await SettingsPage.vibrateTap();

    setState(() => _sending = true);

    final payload = _buildPayload(title, message);

    String firestoreId;
    bool sentOk = false;

    try {
      firestoreId =
          await _feedbackService.send(type: 'contact', message: payload);
      sentOk = true;
    } catch (_) {
      firestoreId = _newId();
    }

    final item = UserFeedbackItem(
      id: firestoreId,
      type: _type,
      title: title,
      message: message,
      ts: DateTime.now().millisecondsSinceEpoch,
      status: FeedbackStatus.pending,
    );

    final next = [item, ..._items]..sort((a, b) => b.ts.compareTo(a.ts));

    if (mounted) {
      setState(() {
        _items = next;
        _sending = false;
      });
    }

    await _save(next);

    _titleCtrl.clear();
    _msgCtrl.clear();

    if (!mounted) return;

    await _showResultDialog(
      ok: sentOk,
      title: sentOk ? 'GÖNDERİLDİ' : 'KAYDEDİLDİ',
      message: sentOk
          ? 'Mesajın bize ulaştı. En kısa sürede inceleyeceğiz.'
          : 'İnternet yok gibi görünüyor. Mesajın cihazda kaydedildi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.height / 760.0).clamp(0.78, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0415),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: _ContactBackgroundPainter(_controller.value),
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
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'BİZE ULAŞIN',
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
                            _buildInfoCard(),
                            const SizedBox(height: 14),
                            _buildFormCard(s),
                            const SizedBox(height: 18),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    color: Colors.white.withOpacity(0.92),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'GÖNDERDİKLERİM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_items.isEmpty)
                              _buildEmptyHistoryCard()
                            else
                              ..._items.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildHistoryCard(e),
                                ),
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

  Widget _buildInfoCard() {
    return _glassCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFD500F9).withOpacity(0.16),
              border: Border.all(
                color: const Color(0xFFD500F9).withOpacity(0.30),
              ),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Hata, öneri veya diğer mesajlarını buradan bize iletebilirsin.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(double s) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _typeColor(_type).withOpacity(0.18),
                  border:
                      Border.all(color: _typeColor(_type).withOpacity(0.30)),
                ),
                child: Icon(
                  _typeIcon(_type),
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'YENİ MESAJ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: (16 * s).toDouble()),
          _buildSectionLabel('KONU'),
          const SizedBox(height: 8),
          _TypeSelector(
            selected: _type,
            onChanged: (value) async {
              await SettingsPage.vibrateTap();
              if (!mounted) return;
              setState(() => _type = value);
            },
          ),
          const SizedBox(height: 14),
          _buildSectionLabel('BAŞLIK'),
          const SizedBox(height: 8),
          _StyledTextField(
            controller: _titleCtrl,
            hint: 'Konuyu kısaca yaz',
            maxLength: 60,
            maxLines: 1,
          ),
          const SizedBox(height: 14),
          _buildSectionLabel('AÇIKLAMA'),
          const SizedBox(height: 8),
          _StyledTextField(
            controller: _msgCtrl,
            hint: _type == FeedbackType.bug
                ? 'Yaşadığın sorunu detaylı anlat...'
                : 'Mesajını buraya yaz...',
            maxLength: 500,
            maxLines: 5,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.70),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cihaz bilgisi eklensin',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _includeDeviceInfo,
                  onChanged: (v) async {
                    await SettingsPage.vibrateTap();
                    if (!mounted) return;
                    setState(() => _includeDeviceInfo = v);
                  },
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF2979FF),
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD500F9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _sending ? 'GÖNDERİLİYOR...' : 'GÖNDER',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return _glassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Henüz gönderilmiş mesaj yok.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(UserFeedbackItem item) {
    final isPending = item.status == FeedbackStatus.pending;
    final statusColor =
        isPending ? const Color(0xFFFFB300) : const Color(0xFF00E676);
    final statusText = isPending ? 'BEKLİYOR' : 'YANITLANDI';
    final statusIcon =
        isPending ? Icons.schedule_rounded : Icons.mark_email_read_rounded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.11),
                Colors.white.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(
                    icon: _typeIcon(item.type),
                    text: _typeLabel(item.type),
                    color: _typeColor(item.type),
                  ),
                  _pill(
                    icon: statusIcon,
                    text: statusText,
                    color: statusColor,
                  ),
                  Text(
                    _formatDate(item.ts),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.46),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.adminNote?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF00E676).withOpacity(0.10),
                    border: Border.all(
                      color: const Color(0xFF00E676).withOpacity(0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        size: 16,
                        color: Color(0xFF00E676),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.adminNote!,
                          style: const TextStyle(
                            color: Color(0xFFB9FFD9),
                            fontSize: 12.8,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(0.13),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.52),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.13),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD500F9).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final FeedbackType selected;
  final ValueChanged<FeedbackType> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        FeedbackType.bug,
        Icons.bug_report_rounded,
        'Hata',
        const Color(0xFFFF6D00),
      ),
      (
        FeedbackType.suggestion,
        Icons.lightbulb_rounded,
        'Öneri',
        const Color(0xFF00E676),
      ),
      (
        FeedbackType.other,
        Icons.chat_bubble_rounded,
        'Diğer',
        const Color(0xFFD500F9),
      ),
    ];

    return Row(
      children: items.map((item) {
        final isSelected = selected == item.$1;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == items.last ? 0 : 6),
            child: GestureDetector(
              onTap: () => onChanged(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? item.$4.withOpacity(0.18)
                      : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isSelected
                        ? item.$4.withOpacity(0.34)
                        : Colors.white.withOpacity(0.10),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      item.$2,
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.62),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.$3,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.68),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.30),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFD500F9),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _ContactBackgroundPainter extends CustomPainter {
  final double progress;

  _ContactBackgroundPainter(this.progress);

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
            orb.color.withOpacity(0.20),
            orb.color.withOpacity(0.05),
            orb.color.withOpacity(0.0),
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

      final dotPaint = Paint()..color = color.withOpacity(0.14);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ContactBackgroundPainter oldDelegate) => true;
}
