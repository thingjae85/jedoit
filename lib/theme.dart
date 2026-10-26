import 'package:flutter/material.dart';

/// 저두잇 색. 흰 바탕에 혼자 미션은 초록, 친구 챌린지는 주황으로 구분한다.
/// 글자·아이콘이 올라가는 진한 색은 흰 바탕과 4.5:1 이상 대비가 나도록 골랐다.
abstract final class JdColors {
  static const ink = Color(0xFF1F2326);
  static const subtle = Color(0xFF5F666D);
  static const faint = Color(0xFF6B7178);
  static const line = Color(0xFFF0F1F3);
  static const empty = Color(0xFFF1F2F4);
  static const box = Color(0xFFCDD2D7);
  static const panel = Color(0xFFF5F6F7);

  static const solo = Color(0xFF2E8566);
  static const soloText = Color(0xFF1F6B52);
  static const soloTint = Color(0xFFE3F4EC);
  static const soloMid = Color(0xFFBFE3D2);

  static const together = Color(0xFFC4552C);
  static const togetherText = Color(0xFF9A4120);
  static const togetherFill = Color(0xFFF28B60);
  static const togetherTint = Color(0xFFFFF4EE);
  static const togetherChip = Color(0xFFFFE6DA);
  static const togetherEmpty = Color(0xFFF6D3C2);

  /// 친구 동그라미 배경. 닉네임마다 돌아가며 쓴다.
  static const avatars = [soloTint, togetherChip, Color(0xFFEEEAFE), Color(0xFFE3EFFB), Color(0xFFFFF4D6)];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: JdColors.solo,
    primary: JdColors.solo,
    surface: Colors.white,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: JdColors.ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: JdColors.ink),
    ),
    cardTheme: CardThemeData(
      color: JdColors.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: rounded,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: rounded),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: JdColors.box, width: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: JdColors.panel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: JdColors.soloTint,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? JdColors.ink : JdColors.faint,
          )),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: JdColors.line, thickness: 1, space: 1),
  );
}
