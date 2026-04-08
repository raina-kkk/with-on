import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_scope.dart';
import 'firebase_options.dart';
import 'presentation/pages/group_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/app_splash_page.dart';
import 'presentation/pages/my_room_page.dart';
import 'presentation/pages/profile_page.dart';
import 'services/conditional_notification_helper.dart';
import 'services/notification_service.dart';
import 'services/account_data_recovery_service.dart';

// ── [MVP: Spark 플랜] 기도 그룹 실시간 푸시(FCM) 비활성화 ──────────────────────
// Blaze 전환 후 Cloud Functions로 푸시 발송 시 아래 주석 해제 후 사용.
// import 'package:firebase_messaging/firebase_messaging.dart';
// @pragma('vm:entry-point')
// Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// }

// ── 진입점 ────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM 백그라운드 핸들러 (Spark 플랜에서는 미사용)
  // FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // 로컬 알림 플러그인 초기화
  await NotificationService.instance.initialize();
  await initializeDateFormatting('ko_KR');

  runApp(const WithOnApp());
}

const String _kThemeModeKey = 'theme_mode';

Future<ThemeMode> _loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_kThemeModeKey);
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

Future<void> _saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  final value = mode == ThemeMode.light
      ? 'light'
      : mode == ThemeMode.dark
          ? 'dark'
          : 'system';
  await prefs.setString(_kThemeModeKey, value);
}

// ── 앱 루트 ───────────────────────────────────
class WithOnApp extends StatefulWidget {
  const WithOnApp({super.key});

  @override
  State<WithOnApp> createState() => _WithOnAppState();
}

class _WithOnAppState extends State<WithOnApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode().then((mode) {
      if (mounted) setState(() => _themeMode = mode);
    });
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveThemeMode(mode);
  }

  void _handleSplashCompleted() {
    if (!mounted || !_showSplash) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeModeScope(
      themeMode: _themeMode,
      setThemeMode: _setThemeMode,
      child: MaterialApp(
        title: 'With;On',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        // 스플래시 페이드아웃 시 뒤는 Theme(앱 다크 설정)이 아니라 OS 밝기에 맞춘 바탕 — 검정 플래시 완화
        builder: (context, child) {
          final content = child ?? const SizedBox.shrink();
          if (!_showSplash) return content;
          final bridge = MediaQuery.platformBrightnessOf(context) ==
                  Brightness.dark
              ? AppTheme.darkBackground
              : AppTheme.bgLight;
          return ColoredBox(color: bridge, child: content);
        },
        home: _showSplash
            ? AppSplashPage(onCompleted: _handleSplashCompleted)
            : const _AuthGate(),
      ),
    );
  }
}

// ── 인증 게이트 ────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _recoveryTriggered = false;

  void _runRecoveryOnce(User user) {
    if (_recoveryTriggered) return;
    _recoveryTriggered = true;
    AccountDataRecoveryService.recoverByEmail(user).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final bridge = MediaQuery.platformBrightnessOf(context) ==
                  Brightness.dark
              ? AppTheme.darkBackground
              : AppTheme.bgLight;
          return Scaffold(
            backgroundColor: bridge,
            body: const SizedBox.expand(),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          _runRecoveryOnce(snapshot.data!);
          return const MainScaffold();
        }
        return const LoginPage();
      },
    );
  }
}

// ── 메인 스캐폴드 (HTML 목업 스타일: 홈 / 나의 기도 / + / 중보 기도 탭 / 통계) ─────
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final ValueNotifier<VoidCallback?> _openAddPrayerNotifier = ValueNotifier<VoidCallback?>(null);
  final GlobalKey _groupPageKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(
        onNavigateToMyPrayer: () => setState(() => _currentIndex = 1),
        onNavigateToGroup: () => setState(() => _currentIndex = 3),
        onNavigateToGroupPrayer: _openGroupPrayerFromHome,
        onNavigateToProfile: _openProfilePage,
        onNotification: _openNotificationsFromHome,
        notificationCount: null, // TODO: stream from notification count
      ),
      MyRoomPage(
        onRegisterAddPrayer: (cb) => _openAddPrayerNotifier.value = cb,
        onProfile: _openProfilePage,
      ),
      const SizedBox.shrink(), // center + only
      GroupPage(
        key: _groupPageKey,
        onNotification: _openNotificationsFromHome,
        onProfile: _openProfilePage,
        notificationCount: null,
      ),
      StatsPage(
        onNotification: _openNotificationsFromHome,
        onProfile: _openProfilePage,
        notificationCount: null,
      ),
    ];
    _restoreNotificationSchedule();
    Future.microtask(() async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await ConditionalNotificationHelper.checkAndShow(uid);
    });
  }

  void _openNotificationsFromHome() {
    // 홈에서 알림 탭 시 나의 기도 페이지에서 시트 열기 등은 MyRoomPage 의존
    setState(() => _currentIndex = 1);
  }

  void _openProfilePage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          currentIndex: _currentIndex,
          onSelectTab: (index) {
            setState(() => _currentIndex = index);
          },
          onCenterTap: _onCenterTap,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _openAddPrayerNotifier.dispose();
    super.dispose();
  }

  Future<void> _restoreNotificationSchedule() async {
    final settings = await NotificationService.instance.loadSettings();
    if (settings.enabled) {
      await NotificationService.instance
          .scheduleDailyReminder(settings.time);
    }
  }

  void _onCenterTap() {
    _openAddPrayerNotifier.value?.call();
    setState(() => _currentIndex = 1);
  }

  void _openGroupPrayerFromHome(String groupId, String prayerId) {
    setState(() => _currentIndex = 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _groupPageKey.currentState;
      if (state == null) return;
      (state as dynamic).focusPrayerFromHome(
        groupId: groupId,
        prayerId: prayerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bodyIndex = _currentIndex == 2 ? 1 : (_currentIndex > 2 ? _currentIndex - 1 : _currentIndex);

    return Scaffold(
      body: IndexedStack(
        index: bodyIndex,
        children: [
          _pages[0],
          _pages[1],
          _pages[3],
          _pages[4],
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
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
              _NavItem(
                icon: Icons.home_rounded,
                label: '홈',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: '나의 기도',
                isActive: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _CenterAddButton(onTap: _onCenterTap),
              _NavItem(
                icon: Icons.groups_rounded,
                label: '중보 기도',
                isActive: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: '통계',
                isActive: _currentIndex == 4,
                onTap: () => setState(() => _currentIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final activeColor = navTheme.selectedItemColor ?? AppTheme.accent;
    final inactiveColor = navTheme.unselectedItemColor ?? AppColors.navInactive;
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

class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({required this.onTap});

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
        ),
        child: Icon(
          Icons.add_rounded,
          color: isDark ? AppTheme.darkBackground : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
