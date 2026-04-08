import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_scope.dart';
import '../../services/notification_service.dart';
import '../widgets/app_banner.dart';

// ── HTML 컨셉 통계 차트 색상 ─────────────────────
const Color _kPeach = AppTheme.chartPeach;
const Color _kSkyBlue = AppTheme.chartSkyBlue;
const Color _kSageGreen = AppTheme.chartGreen;
const Color _kLavender = AppTheme.chartLavender;

const _kStatusChartConfig = <(String, Color)>[
  ('기도 중', AppTheme.statusPrayingFg),
  ('응답 받음', AppTheme.statusRespondedFg),
  ('기다리는 중', AppTheme.statusWaitingFg),
  ('방향 전환', AppTheme.statusPartialFg),
  ('잠시 멈춤', AppTheme.statusGratitudeFg),
];

// ── 통계 데이터 ─────────────────────────────────
class _PrayerStats {
  const _PrayerStats({
    required this.thisMonth,
    required this.totalAnswered,
    required this.totalAll,
    required this.participatedCount,
    required this.last7Days,
    required this.statusCounts,
  });

  final int thisMonth;
  final int totalAnswered;
  final int totalAll;
  final int participatedCount;
  final List<int> last7Days;
  final List<int> statusCounts;

  static _PrayerStats empty() => const _PrayerStats(
        thisMonth: 0,
        totalAnswered: 0,
        totalAll: 0,
        participatedCount: 0,
        last7Days: [0, 0, 0, 0, 0, 0, 0],
        statusCounts: [0, 0, 0, 0, 0],
      );
}

class _TopGroup {
  const _TopGroup({
    required this.groupId,
    required this.name,
    required this.totalHoldClicks,
  });

  final String groupId;
  final String name;
  final int totalHoldClicks;
}

class _TopMember {
  const _TopMember({
    required this.memberUid,
    required this.nickname,
    required this.totalHoldClicks,
  });

  final String memberUid;
  final String nickname;
  final int totalHoldClicks;
}

