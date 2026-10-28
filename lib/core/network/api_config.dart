class ApiConfig {
  ApiConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://chagher.ir/api/',
  );

  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration shortRequestTimeout = Duration(seconds: 10);
  static const Duration longRequestTimeout = Duration(seconds: 30);

  /// تولید برنامه با هوش مصنوعی — از بقیه‌ی مسیرها بسیار کندتر است و با
  /// تایم‌اوت معمولی، درخواستی که روی سرور موفق می‌شود روی کلاینت
  /// «ناموفق» گزارش می‌شد و مربی توکنش را سوخته می‌دید.
  static const Duration programGenerationTimeout = Duration(minutes: 3);

  static Uri uri(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }

    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    return Uri.parse('$base$path');
  }

  static String resolveMediaUrl(String path) {
    if (path.isEmpty) return path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final mediaUri = Uri.tryParse(path);
      final apiUri = Uri.parse(apiBaseUrl);
      if (mediaUri != null &&
          mediaUri.scheme == 'http' &&
          apiUri.scheme == 'https' &&
          mediaUri.host == apiUri.host) {
        return mediaUri.replace(scheme: 'https').toString();
      }
      return path;
    }

    final uri = Uri.parse(apiBaseUrl);
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }
}
