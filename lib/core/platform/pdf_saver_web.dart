import 'dart:html' as html;
import 'dart:typed_data';

/// دانلود یک PDF در مرورگر.
///
/// این فایل فقط در بیلد وب کامپایل می‌شود (از طریق conditional export در
/// `pdf_saver.dart`)، پس import کردن `dart:html` اینجا امن است.
Future<void> savePdf(Uint8List bytes, String filename) async {
  _download(bytes, filename);
}

/// دانلود چند PDF پشت سر هم.
///
/// فاصله‌ی کوتاه بین دانلودها عمدی است: بعضی مرورگرها دانلودهای پشت‌سرهم و
/// بدون وقفه را به‌عنوان popup مسدود می‌کنند.
Future<void> savePdfBatch(List<(Uint8List, String)> files) async {
  for (final (bytes, filename) in files) {
    _download(bytes, filename);
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

void _download(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrl(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
