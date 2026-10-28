import '../core/session/session_resolver.dart';
import '../core/session/session_store.dart';
import '../rigester-login/token_manegment.dart';


/// لایه‌ی نازک روی نشست ذخیره‌شده‌ی مرورگر.
///
/// «کوکی» نام تاریخی این سرویس است؛ نشست در عمل روی `localStorage`
/// می‌نشیند (از طریق [SessionStore]) تا بین بازدیدها باقی بماند.
class CookieService {
  static final AuthTokenService _authTokenService = AuthTokenService();

  /// آیا توکنی روی این مرورگر ذخیره شده است؟
  ///
  /// فقط وجود توکن را می‌گوید، نه معتبر بودن یا نوعش را. برای تصمیم
  /// مسیریابی از [resolveSession] استفاده کنید — وگرنه ممکن است کاربری با
  /// نشست ورزشکار به داشبورد مربی فرستاده شود.
  static Future<bool> hasValidSession() async {
    return _authTokenService.isLoggedIn();
  }

  /// نشست را با سرور می‌سنجد و نوع واقعی حساب را برمی‌گرداند.
  static Future<AppSessionKind> resolveSession() =>
      SessionResolver.resolveKindOrStored();

  /// دریافت شماره موبایل کاربر ذخیره‌شده (در صورت وجود)
  static Future<String?> getSavedPhone() {
    return _authTokenService.getUserPhone();
  }

  /// حذف کامل نشست کاربر
  static Future<void> clearSession() async {
    await _authTokenService.clearToken();
  }
}
