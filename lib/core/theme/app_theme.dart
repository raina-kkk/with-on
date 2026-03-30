import 'package:flutter/material.dart';

/// WithOn UI — 웜 크림 라이트 / 프로페셔널 다크 (Dark)
class AppTheme {

  // ── Light 테마 Color 정리 ──
  // Light: 배경 #FFFFFF (전체 앱 바탕)
  static const Color bgLight = Color(0xFFF2F2F7);
  static const Color bgDeep = Color(0xFFF5F5F5);  // ?? 이건 어디서 사용하는지 확인 필요

  /// Light UI 브랜드 톤. **반투명** `0x90A67041`(알파 ≈56%) — 아래 깔린 배경과 블렌딩되어
  /// **실제로 보이는 RGB는 배경마다 달라짐**. Chrome도 `Theme.of(context).primaryColor`로 칠한 영역은
  /// 밝은 캔버스 위에서 더 옅게 보일 수 있음. **전면 단색(스플래시)** 은 [splashBackground]만 쓸 것.
  static const Color primary = Color(0x90A67041);

  /// 스플래시·OS 스플래시용 **완전 불투명** #A67041 (`0xFFA67041`). [primary]와 값이 비슷해 보여도
  /// 알파 유무가 달라 **같은 색이 아님**. 웹 `AppTheme.splashBackground`·Android `splash_background`와 동일.
  static const Color splashBackground = Color(0xFFA67041);

  // Secondary #F2E6C2 — 강조 포인트(아이콘, 텍스트 버튼) [리본 버튼 Color]
  static const Color secondary = Color(0x90A67041);
  // Accent #C7D6D9 — 비활성, 칩, 배지 등 보조 UI [네비게이션 바 텍스트 Color]
  static const Color accent = Color(0xFFC7D6D9);



  // Light: 텍스트 (Primary=핵심, Secondary=강조 톤)
  static const Color textDark = Color(0xFF232C34);
  static const Color textMedium = Color(0xFF232C34);
  static const Color textLight = Color(0xFF5C6B75);
  static const Color textMuted = Color(0xFF8A9BA3);

  // Light: 테두리 #F0EBCC (은은한 경계선)
  static const Color border = Color(0xFFF0EBCC);
  static const Color borderLight = Color(0xFFF5F1D8);


  // ── Dark 전용 (darkTheme에서 참조) ──
  // Dark: 배경 #0D0D0D (전체 앱 바탕)
  static const Color darkBackground = Color(0xFF0D0D0D);

  // Dark: 텍스트 (Primary=핵심, Secondary=강조 톤)
  static const Color darkPrimary = Color(0xFFF2F2F7);
  static const Color darkPrimaryText = Color(0xFF0D0D0D);
  
  static const Color darkCard = Color(0xFFF2F2F7);
  static const Color darkNavInactive = Color(0x99FAF8E3);


  static const Color darkSecondary = Color(0xFFF2F2F7);
  static const Color darkDivider = Color(0xFF1A2129);
  
  

  // ── 기도 상태 — Light 톤 (Secondary/Accent 활용) ──
  static const Color statusPraying = Color(0xFF72513E);
  static const Color statusWaiting = Color(0xFF232C34);
  static const Color statusResponded = Color(0xFF4A7C59);
  static const Color statusPartial = Color(0xFF5C6B75);
  static const Color statusGratitude = Color(0xFF8A9BA3);

  // Status-pill 배경/전경 (칩·배지 — Accent 톤)
  static const Color statusPrayingBg = Color(0xFFF0EBE0);
  static const Color statusPrayingFg = Color(0xFF72513E);
  static const Color statusWaitingBg = Color(0xFFE8ECEF);
  static const Color statusWaitingFg = Color(0xFF232C34);
  static const Color statusRespondedBg = Color(0xFFE8F0E6);
  static const Color statusRespondedFg = Color(0xFF4A7C59);
  static const Color statusPartialBg = Color(0xFFE8ECEF);
  static const Color statusPartialFg = Color(0xFF5C6B75);
  static const Color statusGratitudeBg = Color(0xFFE8EAED);
  static const Color statusGratitudeFg = Color(0xFF8A9BA3);

  // ── 기도 그룹/차트 (Light 톤) ──
  static const Color groupBlue = Color(0xFF5C6B75);
  static const Color chartPeach = Color(0xFF72513E);
  static const Color chartSkyBlue = Color(0xFF7A8B95);
  static const Color chartGreen = Color(0xFF4A7C59);
  static const Color chartLavender = Color(0xFF8A9BA3);

  // ── 네비 비활성 (Accent #C7D6D9) ──
  static const Color navInactive = Color(0xFFC7D6D9);

  // ── 에러/경고 (Light/Dark 공통) ──
  static const Color errorRed = Color(0xFFA64444);
  static const Color errorRedBg = Color(0xFFFDEAEA);

