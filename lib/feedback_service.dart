import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FeedbackService {
  /// Kullanıcı giriş yapmamışsa anonymous olarak giriş yaptırır.
  Future<String> _getUid() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[FeedbackService] Anonymous auth başlatılıyor...');
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
      debugPrint(
          '[FeedbackService] Anonymous auth BAŞARILI — uid=${user?.uid}');
    }
    if (user == null) throw Exception('Auth başarısız');
    return user.uid;
  }

  Future<String> send({
    required String type,
    required String message,
    String? suggestedWord,
  }) async {
    final uid = await _getUid();

    debugPrint('[FeedbackService] send başlıyor — uid=$uid type=$type');

    try {
      final ref =
          await FirebaseFirestore.instance.collection('user_messages').add({
        'uid': uid,
        'type': type,
        'message': message.trim(),
        'suggestedWord': suggestedWord?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'adminNote': null,
      });

      debugPrint('[FeedbackService] send BAŞARILI — docId=${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('[FeedbackService] send HATA: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMine({String? type}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[FeedbackService] watchMine HATA: kullanıcı giriş yapmamış!');
      return const Stream.empty();
    }

    final uid = user.uid;
    debugPrint(
        '[FeedbackService] watchMine başlatılıyor — uid=$uid type=$type');

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('user_messages')
        .where('uid', isEqualTo: uid);

    if (type != null) {
      q = q.where('type', isEqualTo: type);
    }

    q = q.orderBy('createdAt', descending: true);

    return q.snapshots().handleError((error) {
      debugPrint('[FeedbackService] watchMine HATA: $error');
    });
  }
}
