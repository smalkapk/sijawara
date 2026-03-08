import 'package:flutter/material.dart';

import '../theme.dart';

class AppLogo extends StatelessWidget {
  static const String assetPath = 'server/assets/logosmalka.png';

  final double width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final BorderRadiusGeometry borderRadius;
  final bool showShadow;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width = 160,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.backgroundColor = const Color(0xF2FFFFFF),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.showShadow = false,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: showShadow ? AppTheme.softShadow : null,
      ),
      child: Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return const FittedBox(
            fit: BoxFit.scaleDown,
            child: Icon(
              Icons.school_rounded,
              size: 48,
              color: AppTheme.primaryGreen,
            ),
          );
        },
      ),
    );
  }
}