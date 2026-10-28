import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// ذخیره یک PDF در پوشه اسناد و باز کردن آن با برنامه پیش‌فرض دستگاه.
///
/// این فایل فقط در بیلد موبایل/دسکتاپ کامپایل می‌شود (از طریق conditional
/// export در `pdf_saver.dart`)، پس import کردن `dart:io` اینجا امن است.
Future<void> savePdf(Uint8List bytes, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}

/// ذخیره چند PDF و باز کردن اولین مورد — همان رفتار قبلی.
Future<void> savePdfBatch(List<(Uint8List, String)> files) async {
  if (files.isEmpty) return;

  final directory = await getApplicationDocumentsDirectory();
  for (final (bytes, filename) in files) {
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
  }

  final firstFile = File('${directory.path}/${files.first.$2}');
  await OpenFilex.open(firstFile.path);
}
