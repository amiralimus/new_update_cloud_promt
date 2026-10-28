import 'package:chegher_1/rigester-login/rigester_page.dart';
import 'package:flutter/material.dart';
import '../colors.dart';
import '../cookis/cooki.dart';
import '../dashboard/dashboard.dart';
import '../core/session/session_store.dart';
import '../loging_system/loging_system.dart';

import '../varzeshkar_side/input.dart' show VarzeshkarSide;


class AuthChoicePage extends StatelessWidget {
  const AuthChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: surfaceColor,
        body: SafeArea(
          child: Stack(
            children: [
              // کلید تم پیش از ورود هم در دسترس است؛ کاربری که تم تاریک
              // می‌خواهد نباید اول مجبور به لاگین شود.

              Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo.webp',
                      width: 230,
                      cacheWidth: 460,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 26),
                    _ChoiceButton(
                      text: 'ورود ورزشکار',
                      onPressed: () => _openAthlete(context),
                    ),


                    const SizedBox(height: 16),
                    _ChoiceButton(
                      text: 'ورود',
                      onPressed: () => _openLogin(context),
                    ),
                    const SizedBox(height: 16),
                    _ChoiceButton(
                      text: 'ساخت اکانت جدید',
                      onPressed: () => _openRegister(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  /// ورود مربی/کاربر شخصی.
  ///
  /// نشست ذخیره‌شده نه‌فقط از نظر وجود توکن، بلکه از نظر **نوع حساب** هم
  /// سنجیده می‌شود. پیش از این فقط وجود توکن چک می‌شد و ورزشکاری که وارد
  /// شده بود با زدن همین دکمه به داشبورد مربی می‌رفت — پنلی که هیچ‌کدام از
  /// درخواست‌هایش برای او مجاز نبود.
  Future<void> _openLogin(BuildContext context) async {
    try {
      final kind = await CookieService.resolveSession();

      if (!context.mounted) return;

      if (kind == AppSessionKind.coach) {
        LoggerService.logEvent(
          title: 'AUTO_LOGIN',
          message: 'کاربر با توکن ذخیره‌شده وارد شد',
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const Dashboard()),
        );
        return;
      }

      if (kind == AppSessionKind.athlete) {
        LoggerService.logEvent(
          title: 'AUTO_LOGIN_ATHLETE',
          message: 'نشست ذخیره‌شده از نوع ورزشکار است؛ به پنل ورزشکار می‌رود',
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const VarzeshkarSide()),
        );
        return;
      }

      LoggerService.logEvent(
        title: 'LOGIN_PAGE_OPEN',
        message: 'صفحه ورود باز شد',
      );

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AuthPage(mode: AuthMode.login),
        ),
      );
    } catch (e) {
      LoggerService.logApiError(
        method: '_openLogin',
        url: 'session_check',
        error: e.toString(),
      );

      if (!context.mounted) return;
      _showMessage(context, 'خطا در بررسی نشست: ${e.toString()}', isError: true);
    }
  }

