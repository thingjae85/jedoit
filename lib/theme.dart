import 'package:flutter/material.dart';

import 'widgets/pixel_ui.dart';

/// 화면 스킨. 마이 탭에서 고르고 기기에 저장한다.
enum JdSkin {
  /// 기본: 종이색 바탕에 나무색.
  wood('나무', '기본 스킨'),

  /// 바다: 물빛 바탕, 상어와 물고기 그림, 물이 출렁이는 진행도와 버튼.
  ocean('바다 상어', '물이 출렁이는 바다 스킨');

  const JdSkin(this.label, this.description);
  final String label;
  final String description;

  static JdSkin fromName(String? name) =>
      JdSkin.values.firstWhere((s) => s.name == name, orElse: () => JdSkin.wood);
}

/// 스킨 하나의 색 묶음. 이름은 기본 스킨 기준으로 지었다 (바다 스킨의 wood는 물빛 강조색).
class JdPalette {
  const JdPalette({
    required this.ink,
    required this.subtle,
    required this.faint,
    required this.line,
    required this.paper,
    required this.paperDeep,
    required this.seam,
    required this.seamDark,
    required this.wood,
    required this.woodLight,
    required this.woodText,
    required this.leaf,
    required this.leafDeep,
    required this.roomNavy,
    required this.roomNavyDeep,
    required this.cream,
    required this.outline,
    required this.edge,
    required this.edgeStrong,
    required this.woodDeep,
    required this.leafLip,
    required this.creamLip,
    required this.empty,
    required this.box,
    required this.panel,
    required this.solo,
    required this.soloText,
    required this.soloTint,
    required this.soloMid,
    required this.together,
    required this.togetherText,
    required this.togetherFill,
    required this.togetherTint,
    required this.togetherChip,
    required this.togetherEmpty,
  });

  final Color ink;
  final Color subtle;
  final Color faint;
  final Color line;
  final Color paper;
  final Color paperDeep;
  final Color seam;
  final Color seamDark;
  final Color wood;
  final Color woodLight;
  final Color woodText;
  final Color leaf;
  final Color leafDeep;
  final Color roomNavy;
  final Color roomNavyDeep;
  final Color cream;
  final Color outline;
  final Color edge;
  final Color edgeStrong;
  final Color woodDeep;
  final Color leafLip;
  final Color creamLip;
  final Color empty;
  final Color box;
  final Color panel;
  final Color solo;
  final Color soloText;
  final Color soloTint;
  final Color soloMid;
  final Color together;
  final Color togetherText;
  final Color togetherFill;
  final Color togetherTint;
  final Color togetherChip;
  final Color togetherEmpty;

  /// 기본 나무 스킨.
  static const woodSkin = JdPalette(
    ink: Color(0xFF26231F),
    subtle: Color(0xFF5E5A52),
    faint: Color(0xFF6A665E),
    line: Color(0xFFE9E2D4),
    paper: Color(0xFFFAF6EE),
    paperDeep: Color(0xFFF2ECE0),
    seam: Color(0xFFE4DBCA),
    seamDark: Color(0xFFCBBFA8),
    wood: Color(0xFFC98B4F),
    woodLight: Color(0xFFF0D6AE),
    woodText: Color(0xFF8A5424),
    leaf: Color(0xFF4F9A6E),
    leafDeep: Color(0xFF2F7350),
    roomNavy: Color(0xFF22344A),
    roomNavyDeep: Color(0xFF172534),
    cream: Color(0xFFFFF8EA),
    outline: Color(0xFF4A3527),
    edge: Color(0xFFE0D2BC),
    edgeStrong: Color(0xFFC9B08F),
    woodDeep: Color(0xFFA2693A),
    leafLip: Color(0xFF2B6847),
    creamLip: Color(0xFFE2CFAE),
    empty: Color(0xFFF1F2F4),
    box: Color(0xFFCDD2D7),
    panel: Color(0xFFF2ECE0),
    solo: Color(0xFF2E8566),
    soloText: Color(0xFF1F6B52),
    soloTint: Color(0xFFE3F4EC),
    soloMid: Color(0xFFBFE3D2),
    together: Color(0xFFC4552C),
    togetherText: Color(0xFF9A4120),
    togetherFill: Color(0xFFF28B60),
    togetherTint: Color(0xFFFFF4EE),
    togetherChip: Color(0xFFFFE6DA),
    togetherEmpty: Color(0xFFF6D3C2),
  );

