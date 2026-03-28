
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// HTML 스타일 공통 배너: "With ; On" / "나의 ; 기도" 등
/// 하단 반투명 그라데이션 + 알림·프로필 버튼
class AppBanner extends StatelessWidget implements PreferredSizeWidget {
  const AppBanner({
    super.key,
    required this.titleLeft,
    required this.titleRight,
    required this.subtitle,
    this.onNotification,
    this.onProfile,
    this.notificationCount,
    this.isProfileActive = false,
  });

  /// 예: "With" → "With" + ;(주황) + "On"
  final String titleLeft;
  final String titleRight;
  final String subtitle;
  final VoidCallback? onNotification;
  final VoidCallback? onProfile;
  final int? notificationCount;
  final bool isProfileActive;

  /// 배너 본문 높이 (콘텐츠·패딩·아이콘에 맞춰 오버플로우 방지)
  static const double bannerHeight = 58;
  /// 하단 반투명 그라데이션 구간 (스텝 많게 해서 부드럽게)
  static const double gradientTailHeight = 24;
  /// 상태바를 제외한 배너+꼬리 높이. Stack 본문 `top`/`padding`에는 사용하지 말고
  /// [totalHeightFor]를 쓰세요(기기별 상태바 높이 포함).
  static const double totalHeight = bannerHeight + gradientTailHeight;

  @override
  Size get preferredSize => const Size.fromHeight(totalHeight);

  /// 현재 컨텍스트에서의 배너 전체 높이.
  /// 폰/태블릿 공통으로 상태바(top padding) + 콘텐츠(bannerHeight) + 그라데이션 꼬리 구간을 모두 포함한다.
  static double totalHeightFor(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return topPadding + bannerHeight + gradientTailHeight;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final effectiveHeight = topPadding + bannerHeight + gradientTailHeight;

    return SizedBox(
      height: effectiveHeight,
      child: Stack(
        children: [
          // 불투명 배경 (그라데이션·블러 제거)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.bgLight,
              ),
            ),
          ),
          // 타이틀·버튼만 (패딩 축소)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: titleLeft,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                          color: AppTheme.textLight,
                          fontFamily: 'LeferiPoint',
                        ),
                        children: [
                          const TextSpan(
                            text: ';',
                            style: TextStyle(
                              fontSize: 24,
                              color: AppTheme.textLight,
                              fontFamily: 'LeferiPoint',
                            ),
                          ),
                          TextSpan(
                            text: titleRight,
                            style: const TextStyle(
                              fontSize: 26,
                              color: Color(0xFFFFD966),
                              fontFamily: 'LeferiPoint',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkPrimary
                        : AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onNotification != null)
                    IconButton(
                      onPressed: onNotification,
                      icon: notificationCount != null && notificationCount! > 0
                          ? Badge(
                              label: Text(
                                  notificationCount! > 99 ? '99+' : '$notificationCount'),
                              child: const Icon(Icons.notifications_none_rounded,
                                  color: AppColors.textDark, size: 22),
                            )
                          : const Icon(Icons.notifications_none_rounded,
                              color: AppColors.textDark, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: const CircleBorder(),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  const SizedBox(width: 6),
                  if (onProfile != null)
                    IconButton(
                      onPressed: onProfile,
                      icon: Icon(
                        Icons.person_rounded,
                        color: isProfileActive ? AppTheme.primary : AppColors.textDark,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: const CircleBorder(),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
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
