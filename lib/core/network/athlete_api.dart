import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../platform/pdf_saver.dart';
import '../session/session_store.dart';
import 'api_config.dart';
import 'server_endpoints.dart';

/// لایه‌ی ارتباط با سرور برای پنل ورزشکار.
///
/// چرا جدا از سمت مربی: ورزشکار اصلاً حساب نمی‌سازد و با کد دسترسی وارد
/// می‌شود؛ خطاها هم اینجا به شکل exception بالا می‌روند (نه `ApiResponse`)
/// چون هر صفحه‌ی این پنل یک جریان خطی است و می‌خواهد جریان با اولین خطا
/// قطع شود. هر دو لایه از یک `ApiConfig` و یک `ServerEndpoints` استفاده
/// می‌کنند، پس آدرس‌ها همچنان یک منبع دارند.

/// همان کلیدی که سمت مربی استفاده می‌کند.
///
/// عمداً رشته را دوباره نمی‌نویسیم: اگر روزی یکی از دو نسخه عوض شود، نشست
/// ورزشکار و مربی از هم جدا می‌شوند و کاربر بدون هیچ پیام خطایی بیرون
/// می‌افتد — همان اتفاقی که سخت‌ترین باگ‌ها از آن می‌آید.
const String tokenKey = SessionStore.tokenKey;


class Logger {
  static void log(String message, {String? error, String? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message';
    debugPrint(line);
    if (error != null) debugPrint('ERROR: $error');
    if (stackTrace != null) debugPrint('STACK: $stackTrace');
  }
}

class ProgramDownloadCodeException implements Exception {
  const ProgramDownloadCodeException(this.code);

  final String code;

  @override
  String toString() => 'ProgramDownloadCodeException($code)';
}

class SecureStorage {
  static Future<void> setString(String key, String value) async {
    try {
      final prefs = await SessionStore.prefs();
      await prefs.setString(key, value);
    } catch (e) {
      Logger.log('Persist failed for $key', error: e.toString());
    }
    Logger.log('Stored key: $key');
  }

  static Future<String?> getString(String key) async {
    try {
      return (await SessionStore.prefs()).getString(key);
    } catch (e) {
      Logger.log('Read failed for $key', error: e.toString());
      return null;
    }
  }

  static Future<void> delete(String key) async {
    try {
      await (await SessionStore.prefs()).remove(key);
    } catch (e) {
      Logger.log('Delete failed for $key', error: e.toString());
    }
    Logger.log('Deleted key: $key');
  }

  static Future<void> clear() async {
    await SessionStore.clear();
    Logger.log('Storage cleared');
  }
}

enum ProgramPdfType { both, workout, meal }

extension ProgramPdfTypeApi on ProgramPdfType {
  /// مقداری که سرور می‌فهمد.
  String get apiValue {
    switch (this) {
      case ProgramPdfType.workout:
        return 'workout';
      case ProgramPdfType.meal:
        return 'meal';
      case ProgramPdfType.both:
        return 'both';
    }
  }
}

/// درخواست توکن ورزشکار از مربی — شکل خام داده‌ی سرور.
///
/// رنگ و برچسب فارسی وضعیت عمداً اینجا نیست؛ آن‌ها تصمیم رابط کاربری‌اند و
/// در `input.dart` به‌صورت extension اضافه می‌شوند.
class TokenRequest {
  final int id;
  final int requestedTokens;
  final String status;
  final String message;
  final String createdAt;

