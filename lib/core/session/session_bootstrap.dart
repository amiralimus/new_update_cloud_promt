import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../dashboard/dashboard.dart';
import '../../rigester-login/which_one.dart';
import '../../varzeshkar_side/input.dart' show VarzeshkarSide;
import 'session_resolver.dart';
import 'session_store.dart';

/// اولین صفحه‌ی اپ: تصمیم می‌گیرد کاربر را کجا بفرستد.
///
/// پیش از این، اپ همیشه از صفحه‌ی انتخاب (`AuthChoicePage`) شروع می‌کرد و
/// کاربری که قبلاً وارد شده بود، باز هم باید دکمه می‌زد تا به داشبورد برسد.
/// حالا نشست ذخیره‌شده در همان فریم اول خوانده می‌شود و کاربر مستقیم به
/// داشبورد یا پنل ورزشکار می‌رود.
///
/// تصمیم اینجا گرفته نمی‌شود؛ `SessionResolver` تنها مرجع است تا این قاعده
/// در سه جای مختلف تکرار (و به‌مرور واگرا) نشود.
class SessionBootstrap extends StatefulWidget {
  const SessionBootstrap({super.key});

  @override
  State<SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends State<SessionBootstrap> {
  late final Future<AppSessionKind> _decision =
      SessionResolver.resolveKindOrStored();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSessionKind>(
      future: _decision,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootSplash();
        }

        final kind = snapshot.data ?? AppSessionKind.none;
        if (kind == AppSessionKind.coach) return const Dashboard();
        if (kind == AppSessionKind.athlete) return const VarzeshkarSide();
        return const AuthChoicePage();
      },
    );
  }
}

/// اسپلش کوتاه زمان بررسی نشست — بدون انیمیشن تکرارشونده تا بار پردازشی
/// اضافه‌ای روی بوت اپ نگذارد.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(primeColor),
          ),
        ),
      ),
    );
  }
}
