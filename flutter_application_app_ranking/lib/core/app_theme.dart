import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────
// Paleta de Cores Compartilhada
// ──────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF121212);
  static const Color card = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color primary = Color(0xFF00E676);
  static const Color primaryLight = Color(0xFF1DB954);
  static const Color error = Colors.redAccent;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color textDisabled = Colors.white38;
  static const Color border = Colors.white10;
  static const Color borderLight = Colors.white24;
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
    foregroundColor: Colors.black,
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
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primary,
      surface: AppColors.card,
    ),
  );
}
