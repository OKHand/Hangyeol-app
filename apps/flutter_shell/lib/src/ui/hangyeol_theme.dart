import 'package:flutter/material.dart';

const kHangyeolPrimary = Color(0xff1e6247);
const kHangyeolInk = Color(0xff19231d);
const kHangyeolMuted = Color(0xff6b7871);
const kHangyeolSubtle = Color(0xff98a49d);
const kHangyeolCanvas = Color(0xffffffff);
const kHangyeolSurface = Color(0xfff4f6f5);
const kHangyeolTint = Color(0xffe7efe9);
const kHangyeolDivider = Color(0xffeef1ef);
const kHangyeolBorder = Color(0xffe2e8e4);

/// 한결씨드 고유 녹색 팔레트를 유지하면서 플랫하고 정돈된 UI 톤을 구성하는 공통 테마.
ThemeData buildHangyeolTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kHangyeolPrimary,
    surface: kHangyeolCanvas,
    surfaceContainerLowest: kHangyeolCanvas,
    surfaceContainerLow: kHangyeolSurface,
    surfaceContainer: kHangyeolSurface,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: kHangyeolCanvas,
    canvasColor: kHangyeolCanvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: kHangyeolCanvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: kHangyeolInk,
      titleTextStyle: TextStyle(
        color: kHangyeolInk,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: kHangyeolInk, size: 22),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      elevation: 0,
      pressElevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kHangyeolPrimary : kHangyeolSurface,
      ),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? Colors.white : const Color(0xff425249),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: kHangyeolSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    dividerTheme: const DividerThemeData(
      color: kHangyeolDivider,
      thickness: 0.8,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kHangyeolSurface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xff929e97)),
      labelStyle: const TextStyle(fontSize: 13, color: kHangyeolMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kHangyeolPrimary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kHangyeolPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kHangyeolInk,
        backgroundColor: Colors.white,
        side: const BorderSide(color: kHangyeolBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kHangyeolPrimary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kHangyeolCanvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 58,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? kHangyeolPrimary : const Color(0xffa4afa9),
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? kHangyeolPrimary : const Color(0xff8e9a93),
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kHangyeolInk,
      textColor: kHangyeolInk,
      subtitleTextStyle: TextStyle(fontSize: 12, color: kHangyeolMuted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kHangyeolPrimary : const Color(0xffdde3df),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}

/// 독립 위젯 테스트를 포함해 일관된 캡슐형 필터 칩을 그리는 공용 헬퍼.
ChoiceChip hangyeolChoicePill({
  Key? key,
  required String label,
  required bool selected,
  required ValueChanged<bool>? onSelected,
  Color unselectedBackground = kHangyeolSurface,
  EdgeInsetsGeometry? labelPadding,
}) =>
    ChoiceChip(
      key: key,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      selectedColor: kHangyeolPrimary,
      backgroundColor: unselectedBackground,
      disabledColor: unselectedBackground,
      labelPadding: labelPadding ?? const EdgeInsets.symmetric(horizontal: 6),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : const Color(0xff425249),
      ),
      selected: selected,
      onSelected: onSelected,
    );
