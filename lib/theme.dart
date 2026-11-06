import 'package:flutter/material.dart';

import 'widgets/pixel_ui.dart';

/// 저두잇 색. 도트 방 그림에 맞춰 종이색 바탕에 나무색·남색을 쓴다.
/// 혼자 미션은 초록, 친구 챌린지는 주황으로 구분한다.
/// 글자·아이콘이 올라가는 진한 색은 바탕과 4.5:1 이상 대비가 나도록 골랐다.
abstract final class JdColors {
  static const ink = Color(0xFF26231F);
  static const subtle = Color(0xFF5E5A52);
  static const faint = Color(0xFF6A665E);
  static const line = Color(0xFFE9E2D4);

  /// 바탕 종이색과 그보다 한 톤 짙은 판.
  static const paper = Color(0xFFFAF6EE);
  static const paperDeep = Color(0xFFF2ECE0);

  /// 판 안의 구분선과 테두리.
  static const seam = Color(0xFFE4DBCA);
  static const seamDark = Color(0xFFCBBFA8);

  /// 방 그림의 나무 바닥색. 글자용은 대비를 맞춘 짙은 색.
  static const wood = Color(0xFFC98B4F);
  static const woodLight = Color(0xFFF0D6AE);
  static const woodText = Color(0xFF8A5424);

  /// 다 한 미션 체크.
  static const leaf = Color(0xFF4F9A6E);
  static const leafDeep = Color(0xFF2F7350);

  /// 방 카드 남색.
  static const roomNavy = Color(0xFF22344A);
  static const roomNavyDeep = Color(0xFF172534);
  static const cream = Color(0xFFFFF8EA);
  static const empty = Color(0xFFF1F2F4);
  static const box = Color(0xFFCDD2D7);
  static const panel = Color(0xFFF2ECE0);

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
    surface: JdColors.paper,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: JdColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: JdColors.paper,
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
      backgroundColor: JdColors.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: JdColors.woodLight,
      indicatorShape: const PixelBorder(step: 3, steps: 2),
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
