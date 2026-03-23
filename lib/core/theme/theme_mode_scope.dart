import 'package:flutter/material.dart';

/// 앱 최상단에서 테마 모드를 제공하고, 설정 화면에서 변경할 수 있게 함.
class ThemeModeScope extends InheritedWidget {
  const ThemeModeScope({
    super.key,
    required this.themeMode,
    required this.setThemeMode,
    required super.child,
  });

  final ThemeMode themeMode;
  final void Function(ThemeMode) setThemeMode;

  static ThemeModeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
  }

  static ThemeModeScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ThemeModeScope not found. Wrap with ThemeModeScope.');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) {
    return oldWidget.themeMode != themeMode;
  }
}
