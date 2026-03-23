import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 알림 전담 싱글턴 서비스
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _kChannelId = 'daily_prayer';
  static const _kChannelName = '매일 기도 알림';
  static const _kNotifId = 0;
  static const _kChannelIdConditional = 'conditional_prayer';
  static const _kChannelNameConditional = '회상 알림';
  static const _kEnabled = 'notif_enabled';
  static const _kHour = 'notif_hour';
  static const _kMinute = 'notif_minute';
  static const _kPrefAnswered10Shown = 'notif_answered_10_shown';
  static const _kPrefPraying100Prefix = 'notif_praying_100_';

  /// 알림 탭 시 네비게이션용 — 앱에서 getAndClearPendingPayload()로 읽고 처리
  static String? _pendingPayload;
  static void setPendingPayload(String? p) => _pendingPayload = p;
  static String? getAndClearPendingPayload() {
    final p = _pendingPayload;
    _pendingPayload = null;
    return p;
  }

  // ── 웹 플랫폼 여부 ─────────────────────────────
  // flutter_local_notifications 는 Android / iOS 전용입니다.
  // 웹(Chrome)에서 실행 시 dart:io Platform API 자체가 지원되지 않아
  // 예외가 발생하므로, 모든 메서드에서 웹을 우선 감지해 조기 반환합니다.
  static bool get _isUnsupportedPlatform =>
      kIsWeb || (!Platform.isAndroid && !Platform.isIOS);

  // ── 초기화 (main에서 1회 호출) ──────────────
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[알림] 웹 환경 — 로컬 알림 미지원, 초기화 생략');
      return;
    }

    // 1) 전체 타임존 데이터베이스 로드
    tz_data.initializeTimeZones();

    // 2) 디바이스의 현지 타임존을 정확히 설정
    //    이 단계를 생략하면 tz.local 이 UTC로 고정돼 알림 시간이 어긋납니다.
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final String localTz = info.identifier;
      tz.setLocalLocation(tz.getLocation(localTz));
      debugPrint('[알림] 디바이스 타임존 설정: $localTz');
    } catch (e) {
      debugPrint('[알림] 타임존 감지 실패, 시스템 기본값 사용: $e');
    }

    // 3) 플러그인 초기화
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        debugPrint('[알림] 탭됨: payload=$payload');
        if (payload != null && payload.isNotEmpty) {
          setPendingPayload(payload);
        }
      },
    );
    debugPrint('[알림] NotificationService 초기화 완료');
  }

  // ── 권한 요청 ────────────────────────────────
  Future<bool> requestPermissions() async {
    if (_isUnsupportedPlatform) {
      debugPrint('[알림] 웹/미지원 환경 — 권한 요청 생략');
      return false;
    }
    debugPrint('[알림] 권한 요청 시작 (플랫폼: ${Platform.operatingSystem})');

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      debugPrint('[알림] Android 권한 결과: $granted');
      return granted;
    } else if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      debugPrint('[알림] iOS 권한 결과: $granted');
      return granted;
    }
    return false;
  }

  // ── 매일 알림 예약 ───────────────────────────
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (_isUnsupportedPlatform) {
      debugPrint('[알림] 웹/미지원 환경 — 알림 예약 생략');
      return;
    }
    debugPrint('[알림] 기존 알림 취소 후 재예약 시작...');
    await _plugin.cancel(_kNotifId);

    final now = DateTime.now();
    var target =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    final tzTarget = tz.TZDateTime.from(target, tz.local);

    debugPrint('[알림] 현재 시각: $now');
    debugPrint('[알림] 예약 목표: $target (로컬)');
    debugPrint('[알림] TZDateTime: $tzTarget');
    debugPrint('[알림] 사용 타임존: ${tz.local.name}');

    try {
      await _plugin.zonedSchedule(
        _kNotifId,
        '🙏 기도할 시간이에요',
        '오늘의 기도를 나눌 시간이에요. 잠시 골방으로 들어와 주세요.',
        tzTarget,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: '매일 정해진 시간에 기도를 알려드립니다.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: const BigTextStyleInformation(
              '오늘의 기도를 나눌 시간이에요.\n잠시 골방으로 들어와 주세요.',
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            subtitle: 'With:溫',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        '[알림] ✅ 기도 알림 예약 성공: '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')} 매일 반복',
      );
    } catch (e, st) {
      debugPrint('[알림] ❌ 알림 예약 실패: $e');
      if (kDebugMode) debugPrint(st.toString());
    }
  }

  // ── 예약된 알림 목록 확인 (디버그용) ──────────
  Future<void> debugPendingNotifications() async {
    if (_isUnsupportedPlatform) return;
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('[알림] 예약된 알림 개수: ${pending.length}');
    for (final n in pending) {
      debugPrint('  ▸ id=${n.id}, title=${n.title}, body=${n.body}');
    }
  }

  // ── 알림 취소 ────────────────────────────────
  Future<void> cancelReminder() async {
    if (_isUnsupportedPlatform) return;
    await _plugin.cancel(_kNotifId);
    debugPrint('[알림] 기도 알림 취소됨');
  }

  // ── SharedPreferences 저장/로드 ──────────────
  Future<void> saveSettings({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setInt(_kHour, time.hour);
    await prefs.setInt(_kMinute, time.minute);
    debugPrint('[알림] 설정 저장: enabled=$enabled, ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
  }

  Future<({bool enabled, TimeOfDay time})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? false;
    final hour = prefs.getInt(_kHour) ?? 8;
    final minute = prefs.getInt(_kMinute) ?? 0;
    debugPrint('[알림] 설정 로드: enabled=$enabled, $hour:${minute.toString().padLeft(2, '0')}');
    return (
      enabled: enabled,
      time: TimeOfDay(hour: hour, minute: minute),
    );
  }

  // ── 조건부 알림 기록 (중복 방지) ─────────────────
  Future<bool> wasAnswered10Shown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrefAnswered10Shown) ?? false;
  }

  Future<void> markAnswered10Shown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefAnswered10Shown, true);
  }

  Future<bool> wasPraying100Shown(String prayerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kPrefPraying100Prefix$prayerId') ?? false;
  }

  Future<void> markPraying100Shown(String prayerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPrefPraying100Prefix$prayerId', true);
  }

  // ── 즉시 알림 (조건부 회상용) — payload로 탭 시 화면 이동 ─
  Future<void> showConditionalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (_isUnsupportedPlatform) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelIdConditional,
            _kChannelNameConditional,
            channelDescription: '기도 회상·격려 알림',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[알림] 조건부 알림 표시 실패: $e');
    }
  }
}
