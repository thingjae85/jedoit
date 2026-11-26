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

  /// 짙은 갈색. 버튼 글자·도트 그림 선에 쓴다 (테두리에는 쓰지 않는다).
  static const outline = Color(0xFF4A3527);

  /// 판(카드)·입력 칸 테두리. 바탕과 살짝만 구분되는 옅은 나무색.
  static const edge = Color(0xFFE0D2BC);

  /// 버튼·고른 칸 테두리. 판보다 한 톤 짙게.
  static const edgeStrong = Color(0xFFC9B08F);

  /// 버튼 아래 두께(눌리는 턱) 색.
  static const woodDeep = Color(0xFFA2693A);
  static const leafLip = Color(0xFF2B6847);
  static const creamLip = Color(0xFFE2CFAE);
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

/// 모든 화면이 같은 모양을 쓰도록 정한 판·버튼 모양.
/// - 묶음 판(카드): 크림색 바탕에 짙은 갈색 2px 테두리, 계단 모서리.
/// - 채운 버튼: 같은 테두리에 아래 턱이 있는 키캡 모양.
/// - 입력 칸·칩·보조 버튼: 얇은 테두리의 작은 계단 모서리.
abstract final class JdShapes {
  static const card = PixelBorder(step: 3, steps: 2, side: BorderSide(color: JdColors.edge, width: 1.5));
  static const key = PixelBorder(step: 3, steps: 2, lip: 4, side: BorderSide(color: JdColors.edgeStrong, width: 1.5));
  static const keySmall = PixelBorder(step: 2, steps: 2, lip: 3, side: BorderSide(color: JdColors.edgeStrong, width: 1.5));
  static const chip = PixelBorder(step: 2, steps: 1, side: BorderSide(color: JdColors.edge, width: 1.5));
  static const chipOn = PixelBorder(step: 2, steps: 1, side: BorderSide(color: JdColors.edgeStrong, width: 1.5));

  /// 판 안의 작은 판·사진 틀: 얇은 테두리.
  static const soft = PixelBorder(step: 3, steps: 2, side: BorderSide(color: JdColors.seam, width: 1.5));

  /// 테두리 없는 작은 이름표·배지.
  static const tag = PixelBorder(step: 2, steps: 1);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: JdColors.wood,
    primary: JdColors.woodText,
    onPrimary: Colors.white,
    secondary: JdColors.solo,
    secondaryContainer: JdColors.woodLight,
    onSecondaryContainer: JdColors.outline,
    surface: JdColors.paper,
    surfaceContainerHighest: JdColors.paperDeep,
    outline: JdColors.seamDark,
    error: const Color(0xFFB3261E),
  );
  const gameText = TextStyle(fontFamily: kGameFont, fontSize: 16, fontWeight: FontWeight.w800);
  final disabledFill = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.disabled) ? JdColors.paperDeep : null);
  return ThemeData(
    useMaterial3: true,
    fontFamily: kAppFont,
    colorScheme: scheme,
    scaffoldBackgroundColor: JdColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: JdColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: JdColors.ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: kGameFont, fontSize: 18, fontWeight: FontWeight.w800, color: JdColors.ink),
    ),
    cardTheme: const CardThemeData(
      color: JdColors.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: JdShapes.card,
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(54)),
        shape: const WidgetStatePropertyAll(JdShapes.key),
        textStyle: const WidgetStatePropertyAll(gameText),
        backgroundColor: disabledFill,
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.disabled) ? JdColors.faint : null),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.disabled) ? JdColors.edge : JdColors.edgeStrong, width: 1.5)),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        shape: const WidgetStatePropertyAll(JdShapes.keySmall),
        backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? JdColors.paperDeep : JdColors.cream),
        foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? JdColors.faint : JdColors.outline),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.disabled) ? JdColors.edge : JdColors.edgeStrong, width: 1.5)),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: kGameFont, fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: JdColors.woodText,
        shape: const PixelBorder(step: 2, steps: 1),
        textStyle: const TextStyle(fontFamily: kGameFont, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(PixelBorder(step: 2, steps: 2))),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(PixelBorder(step: 2, steps: 2)),
        side: const WidgetStatePropertyAll(BorderSide(color: JdColors.edgeStrong, width: 1.5)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? JdColors.woodLight : JdColors.cream),
        foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? JdColors.outline : JdColors.subtle),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: kGameFont, fontSize: 14, fontWeight: FontWeight.w700)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: JdColors.cream,
      selectedColor: JdColors.woodLight,
      disabledColor: JdColors.paperDeep,
      shape: JdShapes.chip,
      side: BorderSide(color: JdColors.edge, width: 1.5),
      labelStyle: TextStyle(fontFamily: kAppFont, fontSize: 14, fontWeight: FontWeight.w600, color: JdColors.ink),
      iconTheme: IconThemeData(color: JdColors.woodText, size: 18),
      showCheckmark: false,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? JdColors.woodText : JdColors.seamDark),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const PixelBorder(step: 2, steps: 1),
      side: const BorderSide(color: JdColors.edgeStrong, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? JdColors.leaf : Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: JdColors.cream,
      labelStyle: const TextStyle(color: JdColors.subtle),
      floatingLabelStyle: const TextStyle(color: JdColors.woodText, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: JdColors.edge, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: JdColors.edge, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: JdColors.woodText, width: 1.5)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: JdColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: JdShapes.card,
      titleTextStyle: TextStyle(fontFamily: kGameFont, fontSize: 18, fontWeight: FontWeight.w800, color: JdColors.ink),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: JdColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: JdShapes.card,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: JdColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: JdShapes.card,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: JdColors.wood, linearTrackColor: JdColors.paperDeep),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: JdColors.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: JdColors.woodLight,
      indicatorShape: const PixelBorder(step: 3, steps: 2),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: kGameFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected) ? JdColors.ink : JdColors.faint,
          )),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: JdColors.roomNavyDeep,
      shape: PixelBorder(step: 3, steps: 2),
      contentTextStyle: TextStyle(fontFamily: kAppFont, fontSize: 14, color: JdColors.cream),
      actionTextColor: JdColors.woodLight,
    ),
    dividerTheme: const DividerThemeData(color: JdColors.seam, thickness: 1, space: 1),
  );
}
