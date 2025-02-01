import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: Color(0xFFDB2777),
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'System',
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Color(0xFFDB2777),
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFFDB2777),
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFFDB2777),
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFDB2777),
        foregroundColor: Colors.white,
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}

