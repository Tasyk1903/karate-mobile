import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const red = Color(0xFFAD2B2D);
  static const redDark = Color(0xFF8F171C);
  static const ink = Color(0xFF111827);
  static const textMuted = Color(0xFF646E7D);
  static const border = Color(0xFFE6E8ED);
  static const field = Color(0xFFFFFFFF);
  static const page = Color(0xFFF8F8F9);

  static const darkInk = Color(0xFFF8FAFC);
  static const darkTextMuted = Color(0xFFABB4C2);
  static const darkBorder = Color(0xFF263142);
  static const darkField = Color(0xFF111827);
  static const darkPage = Color(0xFF07090D);

  static Color accentFor(BuildContext context) =>
      isDark(context) ? const Color(0xFFFF8C8D) : red;
  static Color inkFor(BuildContext context) => isDark(context) ? darkInk : ink;
  static Color mutedFor(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;
  static Color borderFor(BuildContext context) =>
      isDark(context) ? darkBorder : border;
  static Color surfaceFor(BuildContext context) =>
      isDark(context) ? darkField : field;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageFor(BuildContext context) =>
      isDark(context) ? darkPage : page;

  static Color backgroundOverlay(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.46)
      : Colors.white.withValues(alpha: 0.72);

  static String backgroundImage(BuildContext context) => isDark(context)
      ? 'assets/images/back-night.png'
      : 'assets/images/back-white.jpg';
}
