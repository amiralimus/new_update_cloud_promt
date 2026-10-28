import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/network/api_config.dart';
import '../core/session/session_store.dart';

// ============================================================================
// 1️⃣ سرویس لاگینگ - بدون تغییر (برای وب هم کار می‌کند)
// ============================================================================

class LoggerService {
  static const String _tag = '🔵 CLASSIC_CAFE';
  static const String _apiTag = '📡 API';
  static const String _authTag = '🔐 AUTH';
  static const String _profileTag = '👤 PROFILE';
  static const String _errorTag = '🔴 ERROR';

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
        final displayValue = key.contains('Authorization')
            ? '${value.substring(0, 20)}...'
            : value;
        debugPrint('    - $key: $displayValue');
      });
    }
    if (body != null && body.isNotEmpty) {
      debugPrint('  Body: $body');
    }
  }

  static void logApiResponse({
    required String method,
    required String url,
    required int statusCode,
    required String responseBody,
    required Duration duration,
  }) {
    if (!kDebugMode) return;
    final statusEmoji = statusCode >= 200 && statusCode < 300 ? '✅' : '⚠️';
    debugPrint('$_tag | $_apiTag');
    debugPrint(
      '  📥 [RESPONSE] $statusEmoji $statusCode - $method $url (${duration.inMilliseconds}ms)',
    );
    if (responseBody.isNotEmpty && responseBody.length < 500) {
      debugPrint('  Body: $responseBody');
    }
  }

  static void logApiError({
    required String method,
    required String url,
    required String error,
  }) {
    if (!kDebugMode) return;
    debugPrint('$_tag | $_errorTag | $_apiTag');
    debugPrint('  ❌ [ERROR] $method $url');
    debugPrint('  Message: $error');
  }

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

  static void logProfile({required String action, required String message}) {
    if (!kDebugMode) return;
    debugPrint('$_tag | $_profileTag');
    debugPrint('  👤 [$action] $message');
  }

  static void logEvent({required String title, required String message}) {
    if (!kDebugMode) return;
    debugPrint('$_tag | ℹ️  [$title] $message');
  }
}

// ============================================================================
// 2️⃣ سرویس توکن — پوسته‌ای روی SessionStore
// ============================================================================

/// پوسته‌ی نازک روی [SessionStore] برای سمت مربی/کاربر شخصی.
///
/// عمداً هیچ کلید یا کش اختصاصی ندارد:
///
/// * **کلید تکراری نه** — رشته‌ی کلید فقط در `SessionStore` تعریف شده. پیش از
///   این در سه فایل تکرار شده بود و اگر یکی عوض می‌شد، نشست بی‌صدا دو تکه
///   می‌شد و کاربر بدون هیچ پیام خطایی بیرون می‌افتاد.
/// * **کش تکراری نه** — این کلاس قبلاً `_cachedToken` خودش را داشت. اگر جای
///   دیگری (مثل خروج ورزشکار یا ابطال توکن در بوت) نشست را پاک می‌کرد، این
///   کش کهنه می‌ماند و برنامه با توکن مرده به کار ادامه می‌داد.
///   `SharedPreferences` خودش همه‌چیز را در حافظه نگه می‌دارد، پس این لایه
///   از ابتدا اضافه بود.
class AuthTokenService {
  static final AuthTokenService _instance = AuthTokenService._internal();

  factory AuthTokenService() {
    return _instance;
  }

  AuthTokenService._internal();

  /// ذخیره توکن ورود مربی/کاربر شخصی
  Future<void> saveToken({required String token, required String phone}) async {
    await SessionStore.saveSession(
      token: token,
      phone: phone,
      kind: AppSessionKind.coach,
    );

    LoggerService.logTokenOperation(operation: 'SAVE', tokenPreview: token);
    LoggerService.logAuth(
      action: 'TOKEN_SAVED',
      message: 'توکن برای $phone ذخیره شد',
    );
  }

  /// دریافت توکن
  Future<String?> getToken() async {
    final token = await SessionStore.readToken();

    if (token != null && token.isNotEmpty) {
      LoggerService.logTokenOperation(
        operation: 'RETRIEVE',
        tokenPreview: token,
      );
    } else {
      LoggerService.logAuth(
        action: 'NO_TOKEN',
        message: 'توکن ذخیره‌شده‌ای موجود نیست',
        isSuccess: false,
      );
    }

    return token;
  }

