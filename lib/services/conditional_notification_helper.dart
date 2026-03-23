import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';

/// 앱 진입 시 조건 충족하면 로컬 알림 1회 표시 (SharedPreferences로 중복 방지)
class ConditionalNotificationHelper {
  /// 응답 완료 10개 달성 시 [알림 A], 기도 중 100일 경과 시 [알림 B] 검사
  static Future<void> checkAndShow(String? uid) async {
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('prayers')
          .where('owner_uid', isEqualTo: uid)
          .get();

      int answeredCount = 0;
      final List<({String id, String title, DateTime createdAt})> prayingPrayers = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final createdAt = _toDateTime(data['created_at']);
        final title = (data['title'] as String?)?.trim().isEmpty != true
            ? (data['title'] as String?)!.trim()
            : '기도 제목';

        if (status == 'answered') answeredCount++;
        if (status == 'praying') {
          prayingPrayers.add((id: doc.id, title: title, createdAt: createdAt));
        }
      }

      final now = DateTime.now();
      const hundredDays = Duration(days: 100);

      // [알림 A] 응답 10개 달성
      if (answeredCount >= 10) {
        final shown = await NotificationService.instance.wasAnswered10Shown();
        if (!shown) {
          await NotificationService.instance.showConditionalNotification(
            id: 10,
            title: '응답의 열매',
            body: '벌써 10개의 기도에 응답을 받으셨네요! 하나님과 함께한 소중한 열매들을 확인해보세요.',
            payload: 'answered_10',
          );
          await NotificationService.instance.markAnswered10Shown();
        }
      }

      // [알림 B] 기도 중(PRAYING) 100일 경과 — 첫 1건만 (앱 접속 시)
      for (final p in prayingPrayers) {
        if (now.difference(p.createdAt) >= hundredDays) {
          final shown = await NotificationService.instance.wasPraying100Shown(p.id);
          if (!shown) {
            await NotificationService.instance.showConditionalNotification(
              id: 11,
              title: '잊고 있던 간구',
              body: '이 기도를 시작한 지 100일이 되었습니다: \'${p.title.length > 20 ? "${p.title.substring(0, 20)}…" : p.title}\'. 여전히 하나님은 기도를 듣고 계십니다.',
              payload: 'praying_100_${p.id}',
            );
            await NotificationService.instance.markPraying100Shown(p.id);
          }
          break; // 한 번에 하나만
        }
      }
    } catch (_) {}
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
