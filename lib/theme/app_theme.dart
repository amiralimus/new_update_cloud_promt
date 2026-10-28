import 'package:flutter/material.dart';

import '../colors.dart';

/// ساخت `ThemeData` هماهنگ با توکن‌های `colors.dart`.
///
/// ویجت‌های خود فلاتر (دیالوگ، اسنک‌بار، منو، تولتیپ، اسکرول‌بار) رنگشان را
/// از اینجا می‌گیرند.
ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: primeColor,
    brightness: Brightness.light,
  ).copyWith(
    primary: primeColor,
    onPrimary: onPrimaryColor,
    surface: surfaceColor,
    onSurface: textPrimaryColor,
    error: dangerFgColor,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: backgroundColor,
    canvasColor: surfaceColor,
    dividerColor: borderColor,
    shadowColor: shadowColor,
    primaryColor: primeColor,

    // تنها تغییر رفتاری تم: انیمیشن جابه‌جایی صفحه‌ها. حالت پیش‌فرض روی وب
    // zoom است که هر بار یک لایه‌ی کامل را مقیاس و محو می‌کند و روی
    // صفحه‌های بزرگ این پروژه محسوس کند است.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      ),
      contentTextStyle: TextStyle(fontSize: 14, color: textSecondaryColor),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceColor,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: textPrimaryColor, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xff323232),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xff37474F),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primeColor,
      selectionColor: primeColor.withValues(alpha: 0.28),
      selectionHandleColor: primeColor,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primeColor),
    iconTheme: IconThemeData(color: textSecondaryColor),
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(
      bodyColor: textPrimaryColor,
      displayColor: textPrimaryColor,
      decorationColor: textPrimaryColor,
    ),
  );
}