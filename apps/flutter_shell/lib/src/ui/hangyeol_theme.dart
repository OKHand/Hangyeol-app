import 'package:flutter/material.dart';

const kHangyeolPrimary = Color(0xff1e6247);
const kHangyeolInk = Color(0xff141e18);
const kHangyeolMuted = Color(0xff48574e);
const kHangyeolSubtle = Color(0xff68776e);
const kHangyeolCanvas = Color(0xffffffff);
const kHangyeolSurface = Color(0xffeef3f0);
const kHangyeolChipUnselected = Color(0xffe8efeb);
const kHangyeolChipBorder = Color(0xffc9d7cf);
const kHangyeolTint = Color(0xffdfece3);
const kHangyeolDivider = Color(0xffe6ece8);
const kHangyeolBorder = Color(0xffd2ddd6);

/// 한결씨드 고유 녹색 팔레트를 유지하면서 시인성이 높고 정돈된 플랫 UI 톤을 구성하는 공통 테마.
ThemeData buildHangyeolTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kHangyeolPrimary,
    surface: kHangyeolCanvas,
    onSurface: kHangyeolInk,
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
    chipTheme: const ChipThemeData(
      showCheckmark: false,
      shape: StadiumBorder(),
      side: BorderSide(color: kHangyeolChipBorder),
      elevation: 0,
      pressElevation: 0,
      backgroundColor: kHangyeolChipUnselected,
      disabledColor: kHangyeolSurface,
      selectedColor: kHangyeolPrimary,
      secondarySelectedColor: kHangyeolPrimary,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      labelPadding: EdgeInsets.symmetric(horizontal: 2),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kHangyeolInk,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white,
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
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xff5f6f65)),
      labelStyle: const TextStyle(fontSize: 13, color: kHangyeolMuted, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kHangyeolBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kHangyeolBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kHangyeolPrimary, width: 1.5),
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
        side: const BorderSide(color: kHangyeolChipBorder),
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
          color: states.contains(WidgetState.selected) ? kHangyeolPrimary : const Color(0xff7f8d85),
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? kHangyeolPrimary : const Color(0xff68776e),
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
        (states) => states.contains(WidgetState.selected) ? kHangyeolPrimary : const Color(0xffcbd5cf),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}

/// 독립 위젯 테스트를 포함해 시인성 높은 캡슐형 필터 칩을 그리는 공용 헬퍼.
ChoiceChip hangyeolChoicePill({
  Key? key,
  required String label,
  required bool selected,
  required ValueChanged<bool>? onSelected,
  Color unselectedBackground = kHangyeolChipUnselected,
  EdgeInsetsGeometry? padding,
  EdgeInsetsGeometry? labelPadding,
  VisualDensity? visualDensity,
}) =>
    ChoiceChip(
      key: key,
      showCheckmark: false,
      visualDensity: visualDensity ?? VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
      side: BorderSide(color: selected ? kHangyeolPrimary : kHangyeolChipBorder),
      selectedColor: kHangyeolPrimary,
      backgroundColor: unselectedBackground,
      disabledColor: unselectedBackground,
      padding: padding,
      labelPadding: labelPadding ?? const EdgeInsets.symmetric(horizontal: 6),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? Colors.white : kHangyeolInk,
        ),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? Colors.white : kHangyeolInk,
      ),
      selected: selected,
      onSelected: onSelected,
    );
