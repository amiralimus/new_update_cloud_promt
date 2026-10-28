import 'package:shared_preferences/shared_preferences.dart';

/// نوع نشستی که روی این مرورگر ذخیره شده است.
///
/// هر دو سمت (مربی/کاربر شخصی و ورزشکار باشگاه) توکن را زیر یک کلید ذخیره
/// می‌کنند، پس بدون این نشانه نمی‌شود فهمید کاربر بازگشته را باید به داشبورد
/// فرستاد یا به پنل ورزشکار.
enum AppSessionKind { none, coach, athlete }

/// محل واحد نگه‌داری نشست کاربر روی مرورگر.
///
/// دلیل وجودش: پیش از این، سمت ورزشکار توکن را در یک `Map` در حافظه نگه
/// می‌داشت و با هر بار refresh صفحه پاک می‌شد؛ کاربر مجبور بود هر بار دوباره
/// کد دسترسی بزند. حالا هر دو سمت روی `SharedPreferences` می‌نویسند که در
/// وب روی `localStorage` می‌نشیند و بین بازدیدها باقی می‌ماند.
class SessionStore {
  SessionStore._();

  static const String tokenKey = 'auth_token_classic_cafe';
  static const String phoneKey = 'user_phone';
  static const String _kindKey = 'session_kind';

  static SharedPreferences? _prefs;

  /// نمونه‌ی SharedPreferences را یک بار می‌گیرد و نگه می‌دارد.
  ///
  /// در بوت اپ یک بار صدا زده می‌شود تا خواندن توکن در مسیرهای داغ (هر
  /// درخواست API) دیگر منتظر مقداردهی اولیه نماند.
  static Future<SharedPreferences> prefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<String?> readToken() async {
    try {
      return (await prefs()).getString(tokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readPhone() async {
    try {
      return (await prefs()).getString(phoneKey);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  /// ذخیره‌ی نشست — تنها نقطه‌ای که توکن نوشته می‌شود.
  ///
  /// هر دو سمت (مربی و ورزشکار) از همین‌جا می‌نویسند تا کلید در چند فایل
  /// تکرار نشود؛ تکرار کلید یعنی اگر روزی یکی‌شان عوض شود، نشست بی‌صدا دو
  /// تکه می‌شود و کاربر بدون هیچ پیام خطایی از سیستم بیرون می‌افتد.
  static Future<void> saveSession({
    required String token,
    required AppSessionKind kind,
    String? phone,
  }) async {
    try {
      final store = await prefs();
      await store.setString(tokenKey, token);
      if (phone != null && phone.isNotEmpty) {
        await store.setString(phoneKey, phone);
      }
      await saveKind(kind);
    } catch (_) {
      // نوشتن در حافظه‌ی مرورگر ممکن است در حالت خصوصی مسدود باشد؛
      // ورود همان نشست جاری باید کار کند حتی اگر ماندگار نشود.
    }
  }

  static Future<void> saveKind(AppSessionKind kind) async {
    try {
      final store = await prefs();
      if (kind == AppSessionKind.none) {
        await store.remove(_kindKey);
      } else {
        await store.setString(_kindKey, kind.name);
      }
    } catch (_) {
      // ذخیره‌نشدن نوع نشست نباید ورود را بشکند؛ در بدترین حالت کاربر
      // یک بار صفحه انتخاب را می‌بیند.
    }
  }

  static Future<AppSessionKind> readKind() async {
    try {
      final value = (await prefs()).getString(_kindKey);
      if (value == AppSessionKind.coach.name) return AppSessionKind.coach;
      if (value == AppSessionKind.athlete.name) return AppSessionKind.athlete;
      return AppSessionKind.none;
    } catch (_) {
      return AppSessionKind.none;
    }
  }

  /// نشست ذخیره‌شده و نوع آن — برای تصمیم مسیر در بوت اپ.
  static Future<AppSessionKind> resolveKind() async {
    if (!await hasToken()) return AppSessionKind.none;
    final kind = await readKind();
    // توکنی که پیش از افزوده‌شدن این نشانه ذخیره شده باشد، نوع ندارد؛
    // آن را نشست مربی در نظر می‌گیریم چون تنها مسیری بود که توکن را
    // ماندگار ذخیره می‌کرد.
    return kind == AppSessionKind.none ? AppSessionKind.coach : kind;
  }

  static Future<void> clear() async {
    try {
      final store = await prefs();
      await store.remove(tokenKey);
      await store.remove(phoneKey);
      await store.remove(_kindKey);
    } catch (_) {
      // پاک‌نشدن از حافظه‌ی مرورگر نباید خروج را بشکند
    }
  }
}