  /// 바다 상어 스킨. 글자색은 물빛 바탕과 4.5:1 이상 대비.
  static const oceanSkin = JdPalette(
    ink: Color(0xFF12303D),
    subtle: Color(0xFF41606B),
    faint: Color(0xFF4C6B75),
    line: Color(0xFFD2E9EE),
    paper: Color(0xFFEAF6F8),
    paperDeep: Color(0xFFDAEEF2),
    seam: Color(0xFFC9E3EA),
    seamDark: Color(0xFF9CC9D4),
    wood: Color(0xFF3C98B2),
    woodLight: Color(0xFFCDEBF1),
    woodText: Color(0xFF1D6A86),
    leaf: Color(0xFF2D8CB0),
    leafDeep: Color(0xFF1F6E8E),
    roomNavy: Color(0xFF22344A),
    roomNavyDeep: Color(0xFF172534),
    cream: Color(0xFFF6FCFD),
    outline: Color(0xFF163C4A),
    edge: Color(0xFFBFE0E7),
    edgeStrong: Color(0xFF7DBACA),
    woodDeep: Color(0xFF155470),
    leafLip: Color(0xFF185A75),
    creamLip: Color(0xFFC3E2E9),
    empty: Color(0xFFF1F2F4),
    box: Color(0xFFCDD2D7),
    panel: Color(0xFFDAEEF2),
    solo: Color(0xFF2A7FA0),
    soloText: Color(0xFF1D6A86),
    soloTint: Color(0xFFE1F2F7),
    soloMid: Color(0xFFB9DFEA),
    together: Color(0xFF2F7DB5),
    togetherText: Color(0xFF1F5F8F),
    togetherFill: Color(0xFF5AA6D6),
    togetherTint: Color(0xFFEEF6FC),
    togetherChip: Color(0xFFDCEDF9),
    togetherEmpty: Color(0xFFC6E0F2),
  );
}

/// 저두잇 색. 도트 방 그림에 맞춰 종이색 바탕에 나무색·남색을 쓴다.
/// 혼자 미션은 초록, 친구 챌린지는 주황으로 구분한다.
/// 글자·아이콘이 올라가는 진한 색은 바탕과 4.5:1 이상 대비가 나도록 골랐다.
/// 지금 고른 스킨의 색을 돌려준다. 스킨을 바꾸면 [JdSkinScope]가 화면 전체를 다시 그린다.
abstract final class JdColors {
  static JdSkin _skin = JdSkin.wood;
  static JdPalette _p = JdPalette.woodSkin;

  static JdSkin get skin => _skin;
  static bool get ocean => _skin == JdSkin.ocean;

  /// 색 묶음만 바꾼다. 화면을 다시 그리는 일은 [JdSkinScope]가 한다.
  static void use(JdSkin skin) {
    _skin = skin;
    _p = switch (skin) { JdSkin.wood => JdPalette.woodSkin, JdSkin.ocean => JdPalette.oceanSkin };
  }

  static Color get ink => _p.ink;
  static Color get subtle => _p.subtle;
  static Color get faint => _p.faint;
  static Color get line => _p.line;

  /// 바탕 종이색과 그보다 한 톤 짙은 판.
  static Color get paper => _p.paper;
  static Color get paperDeep => _p.paperDeep;

  /// 판 안의 구분선과 테두리.
  static Color get seam => _p.seam;
  static Color get seamDark => _p.seamDark;

  /// 방 그림의 나무 바닥색. 글자용은 대비를 맞춘 짙은 색.
  static Color get wood => _p.wood;
  static Color get woodLight => _p.woodLight;
  static Color get woodText => _p.woodText;

  /// 다 한 미션 체크.
  static Color get leaf => _p.leaf;
  static Color get leafDeep => _p.leafDeep;

  /// 방 카드 남색.
  static Color get roomNavy => _p.roomNavy;
  static Color get roomNavyDeep => _p.roomNavyDeep;
  static Color get cream => _p.cream;

  /// 짙은 갈색. 버튼 글자·도트 그림 선에 쓴다 (테두리에는 쓰지 않는다).
  static Color get outline => _p.outline;

  /// 판(카드)·입력 칸 테두리. 바탕과 살짝만 구분되는 옅은 나무색.
  static Color get edge => _p.edge;

  /// 버튼·고른 칸 테두리. 판보다 한 톤 짙게.
  static Color get edgeStrong => _p.edgeStrong;

