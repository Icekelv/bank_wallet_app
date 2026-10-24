import 'package:flutter/material.dart';

/// The two looks: a light, ink-on-paper bank and a dark wallet.
/// Colour is kept for meaning only (gains and losses).
class Palette {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color muted;
  final Color heroBg; // big balance card
  final Color heroInk;
  final Color heroMuted;
  final Color up;
  final Color down;
  final Color upBg;
  final Color downBg;
  final Color heroUp;

  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.muted,
    required this.heroBg,
    required this.heroInk,
    required this.heroMuted,
    required this.up,
    required this.down,
    required this.upBg,
    required this.downBg,
    required this.heroUp,
  });

  static const bank = Palette(
    bg: Color(0xFFF4F4F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F1EE),
    border: Color(0xFFE2E2DD),
    ink: Color(0xFF111111),
    muted: Color(0xFF5F5F5A),
    heroBg: Color(0xFF111111),
    heroInk: Color(0xFFFFFFFF),
    heroMuted: Color(0xFFA3A39E),
    up: Color(0xFF2F7A55),
    down: Color(0xFFB3412E),
    upBg: Color(0xFFE7F3EC),
    downBg: Color(0xFFFBE9E5),
    heroUp: Color(0xFF8FD9B0),
  );

  static const wallet = Palette(
    bg: Color(0xFF0D0D0E),
    surface: Color(0xFF18181A),
    surfaceAlt: Color(0xFF2A2A2C),
    border: Color(0xFF262628),
    ink: Color(0xFFF2F2EF),
    muted: Color(0xFF8E8E89),
    heroBg: Color(0xFF18181A),
    heroInk: Color(0xFFF2F2EF),
    heroMuted: Color(0xFF8E8E89),
    up: Color(0xFF6FD39B),
    down: Color(0xFFF0907F),
    upBg: Color(0xFF15241C),
    downBg: Color(0xFF2A1714),
    heroUp: Color(0xFF6FD39B),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? wallet : bank;
}

ThemeData buildTheme(bool wallet) {
  final p = wallet ? Palette.wallet : Palette.bank;
  final scheme = ColorScheme(
    brightness: wallet ? Brightness.dark : Brightness.light,
    primary: p.ink,
    onPrimary: p.bg,
    secondary: p.ink,
    onSecondary: p.bg,
    error: p.down,
    onError: p.bg,
    surface: p.surface,
    onSurface: p.ink,
  );
  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.border,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w600),
    ),
    textTheme: Typography.material2021().englishLike.apply(bodyColor: p.ink, displayColor: p.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.muted),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.ink, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.down)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.ink,
        foregroundColor: p.bg,
        disabledBackgroundColor: p.surfaceAlt,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.border),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.ink)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.bg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.ink),
  );
}
