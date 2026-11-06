import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'store.dart';
import 'xtream_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  Future<void> _login() async {
    var url = _url.text.trim();
    var user = _user.text.trim();
    var pass = _pass.text;

    // دعم لصق رابط M3U الكامل (get.php?username=..&password=..)
    final u = Uri.tryParse(url);
    if (u != null &&
        u.queryParameters.containsKey('username') &&
        u.queryParameters.containsKey('password')) {
      user = u.queryParameters['username']!;
      pass = u.queryParameters['password']!;
      url = '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
    }

    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'املأ رابط السيرفر واسم المستخدم وكلمة المرور');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = XtreamService(url, user, pass, _name.text.trim());
    try {
      await s.login();
      await Store.addAccount(s.toAccount());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(service: s)),
        (r) => false,
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _dec(String label, IconData icon, [Widget? suffix]) =>
      InputDecoration(
        labelText: tr(label),
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kGold, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: Navigator.canPop(context) ? AppBar() : null,
      body: Container(
        decoration: kBgGradient,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassBox(
                radius: 28,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [kViolet, kGold]),
                      ),
                      child: const Icon(Icons.live_tv_rounded,
                          size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text('Mesut IPTV',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('سجّل الدخول بحساب الاشتراك',
                        style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _name,
                      decoration: _dec('اسم الحساب (اختياري)', Icons.badge_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      decoration: _dec('رابط السيرفر أو رابط M3U', Icons.dns_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      textDirection: TextDirection.ltr,
                      decoration: _dec('اسم المستخدم', Icons.person_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: _hide,
                      textDirection: TextDirection.ltr,
                      decoration: _dec(
                        'كلمة المرور',
                        Icons.lock_rounded,
                        IconButton(
                          icon: Icon(_hide
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        onPressed: _busy ? null : _login,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('تسجيل الدخول',
                                style: TextStyle(fontSize: 17)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
