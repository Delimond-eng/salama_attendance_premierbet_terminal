import '/themes/app_theme.dart';
import 'package:flutter/material.dart';

import '../constants/styles.dart';
import 'svg.dart';

class HomeMenuBtn extends StatelessWidget {
  final String title;
  final String icon;
  final VoidCallback? onPress;

  const HomeMenuBtn({
    super.key,
    required this.title,
    required this.icon,
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final btnSize = (screen.width - 60) / 2;

    return Container(
      height: btnSize,
      width: btnSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryMaterialColor,
            primaryMaterialColor.shade400,
          ], // orange dégradé
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onPress!,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Svg(
                path: "$icon.svg",
                size: btnSize * 0.35, // Taille de l'icône responsive
                color: primaryMaterialColor.shade50,
              ).paddingBottom(10.0),
              Text(
                title,
                style: TextStyle(
                  color: lightGreyColor,
                  fontFamily: 'Staatliches',
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  fontSize: btnSize * 0.12, // Taille du texte responsive
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
