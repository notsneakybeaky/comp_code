import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF10151B);
  static const bar = Color(0xFF0C1015);
  static const line = Color(0xFF1F2731);
  static const text = Color(0xFFD3DAE3);
  static const dim = Color(0xFF56616D);
  static const folder = Color(0xFF7AA2F7);
  static const approach = Color(0xFF9ECE6A);
  static const accent = Color(0xFFFF9E64);
  static const selection = Color(0xFF1A2430);

  /// Tree guide lines: a step brighter than [line] so they read as structure.
  static const guide = Color(0xFF34404D);

  /// Secondary prose, between [text] and [dim].
  static const muted = Color(0xFF8C97A4);
  static const bright = Color(0xFFF1F4F8);
  static const danger = Color(0xFFF7768E);
  static const call = Color(0xFF7DCFFF);
}

abstract final class AppFonts {
  static const mono = 'Cascadia Mono';
  static const monoFallback = ['Consolas', 'Courier New', 'monospace'];
  static const sans = 'Segoe UI';
  static const sansFallback = ['Segoe UI Variable', 'Helvetica Neue', 'Arial', 'sans-serif'];
}

TextStyle mono(double size, {Color color = AppColors.text, FontWeight? weight, double? height, double? spacing}) =>
    TextStyle(
      fontFamily: AppFonts.mono,
      fontFamilyFallback: AppFonts.monoFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing ?? 0.25,
    );

TextStyle sans(double size, {Color color = AppColors.text, FontWeight? weight, double? height}) =>
    TextStyle(
      fontFamily: AppFonts.sans,
      fontFamilyFallback: AppFonts.sansFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: 0.15,
    );

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.approach,
      surface: AppColors.background,
      onSurface: AppColors.text,
      outline: AppColors.line,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.3),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(AppColors.guide.withValues(alpha: 0.9)),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: mono(12, color: AppColors.text),
    ),
  );
  return base;
}

/// Width of [text] laid out on one line, as a Text widget in [context] would draw it.
double measureText(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
