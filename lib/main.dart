
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'store.dart';
import 'i18n.dart' hide Text;
import 'login_screen.dart';
import 'profiles_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MesutBootstrap());
}

class MesutBootstrap extends StatefulWidget {
  const MesutBootstrap({super.key});

  @override
  State<MesutBootstrap> createState() => _MesutBootstrapState();
}

class _MesutBootstrapState extends State<MesutBootstrap> {
  Widget? _app;
  String? _error;
  String _stage = 'بدء تشغيل التطبيق';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_busy) return;
    _busy = true;

    setState(() {
      _error = null;
      _stage = 'إعداد واجهة الهاتف';
    });

    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      _stage = 'تحميل الحسابات والتخزين';
      await Store.init();

      _stage = 'تحميل اللغة';
      I18n.init();

      // تم تعطيل الإعلانات مؤقتاً لاختبار التشغيل.

      final Widget start = Store.accounts().isEmpty
          ? const LoginScreen()
          : const ProfilesScreen();

      if (mounted) {
        setState(() {
          _app = MesutApp(start: start);
          _error = null;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _error = '$e\n\n$stack';
        });
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF171329),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _error == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFD6B35A),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Mesut IPTV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'جارٍ تجهيز التطبيق...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تعذر بدء Mesut IPTV',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'المرحلة: $_stage',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 240,
                          ),
                          padding: const EdgeInsets.all(10),
                          color: Colors.black26,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _error!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _initialize,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
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
        supportedLocales: const [
          Locale('ar'),
          Locale('fr'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(
            primary: kViolet,
            secondary: kGold,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          chipTheme: ChipThemeData(
            selectedColor: kViolet,
            backgroundColor: Colors.white10,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        home: start,
      ),
    );
  }
}