  /// ورود ورزشکار.
  ///
  /// اگر نشست ذخیره‌شده از نوع مربی باشد، پنل ورزشکار با آن توکن کار
  /// نمی‌کند؛ پس پیش از رفتن به آن صفحه، نشست ناهمخوان پاک می‌شود تا
  /// ورزشکار فرم کد دسترسی را ببیند، نه یک پنل خراب.
  Future<void> _openAthlete(BuildContext context) async {
    try {
      final kind = await CookieService.resolveSession();
      if (kind == AppSessionKind.coach) {
        await CookieService.clearSession();
      }
    } catch (_) {
      // شکست بررسی نشست نباید جلوی ورود ورزشکار را بگیرد
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VarzeshkarSide()),
    );
  }

  /// ثبت‌نام: صفحه ثبت‌نام باز می‌شود
  ///
  /// عمداً هیچ onSubmit پاس داده نمی‌شود. قبلاً اینجا یک کال‌بک ثبت می‌شد که
  /// دیالوگ «کد تایید» را روی context همین مسیر باز می‌کرد؛ به‌محض اینکه
  /// کاربر بین ورود و ثبت‌نام جابه‌جا می‌شد، آن context از بین می‌رفت و همان
  /// کال‌بک بعد از یک احراز موفق خطا می‌داد و پیام گمراه‌کننده‌ی «اتصال به
  /// سرور برقرار نشد» نشان داده می‌شد.
  ///
  /// ضمناً سرور در پاسخ ثبت‌نام مستقیماً توکن می‌دهد و هیچ مرحله‌ی تایید
  /// پیامکی برای ثبت‌نام ندارد، پس آن دیالوگ هیچ‌وقت به API وصل نبود.
  /// `_showVerificationDialog` برای روزی که چنین سرویسی اضافه شود در فایل
  /// نگه داشته شده است.
  void _openRegister(BuildContext context) {
    LoggerService.logEvent(
      title: 'REGISTER_PAGE_OPEN',
      message: 'صفحه ثبت‌نام باز شد',
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AuthPage(mode: AuthMode.register),
      ),
    );
  }

  /// دیالوگ تایید کد — فعلاً استفاده نمی‌شود.
  ///
  /// سرور برای ثبت‌نام کد تایید نمی‌فرستد (پاسخ ثبت‌نام مستقیماً شامل توکن
  /// است). این متد برای زمانی نگه داشته شده که سرویس تایید شماره اضافه شود؛
  /// آن موقع باید با یک context زنده صدا زده شود، نه با context یک مسیرِ
  /// جایگزین‌شده.
  // ignore: unused_element
  void _showVerificationDialog(BuildContext context) {
    final codeController = TextEditingController();
    final isVerifying = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: textPrimaryColor.withOpacity(0.5),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: surfaceColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'به شماره موبایلی که وارد کردید، کدی ارسال شده است.\nاین را وارد کنید',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 60,
                    width: 300,
                    child: TextField(
                      controller: codeController,
                      cursorColor: primeColor,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: textfildColor,
                        hintText: '----',
                        counterText: '',
                        hintStyle: TextStyle(
                          color: textFaintColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(16),
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(16),
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(16),
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  ValueListenableBuilder<bool>(
                    valueListenable: isVerifying,
                    builder: (context, verifying, _) => InkWell(
                      onTap: verifying
                          ? null
                          : () async {
                        final code = codeController.text.trim();
                        if (code.isEmpty) {
                          _showMessage(
                            context,
                            'کد تایید را وارد کنید',
                            isError: true,
                          );
                          return;
                        }

                        isVerifying.value = true;
                        try {
                          // TODO: صدا زدن API برای تایید کد
                          LoggerService.logAuth(
                            action: 'VERIFY_CODE',
                            message: 'کد تایید ارسال شد: $code',
                          );

                          _showMessage(
                            context,
                            'اکانت با موفقیت ساخته شد',
                          );

                          if (context.mounted) {
                            Navigator.of(context).pop(); // دیالوگ
                            Navigator.of(context).pop(); // صفحه ثبت‌نام
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const Dashboard(),
                              ),
                            );
                          }
                        } catch (e) {
                          LoggerService.logApiError(
                            method: '_showVerificationDialog',
                            url: 'verification-dialog (local)',
                            error: e.toString(),
                          );

                          _showMessage(
                            context,
                            'خطا در تایید کد: ${e.toString()}',
                            isError: true,
                          );
                        } finally {
                          isVerifying.value = false;
                        }
                      },
                      child: Container(
                        height: 70,
                        width: 300,
                        decoration: BoxDecoration(
                          color: verifying ? primeColor.withOpacity(0.6) : primeColor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: verifying
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onPrimaryColor,
                            ),
                          )
                              : const Text(
                            'بررسی',
                            style: TextStyle(
                              color: onPrimaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      codeController.dispose();
    });
  }

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? dangerFgColor : okFgColor,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: onPrimaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: onPrimaryColor),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primeColor,
          foregroundColor: onPrimaryColor,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}