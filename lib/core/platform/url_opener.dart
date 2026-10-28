// انتخاب پیاده‌سازی در زمان کامپایل — مثل pdf_saver.
//
// هدف: هیچ فایل صفحه‌ای مستقیماً `dart:html` را import نکند، وگرنه آن فایل
// روی بیلد غیروب کامپایل نمی‌شود.
export 'url_opener_io.dart' if (dart.library.html) 'url_opener_web.dart';
