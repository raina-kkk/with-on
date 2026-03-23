import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppSplashPage extends StatefulWidget {
  const AppSplashPage({
    super.key,
    required this.onCompleted,
    this.minDisplayTime = const Duration(milliseconds: 5000),
  });

  final VoidCallback onCompleted;
  final Duration minDisplayTime;

  @override
  State<AppSplashPage> createState() => _AppSplashPageState();
}

class _AppSplashPageState extends State<AppSplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _lightFadeInAnimation;
  Timer? _nextTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _lightFadeInAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _nextTimer = Timer(widget.minDisplayTime, () {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  FadeTransition(
                    opacity: _lightFadeInAnimation,
                    child: Image.asset(
                      'assets/images/Light.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/Lamp_dark.png'
                        : 'assets/images/Lamp.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              '함께 기도하면,\n더 깊어집니다.',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.bgLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
