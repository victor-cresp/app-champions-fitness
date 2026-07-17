import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────
// Paleta de Cores Compartilhada
// ──────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Platina & Grafite: identidade metálica inspirada diretamente na logo.
  static const Color background = Color(0xFF101419);
  static const Color backgroundElevated = Color(0xFF151A20);
  static const Color card = Color(0xFF1A2026);
  static const Color surface = Color(0xFF252C33);

  static const Color primary = Color(0xFFDCE1E5);
  static const Color primaryLight = Color(0xFFF4F6F8);
  static const Color secondary = Color(0xFFAAB2BA);
  static const Color accent = Color(0xFFC3C9CE);

  // Nomes semânticos usados na apresentação do plano PRO.
  static const Color proPlatinum = primary;
  static const Color proSilver = secondary;
  static const Color proSteel = Color(0xFF737E89);
  static const Color proGunmetal = surface;
  static const Color proCharcoal = background;
  static const Color proOnPrimary = Color(0xFF11151A);

  static const Color success = Color(0xFF3CCB8E);
  static const Color warning = Color(0xFFF2B84B);
  static const Color info = Color(0xFF6EA8FE);
  static const Color error = Color(0xFFFF6B6B);

  static const Color onPrimary = Color(0xFF11151A);
  static const Color textPrimary = Color(0xFFF1F3F5);
  static const Color textSecondary = Color(0xFFC1C7CD);
  static const Color textMuted = Color(0xFF8F98A1);
  static const Color textDisabled = Color(0xFF626B74);
  static const Color border = Color(0xFF343C44);
  static const Color borderLight = Color(0xFF4D5761);
}

// ──────────────────────────────────────────────────────────
// Estilos de Input Compartilhados
// ──────────────────────────────────────────────────────────
InputDecoration buildInputDecoration({
  required String label,
  required IconData icon,
  String? hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    hintStyle: const TextStyle(color: Colors.white24),
    labelStyle: const TextStyle(color: AppColors.textMuted),
    prefixIcon: Icon(icon, color: AppColors.primary),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}

// ──────────────────────────────────────────────────────────
// Estilos de Botão Compartilhados
// ──────────────────────────────────────────────────────────
ButtonStyle primaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  );
}

// ──────────────────────────────────────────────────────────
// Tema Escuro Padrão
// ──────────────────────────────────────────────────────────
ThemeData get darkTheme {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      surface: AppColors.card,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textDisabled,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle()),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: Color(0x66DCE1E5),
      selectionHandleColor: AppColors.primary,
    ),
  );
}