  /// دریافت شماره کاربر
  Future<String?> getUserPhone() => SessionStore.readPhone();

  /// حذف توکن (لاگ‌آوت)
  Future<void> clearToken() async {
    await SessionStore.clear();
    LoggerService.logAuth(action: 'LOGOUT', message: 'توکن حذف شد');
  }

  /// بررسی لاگین بودن
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// دریافت headers احراز هویت
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      LoggerService.logAuth(
        action: 'AUTH_HEADER_MISSING',
        message: 'توکن موجود نیست، درخواست بدون Authorization ارسال می‌شود',
        isSuccess: false,
      );
      return {'Content-Type': 'application/json; charset=UTF-8'};
    }

    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json; charset=UTF-8',
    };
  }
}

// ============================================================================
// 3️⃣ سرویس API
// ============================================================================

class ApiResponse {
  final int statusCode;
  final bool success;
  final dynamic data;
  final String? error;

  ApiResponse({
    required this.statusCode,
    required this.success,
    this.data,
    this.error,
  });

  @override
  String toString() =>
      'ApiResponse(status: $statusCode, success: $success, error: $error)';
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  final AuthTokenService _authService = AuthTokenService();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  /// تبدیل مسیر نسبی تصویر (که سرور برمی‌گردونه) به آدرس کامل قابل نمایش
  /// اگر سرور خودش آدرس کامل (http/https) برگردونه، همون استفاده می‌شه.
  static String resolveMediaUrl(String path) {
    return ApiConfig.resolveMediaUrl(path);
  }

