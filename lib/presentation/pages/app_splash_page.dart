import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ── 스플래시 타이밍 (ms) — 필요 시 여기 숫자만 조정하면 됩니다.
const _kPauseLampOnlyMs = 500; // 램프만 보이는 구간 (빈 램프 인지)
const _kLightFadeMs = 520; // 라이트 페이드 인 길이
const _kPauseAfterLightMs = 1000; // 라이트 켜진 뒤 → 문구 전 여유
/// 각 문구 줄 **불투명도 페이드 인** 총 시간. 짧게 = 더 빠름.
const _kTextFadeMs = 800;
const _kPauseBetweenTextLinesMs = 800; // 1줄 끝 → 2줄 시작 사이
const _kHoldToReadMs = 2000; // 문구 읽을 시간
const _kExitFadeMs = 720; // 전체 페이드 아웃

/// 램프가 화면 세로에서 차지하는 비율(위쪽). 상단~정중앙 사이 ≈ 1/4 지점에 램프 중심이 오도록 함.
const _kLampCenterYFraction = 0.25;

/// 문구 블록: SafeArea **아래 가장자리에서 위로** 띄우는 거리 = `높이 × 이 값`.
/// 값이 클수록 문구가 화면 **위쪽**으로 올라감.
/// (예전 코드는 최대 120px로 잘라서, 0.16 이상은 긴 화면에서 거의 변화가 없었음.)
const _kTextBottomPaddingFraction = 0.30;

/// 스플래시 문구 1·2줄 사이 추가 간격 (논리 픽셀). 더 넓히려면 값만 키우면 됨.
const _kSplashTextLineGap = 12.0;

/// 브랜드 컬러 배경 → 램프 → (짧은 페이드) 라이트 → 문구 → 전체 페이드아웃 후 [onCompleted].
class AppSplashPage extends StatefulWidget {
  const AppSplashPage({
    super.key,
    required this.onCompleted,
  });

  final VoidCallback onCompleted;

  @override
  State<AppSplashPage> createState() => _AppSplashPageState();
}

class _AppSplashPageState extends State<AppSplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _lightCtrl;
  late final AnimationController _textLine1Ctrl;
  late final AnimationController _textLine2Ctrl;
  late final AnimationController _exitCtrl;
  late final Animation<double> _lightFade;
  late final Animation<double> _textLine1Fade;
  late final Animation<double> _textLine2Fade;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    _lightCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kLightFadeMs),
    );
    _textLine1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTextFadeMs),
    );
    _textLine2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTextFadeMs),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kExitFadeMs),
    );

    _lightFade = CurvedAnimation(parent: _lightCtrl, curve: Curves.easeIn);
    _textLine1Fade =
        CurvedAnimation(parent: _textLine1Ctrl, curve: Curves.easeOut);
    _textLine2Fade =
        CurvedAnimation(parent: _textLine2Ctrl, curve: Curves.easeOut);
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    unawaited(_runSequence());
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: _kPauseLampOnlyMs));
    if (!mounted) return;
    await _lightCtrl.forward();
    await Future<void>.delayed(
        const Duration(milliseconds: _kPauseAfterLightMs));
    if (!mounted) return;
    await _textLine1Ctrl.forward();
    await Future<void>.delayed(
        const Duration(milliseconds: _kPauseBetweenTextLinesMs));
    if (!mounted) return;
    await _textLine2Ctrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: _kHoldToReadMs));
    if (!mounted) return;
    await _exitCtrl.forward();
    if (!mounted) return;
    widget.onCompleted();
  }

  @override
  void dispose() {
    _lightCtrl.dispose();
    _textLine1Ctrl.dispose();
    _textLine2Ctrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  static const _lineTextStyle = TextStyle(
    fontFamily: 'NotoSerifKR',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppTheme.bgLight,
    height: 1.35,
  );

  @override
  Widget build(BuildContext context) {
    // 앱 테마(저장된 다크)와 무관하게 OS 라이트/다크에 맞춤 — 시스템 라이트인데 램프만 어두운 현상 방지
    final lampPath = MediaQuery.platformBrightnessOf(context) ==
            Brightness.dark
        ? 'assets/images/Lamp_dark.png'
        : 'assets/images/Lamp.png';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _exitOpacity,
        child: SizedBox.expand(
          child: ColoredBox(
            color: AppTheme.splashBackground,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const lampSize = 160.0;
                  final h = constraints.maxHeight;
                  final topPad =
                      (h * _kLampCenterYFraction - lampSize / 2).clamp(8.0, h);
                  // 문구 2줄 높이 정도는 남기고, 비율이 그대로 반영되도록 상한을 화면에 맞춤
                  final maxBottomPad = (h - 88.0).clamp(28.0, h);
                  final textBottomPad =
                      (h * _kTextBottomPaddingFraction).clamp(28.0, maxBottomPad);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: topPad,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: lampSize,
                            height: lampSize,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                FadeTransition(
                                  opacity: _lightFade,
                                  child: Image.asset(
                                    'assets/images/Light.png',
                                    fit: BoxFit.contain,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                                Image.asset(
                                  lampPath,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.topCenter,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: textBottomPad,
                        child: Center(
                          child: IntrinsicWidth(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FadeTransition(
                                  opacity: _textLine1Fade,
                                  child: const Text(
                                    '함께 기도하면',
                                    textAlign: TextAlign.center,
                                    style: _lineTextStyle,
                                  ),
                                ),
                                const SizedBox(height: _kSplashTextLineGap),
                                FadeTransition(
                                  opacity: _textLine2Fade,
                                  child: const Text(
                                    '더 깊어집니다',
                                    textAlign: TextAlign.center,
                                    style: _lineTextStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
