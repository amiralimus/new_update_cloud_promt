import 'package:flutter/widgets.dart';

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1100; // کمی فاصله امن از 1024
}

enum AppDeviceType { mobile, tablet, desktop }

class AppResponsive {
  static AppDeviceType deviceType(BuildContext context) {
    // shortestSide مستقل از چرخش صفحه است
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;

    if (shortestSide < AppBreakpoints.mobile) {
      return AppDeviceType.mobile;
    }
    if (shortestSide < AppBreakpoints.tablet) {
      return AppDeviceType.tablet;
    }
    return AppDeviceType.desktop;
  }

// بقیه‌ی متدها همون‌طور که هست می‌مونن
}