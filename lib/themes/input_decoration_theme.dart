import 'package:flutter/material.dart';

import '../constants/styles.dart';

const InputDecorationTheme lightInputDecorationTheme = InputDecorationTheme(
  fillColor: Color(0xFFF7F9FE),
  filled: true,
  hintStyle: TextStyle(color: blackColor60, fontSize: 14.0, height: 1.2),
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  labelStyle: TextStyle(color: blackColor80, fontWeight: FontWeight.w500),
  border: outlineInputBorder,
  enabledBorder: outlineInputBorder,
  focusedBorder: focusedOutlineInputBorder,
  errorBorder: errorOutlineInputBorder,
);

const InputDecorationTheme darkInputDecorationTheme = InputDecorationTheme(
  fillColor: darkGreyColor,
  filled: true,
  hintStyle: TextStyle(color: whiteColor40, fontSize: 14.0),
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: outlineInputBorder,
  enabledBorder: outlineInputBorder,
  focusedBorder: focusedOutlineInputBorder,
  errorBorder: errorOutlineInputBorder,
);

const OutlineInputBorder outlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(defaultBorderRadius + 2)),
  borderSide: BorderSide(color: greyColor80),
);

const OutlineInputBorder focusedOutlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(defaultBorderRadius + 2)),
  borderSide: BorderSide(color: primaryColor, width: 1.3),
);

const OutlineInputBorder errorOutlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(defaultBorderRadius + 2)),
  borderSide: BorderSide(color: errorColor),
);

OutlineInputBorder secondaryOutlineInputBorder(BuildContext context) {
  return OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(defaultBorderRadius)),
    borderSide: BorderSide(
      color: Theme.of(
        context,
      ).textTheme.bodyLarge!.color!.withValues(alpha: 0.15),
    ),
  );
}
