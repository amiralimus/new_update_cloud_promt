import 'package:flutter/foundation.dart';

/// سرویس لاگینگ ساده و کارآمد برای API و رویدادهای تطبیق
class LoggerService {
  static const String _tag = '🔵 CLASSIC_CAFE';
  static const String _apiTag = '📡 API';
  static const String _authTag = '🔐 AUTH';
  static const String _profileTag = '👤 PROFILE';
  static const String _errorTag = '🔴 ERROR';

  /// لاگ برای درخواست API
  static void logApiRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    if (!kDebugMode) return;

    debugPrint('$_tag | $_apiTag');
    debugPrint('  📤 [REQUEST] $method $url');

    if (headers != null && headers.isNotEmpty) {
      debugPrint('  Headers:');
      headers.forEach((key, value) {
        // پنهان کردن توکن برای امنیت
        final displayValue = key.contains('Authorization')
            ? '${value.substring(0, 20)}...'
            : value;
        debugPrint('    - $key: $displayValue');
      });
    }

    if (body != null && body.isNotEmpty) {
      debugPrint('  Body: ${_prettyJson(body)}');
    }
  }

  /// لاگ برای پاسخ API
  static void logApiResponse({
    required String method,
    required String url,
    required int statusCode,
    required String responseBody,
    required Duration duration,
  }) {
    if (!kDebugMode) return;

    final statusEmoji =
    statusCode >= 200 && statusCode < 300 ? '✅' : '⚠️';
    debugPrint('$_tag | $_apiTag');
    debugPrint(
        '  📥 [RESPONSE] $statusEmoji $statusCode - $method $url (${duration.inMilliseconds}ms)');

    if (responseBody.isNotEmpty) {
      try {
        debugPrint('  Body: ${_prettyJson(responseBody)}');
      } catch (e) {
        debugPrint('  Body: $responseBody');
      }
    }
  }

  /// لاگ برای خطاهای API
  static void logApiError({
    required String method,
    required String url,
    required String error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    debugPrint('$_tag | $_errorTag | $_apiTag');
    debugPrint('  ❌ [ERROR] $method $url');
    debugPrint('  Message: $error');

    if (stackTrace != null) {
      debugPrint('  Stack: ${stackTrace.toString().split('\n').take(3).join('\n  ')}');
    }
  }

  /// لاگ برای احراز هویت (لاگین/ثبت‌نام)
  static void logAuth({
    required String action,
    required String message,
    bool isSuccess = true,
  }) {
    if (!kDebugMode) return;

    final emoji = isSuccess ? '✅' : '❌';
    debugPrint('$_tag | $_authTag');
    debugPrint('  $emoji [$action] $message');
  }

  /// لاگ برای توکن
  static void logTokenOperation({
    required String operation,
    String? tokenPreview,
  }) {
    if (!kDebugMode) return;

    debugPrint('$_tag | $_authTag');
    if (tokenPreview != null) {
      final preview = '${tokenPreview.substring(0, 20)}...';
      debugPrint('  🔑 [$operation] $preview');
    } else {
      debugPrint('  🔑 [$operation] توکن موجود نیست');
    }
  }

  /// لاگ برای پروفایل
  static void logProfile({
    required String action,
    required String message,
  }) {
    if (!kDebugMode) return;

    debugPrint('$_tag | $_profileTag');
    debugPrint('  👤 [$action] $message');
  }

  /// لاگ برای رویدادهای عمومی
  static void logEvent({
    required String title,
    required String message,
  }) {
    if (!kDebugMode) return;

    debugPrint('$_tag | ℹ️  [$title] $message');
  }

  /// تبدیل JSON به فرمت قابل‌خواندگی
  static String _prettyJson(dynamic json) {
    try {
      if (json is String) {
        return json;
      }
      return json.toString();
    } catch (e) {
      return json.toString();
    }
  }
}