  /// دریافت پاسخ باینری (مثل PDF).
  ///
  /// `get` معمولی پاسخ را JSON فرض می‌کند و برای فایل به‌درد نمی‌خورد؛
  /// اینجا بایت‌ها دست‌نخورده برگردانده می‌شوند. در صورت خطا `null`.
  Future<Uint8List?> getBytes({
    required String endpoint,
    bool requiresAuth = true,
  }) async {
    final url = ApiConfig.uri(endpoint);

    try {
      final headers = await _getHeaders(requiresAuth);

      LoggerService.logApiRequest(
        method: 'GET (bytes)',
        url: url.toString(),
        headers: headers,
      );

      final startTime = DateTime.now();
      final response = await http
          .get(url, headers: headers)
          .timeout(ApiConfig.longRequestTimeout);
      final duration = DateTime.now().difference(startTime);

      LoggerService.logApiResponse(
        method: 'GET (bytes)',
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: '<${response.bodyBytes.length} bytes>',
        duration: duration,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      LoggerService.logApiError(
        method: 'GET (bytes)',
        url: url.toString(),
        error: e.toString(),
      );
      return null;
    }
  }

  Future<ApiResponse> get({
    required String endpoint,
    bool requiresAuth = true,
  }) async {
    final url = ApiConfig.uri(endpoint);

    try {
      final headers = await _getHeaders(requiresAuth);

      LoggerService.logApiRequest(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final startTime = DateTime.now();
      final response = await http
          .get(url, headers: headers)
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () => throw Exception('درخواست زمان‌مند شد (15 ثانیه)'),
          );

      final duration = DateTime.now().difference(startTime);

      LoggerService.logApiResponse(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        duration: duration,
      );

      return _handleResponse(response);
    } catch (e) {
      LoggerService.logApiError(
        method: 'GET',
        url: url.toString(),
        error: e.toString(),
      );

      return ApiResponse(
        statusCode: 0,
        success: false,
        error: 'خطا در درخواست: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> post({
    required String endpoint,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    final url = ApiConfig.uri(endpoint);

    try {
      final headers = await _getHeaders(requiresAuth);

      LoggerService.logApiRequest(
        method: 'POST',
        url: url.toString(),
        body: body,
        headers: headers,
      );

      final startTime = DateTime.now();
      final response = await http
          .post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            timeout ?? ApiConfig.requestTimeout,
            onTimeout: () => throw Exception(
              'درخواست زمان‌مند شد '
              '(${(timeout ?? ApiConfig.requestTimeout).inSeconds} ثانیه)',
            ),
          );

      final duration = DateTime.now().difference(startTime);

      LoggerService.logApiResponse(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        duration: duration,
      );

      return _handleResponse(response);
    } catch (e) {
      LoggerService.logApiError(
        method: 'POST',
        url: url.toString(),
        error: e.toString(),
      );

      return ApiResponse(
        statusCode: 0,
        success: false,
        error: 'خطا در درخواست: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> put({
    required String endpoint,
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    final url = ApiConfig.uri(endpoint);

    try {
      final headers = await _getHeaders(requiresAuth);

      LoggerService.logApiRequest(
        method: 'PUT',
        url: url.toString(),
        body: body,
        headers: headers,
      );

      final startTime = DateTime.now();
      final response = await http
          .put(url, headers: headers, body: jsonEncode(body))
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () => throw Exception('درخواست زمان‌مند شد (15 ثانیه)'),
          );

      final duration = DateTime.now().difference(startTime);

      LoggerService.logApiResponse(
        method: 'PUT',
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        duration: duration,
      );

      return _handleResponse(response);
    } catch (e) {
      LoggerService.logApiError(
        method: 'PUT',
        url: url.toString(),
        error: e.toString(),
      );

      return ApiResponse(
        statusCode: 0,
        success: false,
        error: 'خطا در درخواست: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> patch({
    required String endpoint,
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    final url = ApiConfig.uri(endpoint);

    try {
      final headers = await _getHeaders(requiresAuth);

      LoggerService.logApiRequest(
        method: 'PATCH',
        url: url.toString(),
        body: body,
        headers: headers,
      );

      final startTime = DateTime.now();
      final response = await http
          .patch(url, headers: headers, body: jsonEncode(body))
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () => throw Exception('درخواست زمان‌مند شد (15 ثانیه)'),
          );

      final duration = DateTime.now().difference(startTime);

      LoggerService.logApiResponse(
        method: 'PATCH',
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        duration: duration,
      );

      return _handleResponse(response);
    } catch (e) {
      LoggerService.logApiError(
        method: 'PATCH',
        url: url.toString(),
        error: e.toString(),
      );

      return ApiResponse(
        statusCode: 0,
        success: false,
        error: 'خطا در درخواست: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse> delete({
    required String endpoint,
    bool requiresAuth = true,
  }) async {
    final url = ApiConfig.uri(endpoint);

    try {
      final headers = await _getHeaders(requiresAuth);

      LoggerService.logApiRequest(
        method: 'DELETE',
        url: url.toString(),
        headers: headers,
      );

      final startTime = DateTime.now();
      final response = await http
          .delete(url, headers: headers)
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () => throw Exception('درخواست زمان‌مند شد (15 ثانیه)'),
          );

      final duration = DateTime.now().difference(startTime);

      LoggerService.logApiResponse(
        method: 'DELETE',
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        duration: duration,
      );

      return _handleResponse(response);
    } catch (e) {
      LoggerService.logApiError(
        method: 'DELETE',
        url: url.toString(),
        error: e.toString(),
      );

      return ApiResponse(
        statusCode: 0,
        success: false,
        error: 'خطا در حذف: ${e.toString()}',
      );
    }
  }

  /// درخواست چندبخشی (multipart) برای زمانی که فایل (مثل عکس پروفایل) هم
  /// همراه با فیلدهای متنی ارسال می‌شود.
  Future<ApiResponse> multipart({
    required String method, // 'POST' یا 'PATCH' یا 'PUT'
    required String endpoint,
    Map<String, String>? fields,
    String? fileFieldName,
    Uint8List? fileBytes,
    String? fileName,
    bool requiresAuth = true,
  }) async {
    final url = ApiConfig.uri(endpoint);

    try {
      final headers = await _getHeaders(requiresAuth);
      // برای multipart نباید Content-Type دستی ست بشه؛
      // پکیج http خودش boundary مناسب رو تنظیم می‌کنه.
      headers.remove('Content-Type');

      final request = http.MultipartRequest(method, url);
      request.headers.addAll(headers);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (fileBytes != null && fileFieldName != null) {
        final uploadFileName = fileName?.trim().isNotEmpty == true
            ? fileName!.trim()
            : 'upload.jpg';
        request.files.add(
          http.MultipartFile.fromBytes(
            fileFieldName,
            fileBytes,
            filename: uploadFileName,
            contentType: _mediaTypeForFileName(uploadFileName),
          ),
        );
      }

      LoggerService.logApiRequest(
        method: '$method (multipart)',
        url: url.toString(),
        body: fields,
        headers: headers,
      );

      final startTime = DateTime.now();
      final streamedResponse = await request.send().timeout(
        ApiConfig.longRequestTimeout,
        onTimeout: () => throw Exception('درخواست زمان‌مند شد (30 ثانیه)'),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final duration = DateTime.now().difference(startTime);

      LoggerService.logApiResponse(
        method: '$method (multipart)',
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        duration: duration,
      );

      return _handleResponse(response);
    } catch (e) {
      LoggerService.logApiError(
        method: '$method (multipart)',
        url: url.toString(),
        error: e.toString(),
      );

      return ApiResponse(
        statusCode: 0,
        success: false,
        error: 'خطا در آپلود: ${e.toString()}',
      );
    }
  }

  Future<Map<String, String>> _getHeaders(bool requiresAuth) async {
    if (requiresAuth) {
      return await _authService.getAuthHeaders();
    }

    return {'Content-Type': 'application/json; charset=UTF-8'};
  }

  static http.MediaType _mediaTypeForFileName(String fileName) {
    final extension = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
        : '';

    return switch (extension) {
      'jpg' || 'jpeg' => http.MediaType('image', 'jpeg'),
      'png' => http.MediaType('image', 'png'),
      'gif' => http.MediaType('image', 'gif'),
      'webp' => http.MediaType('image', 'webp'),
      'heic' => http.MediaType('image', 'heic'),
      'heif' => http.MediaType('image', 'heif'),
      _ => http.MediaType('application', 'octet-stream'),
    };
  }

  /// پیام خطای خواندنی از پاسخ سرور.
  ///
  /// پیش از این فقط کلیدهای `detail` و `error` خوانده می‌شد و خطاهای
  /// اعتبارسنجی DRF — که به شکل `{"phone": ["..."]}` برمی‌گردند — همه به
  /// «خطای ناشناخته» تبدیل می‌شدند. کاربر می‌دید فرم ذخیره نمی‌شود ولی
  /// هیچ‌وقت نمی‌فهمید کدام فیلد ایراد دارد.
  static String _extractError(dynamic body) {
    if (body is String && body.trim().isNotEmpty) return body;

    if (body is List && body.isNotEmpty) {
      return body.map((e) => e.toString()).join('\n');
    }

    if (body is Map) {
      for (final key in const [
        'detail',
        'error',
        'message',
        'non_field_errors',
      ]) {
        final value = body[key];
        if (value == null) continue;
        if (value is List && value.isNotEmpty) {
          return value.map((e) => e.toString()).join('\n');
        }
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }

      // خطاهای فیلدبه‌فیلد: هر فیلد در یک خط
      final parts = <String>[];
      body.forEach((key, value) {
        final text = value is List
            ? value.map((e) => e.toString()).join('، ')
            : value.toString();
        if (text.trim().isEmpty) return;
        parts.add('$key: $text');
      });
      if (parts.isNotEmpty) return parts.join('\n');
    }

    return 'خطای ناشناخته';
  }

  ApiResponse _handleResponse(http.Response response) {
    try {
      if (response.statusCode == 204) {
        return ApiResponse(
          statusCode: response.statusCode,
          success: true,
          data: {},
        );
      }

      if (response.body.isEmpty) {
        return ApiResponse(
          statusCode: response.statusCode,
          success: response.statusCode >= 200 && response.statusCode < 300,
          data: response.statusCode >= 200 && response.statusCode < 300
              ? {}
              : null,
        );
      }

      final decodedBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          success: true,
          data: decodedBody,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          success: false,
          data: decodedBody,
          error: _extractError(decodedBody),
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: response.statusCode,
        success: false,
        error: 'خطا در پردازش پاسخ: ${e.toString()}',
      );
    }
  }
}
