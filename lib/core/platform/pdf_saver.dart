// انتخاب پیاده‌سازی در زمان کامپایل.
//
// چرا این فایل وجود دارد: پیش از این، `input.dart` هم‌زمان `dart:io` و
// `dart:html` را import می‌کرد و با `kIsWeb` بین‌شان سوییچ می‌کرد. اما
// `kIsWeb` یک شرط زمان اجراست و جلوی import زمان کامپایل را نمی‌گیرد؛
// نتیجه این بود که فایل روی هیچ پلتفرمی کامپایل نمی‌شد:
//   • بیلد وب    → Dart library 'dart:io' is not available on this platform
//   • بیلد موبایل → Dart library 'dart:html' is not available on this platform
//
// با conditional export، کامپایلر فقط پیاده‌سازی مناسب همان پلتفرم را وارد
// می‌کند و هر دو مسیر دست‌نخورده باقی می‌مانند.
//
// هر دو پیاده‌سازی این دو تابع را ارائه می‌دهند:
//   Future<void> savePdf(Uint8List bytes, String filename)
//   Future<void> savePdfBatch(List<(Uint8List, String)> files)
export 'pdf_saver_io.dart' if (dart.library.html) 'pdf_saver_web.dart';