  /// 버튼 아래 두께(눌리는 턱) 색.
  static Color get woodDeep => _p.woodDeep;
  static Color get leafLip => _p.leafLip;
  static Color get creamLip => _p.creamLip;
  static Color get empty => _p.empty;
  static Color get box => _p.box;
  static Color get panel => _p.panel;
  static Color get solo => _p.solo;
  static Color get soloText => _p.soloText;
  static Color get soloTint => _p.soloTint;
  static Color get soloMid => _p.soloMid;
  static Color get together => _p.together;
  static Color get togetherText => _p.togetherText;
  static Color get togetherFill => _p.togetherFill;
  static Color get togetherTint => _p.togetherTint;
  static Color get togetherChip => _p.togetherChip;
  static Color get togetherEmpty => _p.togetherEmpty;

  /// 친구 동그라미 배경. 닉네임마다 돌아가며 쓴다.
  static List<Color> get avatars => ocean
      ? const [Color(0xFFE1F2F7), Color(0xFFDCEDF9), Color(0xFFE4EAFB), Color(0xFFD9F0EE), Color(0xFFE8F4FA)]
      : [soloTint, togetherChip, const Color(0xFFEEEAFE), const Color(0xFFE3EFFB), const Color(0xFFFFF4D6)];
}

/// 모든 화면이 같은 모양을 쓰도록 정한 판·버튼 모양.
/// - 묶음 판(카드): 크림색 바탕에 짙은 갈색 2px 테두리, 계단 모서리.
/// - 채운 버튼: 같은 테두리에 아래 턱이 있는 키캡 모양.
/// - 입력 칸·칩·보조 버튼: 얇은 테두리의 작은 계단 모서리.
abstract final class JdShapes {
  static PixelBorder get card => PixelBorder(step: 3, steps: 2, side: BorderSide(color: JdColors.edge, width: 1.5));
  static PixelBorder get key => PixelBorder(step: 3, steps: 2, lip: 4, side: BorderSide(color: JdColors.edgeStrong, width: 1.5));
  static PixelBorder get keySmall => PixelBorder(step: 2, steps: 2, lip: 3, side: BorderSide(color: JdColors.edgeStrong, width: 1.5));
  static PixelBorder get chip => PixelBorder(step: 2, steps: 1, side: BorderSide(color: JdColors.edge, width: 1.5));
  static PixelBorder get chipOn => PixelBorder(step: 2, steps: 1, side: BorderSide(color: JdColors.edgeStrong, width: 1.5));

  /// 판 안의 작은 판·사진 틀: 얇은 테두리.
  static PixelBorder get soft => PixelBorder(step: 3, steps: 2, side: BorderSide(color: JdColors.seam, width: 1.5));

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
    appBarTheme: AppBarTheme(
      backgroundColor: JdColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: JdColors.ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: kGameFont, fontSize: 18, fontWeight: FontWeight.w800, color: JdColors.ink),
    ),
    cardTheme: CardThemeData(
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
        shape: WidgetStatePropertyAll(JdShapes.key),
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
        shape: WidgetStatePropertyAll(JdShapes.keySmall),
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
        side: WidgetStatePropertyAll(BorderSide(color: JdColors.edgeStrong, width: 1.5)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? JdColors.woodLight : JdColors.cream),
        foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? JdColors.outline : JdColors.subtle),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: kGameFont, fontSize: 14, fontWeight: FontWeight.w700)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      ),
    ),
    chipTheme: ChipThemeData(
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
      side: BorderSide(color: JdColors.edgeStrong, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? JdColors.leaf : Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: JdColors.cream,
      labelStyle: TextStyle(color: JdColors.subtle),
      floatingLabelStyle: TextStyle(color: JdColors.woodText, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: JdColors.edge, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: JdColors.edge, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: JdColors.woodText, width: 1.5)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: JdColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: JdShapes.card,
      titleTextStyle: TextStyle(fontFamily: kGameFont, fontSize: 18, fontWeight: FontWeight.w800, color: JdColors.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: JdColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: JdShapes.card,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: JdColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: JdShapes.card,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: JdColors.wood, linearTrackColor: JdColors.paperDeep),
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
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: JdColors.roomNavyDeep,
      shape: const PixelBorder(step: 3, steps: 2),
      contentTextStyle: TextStyle(fontFamily: kAppFont, fontSize: 14, color: JdColors.cream),
      actionTextColor: JdColors.woodLight,
    ),
    dividerTheme: DividerThemeData(color: JdColors.seam, thickness: 1, space: 1),
  );
}