// ── 페이지 ─────────────────────────────────────
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.currentIndex,
    this.onSelectTab,
    this.onCenterTap,
  });

  final int currentIndex;
  final ValueChanged<int>? onSelectTab;
  final VoidCallback? onCenterTap;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _nickname;
  bool _isLoadingNickname = true;
  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isNotifLoading = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _prayersSub;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadNickname();
    _loadNotificationSettings();
    _subscribeToStats();
  }

  @override
  void dispose() {
    _prayersSub?.cancel();
    super.dispose();
  }

  // ── 닉네임 ─────────────────────────────────────
  Future<void> _loadNickname() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingNickname = false);
      return;
    }
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _nickname = (doc.data()?['nickname'] as String?)?.trim();
        _isLoadingNickname = false;
      });
    }
  }

  Future<void> _openChangeNicknameDialog() async {
    final controller = TextEditingController(text: _nickname ?? '');
    final newNickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('닉네임 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기도 그룹에서 보여지는 이름을 변경합니다.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textLight,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '새 닉네임',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('변경하기'),
          ),
        ],
      ),
    );
    if (newNickname == null || newNickname.isEmpty || newNickname == _nickname) {
      return;
    }
    await _updateNickname(newNickname);
  }

  Future<void> _updateNickname(String newNickname) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nickname': newNickname,
        'updated_at': now,
      });
      final prayersQuery = await FirebaseFirestore.instance
          .collection('prayers')
          .where('owner_uid', isEqualTo: uid)
          .get();
      if (prayersQuery.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in prayersQuery.docs) {
          batch.update(doc.reference, {
            'owner_nickname': newNickname,
            'updated_at': now,
          });
        }
        await batch.commit();
      }
      if (mounted) {
        setState(() => _nickname = newNickname);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('닉네임이 변경되었습니다.\n기존 기도 카드에도 반영되었습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '닉네임 변경 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.')));
      }
    }
  }

  // ── 실시간 통계 구독 ─────────────────────────
  void _subscribeToStats() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() {});
      return;
    }
    _prayersSub?.cancel();
    _prayersSub = FirebaseFirestore.instance
        .collection('prayers')
        .where('owner_uid', isEqualTo: uid)
        .snapshots()
        .listen(
      (snapshot) async {
        debugPrint('[통계] prayers 변경 감지: ${snapshot.docs.length}건');
        await _computeStats(uid, snapshot.docs);
      },
      onError: (e) {
        debugPrint('[통계] 스트림 오류: $e');
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _computeStats(
    String uid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> prayerDocs,
  ) async {
    try {
      // 프로필 화면에서는 통계 탭에만 상세 통계를 노출합니다.
      // 여기서는 스트림 구독만 유지하고 별도의 계산은 하지 않습니다.
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[통계] 계산 오류: $e');
      if (mounted) setState(() {});
    }
  }

  // ── 알림 설정 ───────────────────────────────────
  Future<void> _loadNotificationSettings() async {
    final settings = await NotificationService.instance.loadSettings();
    if (mounted) {
      setState(() {
        _notifEnabled = settings.enabled;
        _notifTime = settings.time;
        _isNotifLoading = false;
      });
    }
  }

  Future<void> _toggleNotification(bool value) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '로컬 알림은 Android / iOS 앱에서만 지원됩니다.\n스마트폰 앱으로 설치 후 사용해 주세요.')));
      }
      return;
    }
    if (value) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  '알림 권한이 필요합니다.\n기기 설정에서 알림을 허용해 주시면 감사하겠습니다.')));
        }
        return;
      }
      await NotificationService.instance.scheduleDailyReminder(_notifTime);
      await NotificationService.instance
          .saveSettings(enabled: true, time: _notifTime);
      await NotificationService.instance.debugPendingNotifications();
      if (mounted) {
        setState(() => _notifEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '매일 ${_notifTime.format(context)}에 기도 알림을 드리겠습니다.')));
      }
    } else {
      await NotificationService.instance.cancelReminder();
      await NotificationService.instance
          .saveSettings(enabled: false, time: _notifTime);
      if (mounted) setState(() => _notifEnabled = false);
    }
  }

  Future<void> _changeNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSecondary
                  : AppTheme.accent,
              onPrimary: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkPrimary
                  : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _notifTime = picked);
      await NotificationService.instance.scheduleDailyReminder(picked);
      await NotificationService.instance
          .saveSettings(enabled: true, time: picked);
      await NotificationService.instance.debugPendingNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('알림 시간이 ${picked.format(context)}로 변경되었습니다.')));
      }
    }
  }

  // ── 빌드 ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () async {
                if (mounted) setState(() {});
                _subscribeToStats();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: AppBanner.totalHeightFor(context) + 8,
                  left: 0,
                  right: 0,
                  bottom: 40,
                ),
                child: Column(
                  children: [
                    _buildProfileCard(context),
                    _buildNotificationCard(context),
                    _buildThemeModeCard(context),
                    const SizedBox(height: 8),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBanner(
              titleLeft: 'With',
              titleRight: 'On',
              subtitle: '함께하는 기도의 여정',
              onNotification: () {
                widget.onSelectTab?.call(1);
                Navigator.of(context).pop();
              },
              onProfile: () {},
              isProfileActive: true,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppTheme.darkDivider
                : AppColors.border.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProfileNavItem(
                icon: Icons.home_rounded,
                label: '홈',
                isActive: widget.currentIndex == 0,
                onTap: () => _onTapNav(0),
              ),
              _ProfileNavItem(
                icon: Icons.person_rounded,
                label: '나의 기도',
                isActive: widget.currentIndex == 1,
                onTap: () => _onTapNav(1),
              ),
              _ProfileCenterAddButton(
                onTap: () {
                  widget.onCenterTap?.call();
                  _onTapNav(1);
                },
              ),
              _ProfileNavItem(
                icon: Icons.groups_rounded,
                label: '중보 기도',
                isActive: widget.currentIndex == 3,
                onTap: () => _onTapNav(3),
              ),
              _ProfileNavItem(
                icon: Icons.bar_chart_rounded,
                label: '통계',
                isActive: widget.currentIndex == 4,
                onTap: () => _onTapNav(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTapNav(int index) {
    widget.onSelectTab?.call(index);
    Navigator.of(context).pop();
  }

  // ── 프로필 카드 (HTML 컨셉 24px 라운딩 카드) ──────
  Widget _buildProfileCard(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkDivider.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _nickname?.isNotEmpty == true
                    ? _nickname![0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkDivider
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _isLoadingNickname
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _nickname?.isNotEmpty == true
                                  ? _nickname!
                                  : '닉네임 없음',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _openChangeNicknameDialog,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgDeep,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 14, color: AppTheme.textLight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // 상단 프로필 카드에서는 간단 요약만 유지 (세부 통계는 통계 탭 전용)
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── 알림 설정 카드 ───────────────────────────────
  Widget _buildNotificationCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('알림 설정',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  )),
            ],
          ),
          const SizedBox(height: 16),

          // 토글 행: 상단 라벨과 같은 줄에 스위치, 설명은 그 아래
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '기도 시간 알림',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '정해진 시간에 매일 알림을 드립니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _isNotifLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _notifEnabled,
                          onChanged: _toggleNotification,
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                          thumbColor:
                              WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return null;
                          }),
                        ),
                ],
              ),
            ],
          ),

          // 시간 변경
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _notifEnabled
                ? Column(
                    children: [
                      Divider(
                        height: 24,
                        color: AppTheme.border.withValues(alpha: 0.4),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 18, color: AppTheme.textLight),
                          const SizedBox(width: 8),
                          const Text('알림 시간',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.textDark,
                              )),
                          const Spacer(),
                          GestureDetector(
                            onTap: _changeNotificationTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _notifTime.format(context),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.edit_rounded,
                                      size: 14, color: Theme.of(context).colorScheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── 테마 모드 선택 카드 ───────────────────────────
  Widget _buildThemeModeCard(BuildContext context) {
    final scope = ThemeModeScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();

    final themeMode = scope.themeMode;
    final setThemeMode = scope.setThemeMode;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkDivider : AppTheme.accent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: isDark ? AppTheme.darkDivider : AppTheme.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '테마',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(width: 350,
          child: SegmentedButton<ThemeMode>(
                segments: const [
                ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded, size: 18),
                label: Text('라이트'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded, size: 18),
                label: Text('다크'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness_rounded, size: 18),
                label: Text('시스템'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (Set<ThemeMode> selected) {
              setThemeMode(selected.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              ),
            ),
          ),
          )
        ],
      ),
    );
  }

  // ── 로그아웃 버튼 ────────────────────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoggingOut
              ? null
              : () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                    title: Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Theme.of(ctx).brightness == Brightness.dark
                        ? AppTheme.darkPrimary
                        : AppTheme.textDark,
                        ),
                        ),
                        content: Text(
                          '정말 로그아웃 하시겠어요?\n언제든지 다시 돌아오실 수 있습니다.',
                          style: TextStyle(
                            color: Theme.of(ctx).brightness == Brightness.dark
                            ? AppTheme.darkPrimary.withValues(alpha: 0.8)
                            : AppTheme.textMedium,
                            ),
                            ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('아니요, 계속 있을게요'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('네, 나갈게요'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              setState(() => _isLoggingOut = true);
              try {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true)
                    .popUntil((route) => route.isFirst);
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그아웃 중 오류가 발생했습니다. 다시 시도해 주세요.'),
                  ),
                );
              } finally {
                if (mounted) setState(() => _isLoggingOut = false);
              }
            }
          },
          icon: const Icon(Icons.logout_rounded, color: AppTheme.textLight),
          label: _isLoggingOut
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '로그아웃',
                  style: TextStyle(color: AppTheme.textLight),
                ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCard
                : Colors.transparent,
            side: const BorderSide(color: AppTheme.accent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  const _ProfileNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.accent;
    final inactiveColor = AppColors.navInactive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? activeColor : inactiveColor,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCenterAddButton extends StatelessWidget {
  const _ProfileCenterAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = colorScheme.secondary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 26,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── 나의 기도 기록만 보여주는 통계 전용 페이지 ─────────────────────────────
class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    this.onNotification,
    this.onProfile,
    this.notificationCount,
  });

  final VoidCallback? onNotification;
  final VoidCallback? onProfile;
  final int? notificationCount;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _PrayerStats? _stats;
  bool _isStatsLoading = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _prayersSub;

  int _streakDays = 0; // 기도에 참여한 연속 일수 (오늘 포함)
  bool _hasAnyGroup = true;
  List<_TopGroup> _topGroups = const [];
  List<_TopMember> _topMembers = const [];
  /// 격려 문구용: 이번 주에 작성된 기도 제목 수
  int _weekNewPrayerCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToStats();
  }

  @override
  void dispose() {
    _prayersSub?.cancel();
    super.dispose();
  }

  void _subscribeToStats() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isStatsLoading = false);
      return;
    }
    _prayersSub?.cancel();
    _prayersSub = FirebaseFirestore.instance
        .collection('prayers')
        .where('owner_uid', isEqualTo: uid)
        .snapshots()
        .listen(
      (snapshot) async {
        await _computeStats(uid, snapshot.docs);
      },
      onError: (_) {
        if (mounted) setState(() => _isStatsLoading = false);
      },
    );
  }

  Future<void> _computeStats(
    String uid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> prayerDocs,
  ) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);
      final sevenDaysAgo = today.subtract(const Duration(days: 6));

      int weekCount = 0;
      int monthCount = 0;
      int answeredCount = 0;
      final last7Participation = List<int>.filled(7, 0);
      final statusCounts = List<int>.filled(5, 0);

      // streak 및 최신 7일 "참여"를 구성하기 위한 날짜 집합
      // (개인: 새 기도제목 작성 / 비공유 카드: 기도손 클릭 / 기도 그룹 카드: 기도손 클릭)
      final participationDays = <DateTime>{};

      // 총 참여(=새 기도제목 + 기도손 클릭 수) 계산
      int personalClickCountTotal = 0;
      int groupClickCountTotal = 0;

      // 기도 그룹 top 섹션/멤버 top 섹션 계산용
      final Map<String, int> groupHoldTotalByGroupId = <String, int>{};
      final Map<String, int> memberHoldTotalByOwnerUid = <String, int>{};
      final Map<String, String> memberNicknameByUid = <String, String>{};

      for (final doc in prayerDocs) {
        final data = doc.data();
        final createdAt = _toDateTime(data['created_at']);
        final createdDay =
            DateTime(createdAt.year, createdAt.month, createdAt.day);
        final status = data['status'] as String?;

        if (!createdDay.isBefore(startOfWeek)) weekCount++;
        if (!createdDay.isBefore(startOfMonth)) monthCount++;
        if (status == 'answered') answeredCount++;

        final dayIndex = createdDay.difference(sevenDaysAgo).inDays;
        if (dayIndex >= 0 && dayIndex <= 6) last7Participation[dayIndex]++;

        // 새 기도제목 작성은 참여일로 포함
        participationDays.add(createdDay);

        final statusIndex = _statusToIndex(status);
        if (statusIndex >= 0 && statusIndex < 5) statusCounts[statusIndex]++;

        // 비공유(나의 기도 카드)에서 기도손 클릭 수 합산
        final isShared = (data['is_shared'] as bool?) ?? false;
        final personalHoldCount = (data['hold_count'] as int?) ?? 0;
        // _savePrayer에서 hold_count를 1로 초기화하므로, 추가 클릭분만 '기도손 클릭 수'로 보정
        final personalClickCount = personalHoldCount > 1 ? personalHoldCount - 1 : 0;
        if (!isShared) {
          personalClickCountTotal += personalClickCount;

          final lastHeldAt = _toNullableDateTime(data['last_held_at']);
          if (personalClickCount > 0 && lastHeldAt != null) {
            final heldDay = DateTime(lastHeldAt.year, lastHeldAt.month, lastHeldAt.day);
            participationDays.add(heldDay);

            final heldIndex = heldDay.difference(sevenDaysAgo).inDays;
            if (heldIndex >= 0 && heldIndex <= 6) {
              last7Participation[heldIndex] += personalClickCount;
            }
          }
        }
      }

      final holdSnap = await FirebaseFirestore.instance
          .collection('group_prayers')
          .where('held_by_uids', arrayContains: uid)
          .get();

      // 내 참여 집계(총 참여/최근 7일 참여용)
      for (final doc in holdSnap.docs) {
        final data = doc.data();
        final lastHeldAt = _toNullableDateTime(data['last_held_at']);
        if (lastHeldAt == null) continue;
        final heldDay = DateTime(lastHeldAt.year, lastHeldAt.month, lastHeldAt.day);

        final holdCount = (data['hold_count'] as int?) ?? 0;
        if (holdCount <= 0) continue;

        groupClickCountTotal += holdCount;
        participationDays.add(heldDay);

        final dayIndex = heldDay.difference(sevenDaysAgo).inDays;
        if (dayIndex >= 0 && dayIndex <= 6) {
          last7Participation[dayIndex] += holdCount;
        }
      }

      // 연속 참여(등불) 계산: 오늘 포함 기준, 과거로 연속으로 이어지는 참여일 수
      int streakDays = 0;
      var cursor = today;
      while (participationDays.contains(cursor)) {
        streakDays++;
        cursor = cursor.subtract(const Duration(days: 1));
      }

      // 사용자의 기도 그룹 여부/기도 그룹 top3 준비
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final groupIds = (userDoc.data()?['group_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final hasAnyGroup = groupIds.isNotEmpty;

      final topGroups = <_TopGroup>[];
      final topMembers = <_TopMember>[];
      if (hasAnyGroup) {
        // 최근 7일 기준으로, 내가 속한 그룹 전체의 group_prayers를 집계한다.
        const chunkSize = 10;
        for (var i = 0; i < groupIds.length; i += chunkSize) {
          final chunk = groupIds.skip(i).take(chunkSize).toList();
          final snap = await FirebaseFirestore.instance
              .collection('group_prayers')
              .where('group_id', whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            final lastHeldAt = _toNullableDateTime(data['last_held_at']);
            if (lastHeldAt == null) continue;
            final heldDay =
                DateTime(lastHeldAt.year, lastHeldAt.month, lastHeldAt.day);
            if (heldDay.isBefore(sevenDaysAgo)) continue;

            final holdCount = (data['hold_count'] as int?) ?? 0;
            if (holdCount <= 0) continue;

            final groupId = (data['group_id'] as String?) ?? '';
            if (groupId.isNotEmpty) {
              groupHoldTotalByGroupId[groupId] =
                  (groupHoldTotalByGroupId[groupId] ?? 0) + holdCount;
            }

            final ownerUid = (data['owner_uid'] as String?)?.trim() ?? '';
            if (ownerUid.isNotEmpty && ownerUid != uid) {
              final nickname =
                  (data['owner_nickname'] as String?)?.trim() ??
                      (data['owner_email'] as String?)?.trim() ??
                      ownerUid;
              memberNicknameByUid[ownerUid] = nickname;
              memberHoldTotalByOwnerUid[ownerUid] =
                  (memberHoldTotalByOwnerUid[ownerUid] ?? 0) + holdCount;
            }
          }
        }

        final filteredEntries = groupHoldTotalByGroupId.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final e in filteredEntries.take(3)) {
          final groupSnap = await FirebaseFirestore.instance
              .collection('groups')
              .doc(e.key)
              .get();
          final name = (groupSnap.data()?['name'] as String?)?.trim();
          topGroups.add(_TopGroup(
            groupId: e.key,
            name: (name?.isNotEmpty == true) ? name! : '기도 그룹',
            totalHoldClicks: e.value,
          ));
        }

        final sortedMembers = memberHoldTotalByOwnerUid.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final e in sortedMembers.take(3)) {
          topMembers.add(_TopMember(
            memberUid: e.key,
            nickname: memberNicknameByUid[e.key] ?? e.key,
            totalHoldClicks: e.value,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _weekNewPrayerCount = weekCount;
          _stats = _PrayerStats(
            thisMonth: monthCount,
            totalAnswered: answeredCount,
            totalAll: prayerDocs.length,
            participatedCount: prayerDocs.length + personalClickCountTotal + groupClickCountTotal,
            last7Days: last7Participation,
            statusCounts: statusCounts,
          );
          _isStatsLoading = false;
          _streakDays = streakDays;
          _hasAnyGroup = hasAnyGroup;
          _topGroups = topGroups;
          _topMembers = topMembers;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  String _encouragingMessage(int weekCount, int totalAnswered) {
    if (totalAnswered < 10) {
      return '더 많은 기도의 씨앗을 심어보세요!';
    }
    if (weekCount == 0) {
      return '이번 주 첫 기도를 나눠볼까요?\n작은 한 줄이면 충분합니다.';
    } else if (weekCount <= 2) {
      return '조금씩 쌓이는 기도가 아름답습니다.\n이번 주도 잘 하고 계세요.';
    } else if (weekCount <= 5) {
      return '꾸준히 기도하고 계시네요.\n이 발자국이 쌓여 귀한 역사가 됩니다.';
    } else {
      return '이번 주도 하나님 앞에 성실히\n나아가고 계십니다. 정말 귀한 걸음이에요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats ?? _PrayerStats.empty();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () async {
                if (mounted) setState(() => _isStatsLoading = true);
                _subscribeToStats();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: AppBanner.totalHeightFor(context) + 8,
                  left: 0,
                  right: 0,
                  bottom: 40,
                ),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecorationFor(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.auto_graph_rounded,
                                color:
                                    Theme.of(context).colorScheme.primary,
                                size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '나의 기도 기록',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Spacer(),
                          if (_isStatsLoading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // 연속 기도의 등불 (streak) — 색 칸은 격려 칸과 동일 높이 구조
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '연속 기도의 등불 $_streakDays일째 타오르고 있어요.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textDark,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('💛',
                                style: TextStyle(fontSize: 16, height: 1.2)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _encouragingMessage(
                                    _weekNewPrayerCount, stats.totalAnswered),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textDark,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // 카드 내부 폭이 매우 좁을 때만 1열 (일반 폰은 2×2 유지)
                          final narrow = constraints.maxWidth < 248;
                          final gap = narrow ? 8.0 : 10.0;
                          Widget rowPair(_StatChip a, _StatChip b) {
                            if (narrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  a,
                                  SizedBox(height: gap),
                                  b,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: a),
                                SizedBox(width: gap),
                                Expanded(child: b),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              rowPair(
                                _StatChip(
                                  icon: Icons.note_add_rounded,
                                  label: '기도 기록',
                                  value: '${stats.totalAll}',
                                  unit: '개',
                                  color: _kPeach,
                                ),
                                _StatChip(
                                  icon: Icons.calendar_month_rounded,
                                  label: '이번 달',
                                  value: '${stats.thisMonth}',
                                  unit: '개',
                                  color: _kSkyBlue,
                                ),
                              ),
                              SizedBox(height: gap),
                              rowPair(
                                _StatChip(
                                  icon: Icons.check_circle_outline_rounded,
                                  label: '응답받음',
                                  value: '${stats.totalAnswered}',
                                  unit: '개',
                                  color: _kSageGreen,
                                ),
                                _StatChip(
                                  icon: Icons.pan_tool_outlined,
                                  label: '기도 참여',
                                  value: '${stats.participatedCount}',
                                  unit: '회',
                                  color: _kLavender,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '기도 상태 분포',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textLight),
                      ),
                      const SizedBox(height: 8),
                      _StatusDistributionChart(counts: stats.statusCounts),
                      const SizedBox(height: 20),
                      const Text(
                        '최근 7일 기도 참여',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textLight),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 100,
                        child: _WeekActivityChart(dailyCounts: stats.last7Days),
                      ),

                      const SizedBox(height: 20),
                      // 최근 7일 기도 그룹 top3
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '최근 7일 기도의 등불이 밝은 기도 그룹 (Top 3)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!_hasAnyGroup)
                              const Text(
                                '함께 기도할 기도 그룹 모임을 시작해 보세요',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMedium,
                                  height: 1.5,
                                ),
                              )
                            else if (_topGroups.isEmpty)
                              const Text(
                                '최근 7일에 기도 그룹 기도손 클릭이 아직 없어요.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMedium,
                                  height: 1.5,
                                ),
                              )
                            else
                              Column(
                                children: List.generate(_topGroups.length, (i) {
                                  final g = _topGroups[i];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i == _topGroups.length - 1 ? 0 : 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            g.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textDark,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${g.totalHoldClicks}회',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      // 내가 많이 기도한 멤버 top3
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내가 많이 기도한 멤버 (Top 3)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!_hasAnyGroup)
                              const Text(
                                '기도 그룹이 없어서 집계할 멤버가 없어요.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMedium,
                                  height: 1.5,
                                ),
                              )
                            else if (_topMembers.isEmpty)
                              const Text(
                                '최근 7일 동안 멤버의 기도손 클릭 데이터가 없어요.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMedium,
                                  height: 1.5,
                                ),
                              )
                            else
                              Column(
                                children: List.generate(_topMembers.length, (i) {
                                  final m = _topMembers[i];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i == _topMembers.length - 1 ? 0 : 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            m.nickname,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textDark,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${m.totalHoldClicks}회',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBanner(
              titleLeft: 'With',
              titleRight: 'On',
              subtitle: '나의 기도 기록',
              onNotification: widget.onNotification,
              onProfile: widget.onProfile,
              notificationCount: widget.notificationCount,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 미니 통계 텍스트 ──────────────────────────────
// ── 통계 칩 위젯 (HTML 컨셉 라운딩 16) ──────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 상태 분포 차트 (HTML 컨셉 컬러) ─────────────
class _StatusDistributionChart extends StatelessWidget {
  const _StatusDistributionChart({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.fold<int>(0, (a, b) => a + b);
    final maxCount = total > 0 ? counts.reduce((a, b) => a > b ? a : b) : 1;

    return Column(
      children: List.generate(5, (i) {
        final label = _kStatusChartConfig[i].$1;
        final color = _kStatusChartConfig[i].$2;
        final count = i < counts.length ? counts[i] : 0;
        final widthRatio = maxCount > 0 ? (count / maxCount) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: widthRatio.clamp(0.0, 1.0),
                    minHeight: 20,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── 7일 활동 바 차트 ─────────────────────────────
class _WeekActivityChart extends StatelessWidget {
  const _WeekActivityChart({required this.dailyCounts});

  final List<int> dailyCounts;

  @override
  Widget build(BuildContext context) {
    final maxCount =
        dailyCounts.reduce((a, b) => a > b ? a : b).clamp(1, 9999);
    const maxBarHeight = 52.0;

    final now = DateTime.now();
    const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final dayLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return dayNames[d.weekday - 1];
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final count = dailyCounts[i];
        final isToday = i == 6;
        final hasActivity = count > 0;
        final barH =
            (count / maxCount * maxBarHeight).clamp(4.0, maxBarHeight);

        final barColor = isToday
            ? _kPeach
            : hasActivity
                ? _kPeach.withValues(alpha: 0.45)
                : AppTheme.bgDeep;

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasActivity)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.normal,
                    color: isToday ? _kPeach : AppTheme.textLight,
                  ),
                ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: hasActivity ? barH : 4,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dayLabels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isToday ? FontWeight.w700 : FontWeight.normal,
                  color: isToday ? _kPeach : AppTheme.textLight,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── 유틸 ─────────────────────────────────────────
DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _toNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int _statusToIndex(String? raw) {
  switch (raw) {
    case 'praying':
      return 0;
    case 'answered':
      return 1;
    case 'waiting':
      return 2;
    case 'refocused':
      return 3;
    case 'resting':
      return 4;
    case 'in_progress':
      return 3;
    default:
      return 0;
  }
}