  // Light: 카드 #F8F8E6 (카드·입력창 — 배경과 층 분리)
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── 기존 참조 호환용 별칭 ──
  static const Color primaryColor = primary;
  static const Color backgroundLight = bgLight;
  static const Color accentYellow = statusGratitude;
  static const Color textMain = textDark;
  static const Color textSubtle = textMedium;

  /// 카드 데코레이션 — 배경색은 앱 배경과 동일, 테두리·그림자 유지 (Light 전용, context 없을 때)
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  /// 카드 데코레이션 — 테마 배경색 + 테두리·그림자 (라이트/다크 공통)
  static BoxDecoration cardDecorationFor(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkCard : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: (isDark ? darkDivider : border).withValues(alpha: 0.4),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bgLight,
      primaryColor: primary,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
        surface: bgLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textDark,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textLight),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: textDark,
          letterSpacing: 1,
          fontFamily: 'NotoSansKR',
        ),
      ),
      cardTheme: CardThemeData(
        color: bgLight,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: border.withValues(alpha: 0.4)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        displayMedium: base.textTheme.displayMedium?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        displaySmall: base.textTheme.displaySmall?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        titleLarge: base.textTheme.titleLarge?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        titleMedium: base.textTheme.titleMedium?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        titleSmall: base.textTheme.titleSmall?.copyWith(color: textDark, fontFamily: 'NotoSansKR'),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: textDark,
          height: 1.6,
          fontFamily: 'Pretendard',
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: textMedium,
          height: 1.7,
          fontFamily: 'Pretendard',
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: textMuted,
          letterSpacing: 0.5,
          fontFamily: 'Pretendard',
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(color: textDark, fontFamily: 'Pretendard'),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          color: textLight,
          letterSpacing: 1,
          fontFamily: 'Pretendard',
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(color: textDark, fontFamily: 'Pretendard'),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: secondary,//navInactive 20263008 PKW 아래 리본 메뉴 칼라 변경경
        unselectedItemColor: navInactive,//secondary,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: secondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(
            color: textLight, fontWeight: FontWeight.w500, fontFamily: 'Pretendard'),
        hintStyle: TextStyle(
            color: textLight.withValues(alpha: 0.6), fontFamily: 'Pretendard'),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.4),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkPrimary,
      colorScheme: base.colorScheme.copyWith(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: darkBackground,
        onPrimary: darkPrimaryText,
        onSurface: darkPrimaryText,
        surfaceContainerHighest: darkCard,
        error: errorRed,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: darkPrimaryText,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: darkPrimaryText.withValues(alpha: 0.9)),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: darkPrimaryText,
          letterSpacing: 1,
          fontFamily: 'NotoSansKR',
        ),
      ),
      cardTheme: CardThemeData(
        color: darkBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          side: const BorderSide(color: darkDivider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        displayMedium: base.textTheme.displayMedium?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        displaySmall: base.textTheme.displaySmall?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        titleLarge: base.textTheme.titleLarge?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        titleMedium: base.textTheme.titleMedium?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        titleSmall: base.textTheme.titleSmall?.copyWith(color: darkPrimaryText, fontFamily: 'NotoSansKR'),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: darkPrimaryText,
          height: 1.6,
          fontFamily: 'Pretendard',
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: darkPrimaryText.withValues(alpha: 0.9),
          height: 1.7,
          fontFamily: 'Pretendard',
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: darkPrimaryText.withValues(alpha: 0.7),
          letterSpacing: 0.5,
          fontFamily: 'Pretendard',
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(color: darkPrimaryText, fontFamily: 'Pretendard'),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          color: darkPrimaryText.withValues(alpha: 0.8),
          letterSpacing: 1,
          fontFamily: 'Pretendard',
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(color: darkPrimaryText, fontFamily: 'Pretendard'),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkNavInactive,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkSecondary,
          foregroundColor: darkPrimaryText,
          elevation: 4,
          shadowColor: darkSecondary.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: darkSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkSecondary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
            color: darkPrimaryText, fontWeight: FontWeight.w500, fontFamily: 'Pretendard'),
        hintStyle: TextStyle(
            color: darkPrimaryText.withValues(alpha: 0.6), fontFamily: 'Pretendard'),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: const TextStyle(
            color: darkPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 기존 코드 호환용 (main.dart, app_banner.dart 등에서 AppColors 참조)
/// 테마에 따라 다른 값을 쓰려면 BuildContext 필요 시 Theme.of(context) 사용.
class AppColors {
  static const Color primary = AppTheme.primary;
  static const Color accent = AppTheme.accent;
  static const Color border = AppTheme.border;
  static const Color navInactive = AppTheme.navInactive;
  static const Color bgLight = AppTheme.bgLight;
  static const Color textDark = AppTheme.textDark;
}
