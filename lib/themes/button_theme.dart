import 'package:flutter/material.dart';

import '../constants/styles.dart';

ElevatedButtonThemeData elevatedButtonThemeData = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
    elevation: 0,
    textStyle: const TextStyle(
      fontFamily: "Poppins",
      fontWeight: FontWeight.w700,
      fontSize: 15,
      letterSpacing: 0.2,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(defaultBorderRadius)),
    ),
  ),
);

OutlinedButtonThemeData outlinedButtonTheme({
  Color borderColor = blackColor10,
}) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      minimumSize: const Size(double.infinity, 48),
      side: BorderSide(width: 1.2, color: borderColor),
      foregroundColor: blackColor,
      textStyle: const TextStyle(
        fontFamily: "Poppins",
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(defaultBorderRadius)),
      ),
    ),
  );
}

final textButtonThemeData = TextButtonThemeData(
  style: TextButton.styleFrom(
    foregroundColor: primaryColor,
    textStyle: const TextStyle(
      fontFamily: "Poppins",
      fontWeight: FontWeight.w600,
      fontSize: 14,
      letterSpacing: 0.1,
    ),
  ),
);
