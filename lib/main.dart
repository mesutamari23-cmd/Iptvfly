import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'theme.dart';
import 'store.dart';
import 'ads.dart';
import 'i18n.dart';
import 'login_screen.dart';
import 'profiles_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await Store.init();
  I18n.init();
  Ads.init(); // بدون انتظار حتى لا يتأخر فتح التطبيق
  // أول تشغيل بدون حسابات: مباشرة لشاشة الدخول، وإلا شاشة الحسابات
  final Widget start =
      Store.accounts().isEmpty ? const LoginScreen() : const ProfilesScreen();
  runApp(MesutApp(start: start));
}

class MesutApp extends StatelessWidget {
  final Widget start;
  const MesutApp({super.key, required this.start});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: I18n.notifier,
      builder: (_, lang, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mesut IPTV',
        locale: Locale(lang),
        supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(primary: kViolet, secondary: kGold),
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
          chipTheme: ChipThemeData(
            selectedColor: kViolet,
            backgroundColor: Colors.white10,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        home: start,
      ),
    );
  }
}
