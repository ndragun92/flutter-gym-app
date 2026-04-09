import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.light,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  static ThemeData dark() {
    // Zinc/Slate inspired palette
    const background = Color(0xFF18181B); // zinc-900
    const surface = Color(0xFF27272A); // zinc-800
    const card = Color(0xFF27272A); // zinc-800
    const primary = Color(0xFF818CF8); // indigo-400 for accent
    const onPrimary = Color(0xFF18181B);
    const text = Color(0xFFE4E4E7); // zinc-200
    const secondaryText = Color(0xFFA1A1AA); // zinc-400

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        background: background,
        surface: surface,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondaryText,
        onBackground: text,
        onSurface: text,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: secondaryText),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: secondaryText),
        ),
        hintStyle: TextStyle(color: secondaryText),
        labelStyle: TextStyle(color: text),
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      iconTheme: base.iconTheme.copyWith(color: text),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surface,
        iconTheme: base.iconTheme.copyWith(color: text),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: text),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(TextStyle(color: text)),
        iconTheme: MaterialStateProperty.all(IconThemeData(color: text)),
      ),
    );
  }
}
