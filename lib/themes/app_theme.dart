import 'package:flutter/material.dart';

import '../constants/styles.dart';
import 'button_theme.dart';
import 'input_decoration_theme.dart';
import 'theme_data.dart';

extension XPadding on Widget {
  Padding paddingAll(double value) {
    return Padding(padding: EdgeInsets.all(value), child: this);
  }

  Padding paddingLeft(double value) {
    return Padding(
      padding: EdgeInsets.only(left: value),
      child: this,
    );
  }

  Padding paddingRight(double value) {
    return Padding(
      padding: EdgeInsets.only(right: value),
      child: this,
    );
  }

  Padding paddingBottom(double value) {
    return Padding(
      padding: EdgeInsets.only(bottom: value),
      child: this,
    );
  }

  Padding paddingTop(double value) {
    return Padding(
      padding: EdgeInsets.only(top: value),
      child: this,
    );
  }

  Padding paddingVertical(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: value),
      child: this,
    );
  }

  Padding paddingHorizontal(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: value),
      child: this,
    );
  }
}

class AppTheme {
  static ThemeData lightTheme(BuildContext context) {
    const secondaryBrand = Color(0xFF0EA5E9);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryBrand,
      surface: Colors.white,
      error: errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: "Poppins",
      colorScheme: colorScheme,
      primarySwatch: primaryMaterialColor,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF3F6FC),
      iconTheme: const IconThemeData(color: blackColor),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: blackColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(color: blackColor80, height: 1.35),
        bodyMedium: TextStyle(color: blackColor60),
      ),
      dividerColor: blackColor10,
      cardColor: Colors.white,
      elevatedButtonTheme: elevatedButtonThemeData,
      textButtonTheme: textButtonThemeData,
      outlinedButtonTheme: outlinedButtonTheme(),
      inputDecorationTheme: lightInputDecorationTheme,
      appBarTheme: appBarLightTheme,
      scrollbarTheme: scrollbarThemeData,
      dataTableTheme: dataTableLightThemeData,
    );
  }

  // Dark theme is inclided in the Full template
}
