import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'core/session/session_bootstrap.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // نمونه‌ی حافظه‌ی مرورگر یک بار همین‌جا گرم می‌شود تا خواندن توکن در
  // مسیرهای داغ (هر درخواست API) منتظر مقداردهی اولیه نماند.
  await SessionStore.prefs();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      scrollBehavior: const AppScrollBehavior(),

      home: const SessionBootstrap(),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}