  TokenRequest({
    required this.id,
    required this.requestedTokens,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory TokenRequest.fromJson(Map<String, dynamic> json) {
    return TokenRequest(
      id: json['id'] ?? 0,
      requestedTokens: json['requested_tokens'] ?? 0,
      status: json['status'] ?? 'pending',
      message: json['message'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isPending => status == 'pending';
}

class PdfFileHelper {
  /// ذخیره/دانلود یک PDF.
  ///
  /// انتخاب مسیر وب یا موبایل دیگر با `kIsWeb` در زمان اجرا انجام نمی‌شود،
  /// بلکه `pdf_saver.dart` در زمان کامپایل پیاده‌سازی درست را وارد می‌کند.
  /// دلیلش این است که import کردن هم‌زمان `dart:io` و `dart:html` باعث
  /// می‌شد این فایل روی هیچ پلتفرمی کامپایل نشود.
  static Future<void> saveAndOpen(Uint8List bytes, String filename) async {
    try {
      await savePdf(bytes, filename);
      Logger.log('PDF saved: $filename');
    } catch (e) {
      Logger.log('PDF save error', error: e.toString());
      rethrow;
    }
  }

  static Future<void> saveMultipleAndOpen(List<(Uint8List, String)> pdfFiles) async {
    try {
      if (pdfFiles.isEmpty) return;
      await savePdfBatch(pdfFiles);
      Logger.log('${pdfFiles.length} PDFs saved');
    } catch (e) {
      Logger.log('Multiple PDF save error', error: e.toString());
      rethrow;
    }
  }
}

class AthleteApi {
  static Future<Map<String, String>> _getHeaders({bool useAuth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (useAuth) {
      final token = await SecureStorage.getString(tokenKey);
      if (token != null) {
        headers['Authorization'] = 'Token $token';
      }
    }
    return headers;
  }

  /// دریافت برنامه‌ای که مربی از قبل ساخته، با کد یکبارمصرف.
  ///
  /// نیازی به حساب کاربری ندارد و توکنی مصرف نمی‌کند؛ فقط تحویل فایل است.
  /// خروجی: بایت‌های PDF.
  static Future<Uint8List> redeemProgramCode(String code) async {
    final response = await http
        .post(
      ApiConfig.uri(ServerEndpoints.programRedeemCode),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'code': code}),
    )
        .timeout(ApiConfig.longRequestTimeout);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    String message = 'دریافت برنامه ناموفق بود.';
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data['error'] != null) {
        message = data['error'].toString();
      }
    } catch (_) {
      // پاسخ خطای غیر JSON — همان پیام پیش‌فرض
    }
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> clientLogin(String accessCode) async {
    try {
      Logger.log('Attempting client login with code: $accessCode');
      final response = await http
          .post(
        ApiConfig.uri(ServerEndpoints.clientAccess),
        headers: await _getHeaders(),
        body: jsonEncode({'access_code': accessCode}),
      )
          .timeout(ApiConfig.shortRequestTimeout);

      Logger.log('Login response status: ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // سرور تشخیص داده این کد برای دانلود برنامه آماده است، نه ورود به پنل
      if (response.statusCode == 409 &&
          data['code_kind'] == 'program_download') {
        throw ProgramDownloadCodeException(accessCode);
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(data['error'] ?? data['detail'] ?? 'Login failed');
      }

      final token = data['token'];
      if (token == null) throw Exception('No token received');

      // توکن و نوع نشست با هم نوشته می‌شوند تا حالتی پیش نیاید که توکن
      // ذخیره شده اما نوع نشست نه — در آن صورت بوت اپ ورزشکار را اشتباهاً
      // به داشبورد مربی می‌فرستاد.
      await SessionStore.saveSession(
        token: token,
        kind: AppSessionKind.athlete,
      );
      Logger.log('Login successful, token stored');
      return data;
    } catch (e) {
      Logger.log('Login failed', error: e.toString());
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getClientProfile() async {
    try {
      Logger.log('Fetching client profile');
      final response = await http
          .get(
        ApiConfig.uri(ServerEndpoints.clientProfile),
        headers: await _getHeaders(useAuth: true),
      )
          .timeout(ApiConfig.shortRequestTimeout);

      if (response.statusCode == 401) {
        await SecureStorage.delete(tokenKey);
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch profile');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      Logger.log('Profile fetch failed', error: e.toString());
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getGymBrand() async {
    try {
      Logger.log('Fetching gym brand');
      final response = await http
          .get(
        ApiConfig.uri(ServerEndpoints.gymBrand),
        headers: await _getHeaders(useAuth: true),
      )
          .timeout(ApiConfig.shortRequestTimeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch gym brand');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      Logger.log('Gym brand fetch failed', error: e.toString());
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      Logger.log('Fetching user profile');
      final response = await http
          .get(
        ApiConfig.uri(ServerEndpoints.userProfile),
        headers: await _getHeaders(useAuth: true),
      )
          .timeout(ApiConfig.shortRequestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      Logger.log('User profile fetch failed', error: e.toString());
      return {};
    }
  }

  static Future<int> getTokenBalance() async {
    try {
      final profile = await getUserProfile();
      return profile['token_balance'] ?? 0;
    } catch (e) {
      Logger.log('Get token balance failed', error: e.toString());
      return 0;
    }
  }

  static Future<Map<String, dynamic>> requestTokens({
    required int amount,
    required String message,
  }) async {
    try {
      Logger.log('Requesting tokens: $amount');
      final response = await http
          .post(
        ApiConfig.uri(ServerEndpoints.tokenRequests),
        headers: await _getHeaders(useAuth: true),
        body: jsonEncode({
          'requested_tokens': amount,
          'message': message,
        }),
      )
          .timeout(ApiConfig.shortRequestTimeout);

      Logger.log('Token request response status: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errData = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(errData['error'] ?? 'Request failed');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      Logger.log('Token request failed', error: e.toString());
      rethrow;
    }
  }

  static Future<List<TokenRequest>> getTokenRequests() async {
    try {
      Logger.log('Fetching token requests');
      final response = await http
          .get(
        ApiConfig.uri(ServerEndpoints.tokenRequests),
        headers: await _getHeaders(useAuth: true),
      )
          .timeout(ApiConfig.shortRequestTimeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch requests');
      }

      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .map((item) => TokenRequest.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      Logger.log('Get requests failed', error: e.toString());
      return [];
    }
  }

  static Future<(bool, Uint8List?, Map)> generateProgram({
    required String name,
    required int? age,
    required String? gender,
    required double? height,
    required double? weight,
    required String injuries,
    required String foodAllergies,
    required String bodyIssues,
    required String chronicDiseases,
    required String exerciseHistory,
    required String extraNotes,
    required int programDays,
    required String programType,
    required String pdfType,
  }) async {
    try {
      Logger.log('Generating program with pdfType: $pdfType');
      final payload = {
        'name': name,
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'injuries': injuries,
        'food_allergies': foodAllergies,
        'body_issues': bodyIssues,
        'chronic_diseases': chronicDiseases,
        'exercise_history': exerciseHistory,
        'extra_notes': extraNotes,
        'program_days': programDays,
        'program_type': programType,
        'generate_pdf': true,
        'pdf_type': pdfType,
      };

      Logger.log('Payload: $payload');

      final response = await http
          .post(
        ApiConfig.uri(ServerEndpoints.programsGenerate),
        headers: await _getHeaders(useAuth: true),
        body: jsonEncode(payload),
      )
          .timeout(ApiConfig.longRequestTimeout);

      Logger.log('Generate response status: ${response.statusCode}');
      Logger.log('Response content-type: ${response.headers['content-type']}');

      if (response.headers['content-type']?.contains('application/pdf') ?? false) {
        Logger.log('PDF received: ${response.bodyBytes.length} bytes');
        return (true, response.bodyBytes, {});
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(data['error'] ?? 'Failed with status ${response.statusCode}');
      }

      Logger.log('Program generated successfully');
      return (false, null, data);

    } catch (e) {
      Logger.log('Program generation failed', error: e.toString());
      rethrow;
    }
  }

  static Future<Uint8List> downloadProgramPdf(
      int programId, {
        ProgramPdfType type = ProgramPdfType.both,
      }) async {
    try {
      Logger.log('Downloading PDF (${type.apiValue}) for program $programId');

      final endpoint = switch (type) {
        ProgramPdfType.workout => ServerEndpoints.programPdfWorkout(programId),
        ProgramPdfType.meal => ServerEndpoints.programPdfMeal(programId),
        ProgramPdfType.both => ServerEndpoints.programPdf(programId),
      };

      final response = await http
          .get(
        ApiConfig.uri(endpoint),
        headers: await _getHeaders(useAuth: true),
      )
          .timeout(ApiConfig.longRequestTimeout);

      Logger.log('PDF download status: ${response.statusCode}');
      Logger.log('Content-Type: ${response.headers['content-type']}');

      if (response.statusCode != 200) {
        String message = 'خطا در دانلود PDF';
        try {
          final err = jsonDecode(response.body) as Map<String, dynamic>;
          message = err['error'] ?? message;
        } catch (_) {}
        throw Exception(message);
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('فایل PDF خالی است');
      }

      Logger.log('PDF downloaded: ${response.bodyBytes.length} bytes');
      return response.bodyBytes;
    } catch (e) {
      Logger.log('PDF download failed', error: e.toString());
      rethrow;
    }
  }

  static Future<List<(Uint8List, String)>> downloadMultipleProgramPdfs({
    required int programId,
    required List<ProgramPdfType> types,
  }) async {
    try {
      Logger.log('Downloading ${types.length} PDFs for program $programId');

      final List<Future<(Uint8List, String)>> futures = [];
      for (final type in types) {
        futures.add(
            downloadProgramPdf(programId, type: type)
                .then((bytes) => (bytes, 'program_${programId}_${type.apiValue}.pdf'))
        );
      }

      final results = await Future.wait(futures);
      Logger.log('All ${results.length} PDFs downloaded successfully');
      return results;

    } catch (e) {
      Logger.log('Multiple PDF download failed', error: e.toString());
      rethrow;
    }
  }

  /// خروج ورزشکار.
  ///
  /// توکن روی سرور هم باطل می‌شود. پیش از این فقط حافظه‌ی مرورگر پاک
  /// می‌شد و همان توکن تا ابد روی سرور معتبر می‌ماند.
  static Future<void> logout() async {
    try {
      await http
          .post(
            ApiConfig.uri(ServerEndpoints.authLogout),
            headers: await _getHeaders(useAuth: true),
          )
          .timeout(ApiConfig.shortRequestTimeout);
    } catch (e) {
      // شکست درخواست خروج نباید مانع پاک‌شدن نشست محلی شود
      Logger.log('Server logout failed', error: e.toString());
    }

    // clear همه‌ی کلیدهای نشست (توکن، شماره، نوع) را با هم پاک می‌کند؛
    // حذف جداگانه‌ی توکن پیش از آن کار اضافه بود.
    await SecureStorage.clear();
    Logger.log('Logged out');
  }
}
