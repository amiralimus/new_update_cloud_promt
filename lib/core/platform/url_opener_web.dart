import 'dart:html' as html;

/// هدایت مرورگر به آدرس پرداخت در همان تب.
///
/// عمداً از `url_launcher` استفاده نمی‌شود تا وابستگی جدیدی به pubspec
/// اضافه نشود؛ برای هدایت به درگاه، همین کافی است.
void openExternalUrl(String url) {
  html.window.location.href = url;
}
