import 'dart:convert';

import 'package:http/http.dart' as http;

import '../network/api_config.dart';
import '../network/server_endpoints.dart';
import 'session_store.dart';

/// نتیجه‌ی بررسی نشست ذخیره‌شده روی این مرورگر.
enum SessionCheck {
  /// نشستی وجود ندارد یا سرور آن را باطل کرده است.
  none,

  /// نشست معتبر مربی/کاربر شخصی.
  coach,

  /// نشست معتبر ورزشکار باشگاه.
  athlete,

  /// توکن هست ولی سرور در دسترس نیست؛ تصمیم قطعی ممکن نیست.
  offline,
}

/// تصمیم‌گیرنده‌ی واحد درباره‌ی «این کاربر قبلاً وارد شده یا نه، و کجا».
///
/// چرا یک جا: پیش از این سه نقطه‌ی مختلف (بوت اپ، دکمه‌ی «ورود» در صفحه‌ی
/// انتخاب، و پنل ورزشکار) هرکدام قاعده‌ی خودشان را داشتند و فقط وجود توکن
/// را چک می‌کردند، نه نوعش را. نتیجه این بود که مثلاً ورزشکاری که وارد شده
/// بود با زدن دکمه‌ی «ورود» به داشبورد مربی می‌رفت و با یک پنل پر از خطا
/// روبه‌رو می‌شد که راه برگشتی هم نداشت.
///
/// مرجع نهایی، `account_type` خودِ سرور است — نه چیزی که قبلاً در مرورگر
/// نوشته‌ایم. اگر آن دو با هم نخوانند، مقدار ذخیره‌شده اصلاح می‌شود.
class SessionResolver {
  SessionResolver._();

  /// نشست ذخیره‌شده را با سرور می‌سنجد.
  ///
  /// فقط پاسخ صریح ۴۰۱/۴۰۳ باعث پاک‌شدن نشست می‌شود. خطای شبکه (سرور خواب،
  /// اینترنت قطع) نباید کاربر را بیرون بیندازد، چون در آن حالت توکن لزوماً
  /// باطل نیست.
  static Future<SessionCheck> resolve() async {
    final token = await SessionStore.readToken();
    if (token == null || token.isEmpty) {
      // کلیدهای نیمه‌مانده (مثلاً نوع نشست بدون توکن) پاک می‌شوند تا
      // دفعه‌ی بعد تصمیم بر پایه‌ی داده‌ی ناقص گرفته نشود.
      await SessionStore.clear();
      return SessionCheck.none;
    }

    try {
      final response = await http
          .get(
            ApiConfig.uri(ServerEndpoints.userProfile),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
          )
          .timeout(ApiConfig.shortRequestTimeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        await SessionStore.clear();
        return SessionCheck.none;
      }

      if (response.statusCode != 200) {
        return SessionCheck.offline;
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final accountType = body is Map ? body['account_type']?.toString() : null;
      final phone = body is Map ? body['phone_number']?.toString() : null;

      final kind = accountType == 'gym_client'
          ? AppSessionKind.athlete
          : AppSessionKind.coach;

      // خودترمیمی: اگر نوع ذخیره‌شده با واقعیت سرور فرق دارد، همین‌جا
      // اصلاح می‌شود تا دفعه‌ی بعد بدون درخواست هم درست باشد.
      await SessionStore.saveSession(token: token, kind: kind, phone: phone);

      return kind == AppSessionKind.athlete
          ? SessionCheck.athlete
          : SessionCheck.coach;
    } catch (_) {
      return SessionCheck.offline;
    }
  }

  /// نوع نشست برای مسیریابی، با در نظر گرفتن حالت آفلاین.
  ///
  /// در آفلاین به آخرین نوع ذخیره‌شده اعتماد می‌کنیم؛ هر درخواست بعدی
  /// خودش خطای واقعی را نشان خواهد داد.
  static Future<AppSessionKind> resolveKindOrStored() async {
    final check = await resolve();
    switch (check) {
      case SessionCheck.coach:
        return AppSessionKind.coach;
      case SessionCheck.athlete:
        return AppSessionKind.athlete;
      case SessionCheck.none:
        return AppSessionKind.none;
      case SessionCheck.offline:
        return SessionStore.resolveKind();
    }
  }
}
