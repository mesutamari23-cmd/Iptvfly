import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'store.dart';
import 'utils.dart';
import 'xtream_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profiles_screen.dart';

class SettingsScreen extends StatefulWidget {
  final XtreamService service;
  const SettingsScreen({super.key, required this.service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _goHome() {
    if (!mounted) return;
    final a = Store.active;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => a == null
            ? const LoginScreen()
            : HomeScreen(service: XtreamService.fromAccount(a)),
      ),
      (r) => false,
    );
  }

  Future<void> _switch(int i) async {
    await Store.setActive(i);
    _goHome();
  }

  Future<void> _remove(int i) async {
    await Store.removeAccount(i);
    _goHome();
  }

  Future<String?> _askNewPin(String title) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _setPin() async {
    if (Store.pin != null && !await askPin(context)) return;
    final p = await _askNewPin('رمز سري جديد (4 أرقام)');
    if (p == null) return;
    if (p.length != 4) {
      _toast('يجب أن يتكون الرمز من 4 أرقام');
      return;
    }
    await Store.setPin(p);
    if (mounted) setState(() {});
    _toast('تم حفظ الرمز السري');
  }

  Future<void> _removePin() async {
    if (!await askPin(context)) return;
    await Store.setPin(null);
    if (mounted) setState(() {});
    _toast('تم حذف الرمز السري');
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t,
            style: const TextStyle(
                color: kGold, fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _box(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final accs = Store.accounts();
    final act = Store.activeIndex;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: Container(
        decoration: kBgGradient,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _section('اللغة'),
            _box(Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {I18n.lang},
                  onSelectionChanged: (v) async {
                    await I18n.set(v.first);
                    _goHome();
                  },
                ),
              ),
            )),
            _section('الحسابات'),
            _box(ListTile(
              leading: const Icon(Icons.switch_account_rounded),
              title: const Text('تبديل الحساب'),
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
                (r) => false,
              ),
            )),
            for (var i = 0; i < accs.length; i++)
              _box(ListTile(
                leading: Icon(
                  i == act ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: i == act ? kGold : Colors.white54,
                ),
                title: Text(accs[i].name),
                subtitle: Text(accs[i].url, textDirection: TextDirection.ltr),
                onTap: i == act ? null : () => _switch(i),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _remove(i),
                ),
              )),
            _box(ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('إضافة حساب'),
              onTap: () => Navigator.of(context)
                  .push<void>(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
            )),
            _section('التشغيل'),
            _box(Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('صيغة البث المباشر'),
                  const SizedBox(height: 4),
                  const Text('جرّب m3u8 إذا كان ts لا يعمل مع سيرفرك',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ts', label: Text('TS')),
                      ButtonSegment(value: 'm3u8', label: Text('M3U8')),
                    ],
                    selected: {Store.liveFormat},
                    onSelectionChanged: (v) async {
                      await Store.setLiveFormat(v.first);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            )),
            _section('الحماية'),
            _box(ListTile(
              leading: const Icon(Icons.lock_rounded),
              title: Text(Store.pin == null ? 'تعيين رمز سري' : 'تغيير الرمز السري'),
              subtitle: const Text('يحمي التصنيفات المخصصة للكبار',
                  style: TextStyle(fontSize: 12)),
              onTap: _setPin,
            )),
            if (Store.pin != null)
              _box(ListTile(
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text('حذف الرمز السري'),
                onTap: _removePin,
              )),
            _section('البيانات'),
            _box(ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('مسح سجل المشاهدة'),
              onTap: () async {
                await Store.clearHistory();
                _toast('تم مسح السجل');
              },
            )),
            _box(ListTile(
              leading: const Icon(Icons.star_border_rounded),
              title: const Text('مسح المفضلة'),
              onTap: () async {
                await Store.clearFavs();
                _toast('تم مسح المفضلة');
              },
            )),
            const SizedBox(height: 20),
            const Center(
              child: Text('Mesut IPTV v5.0',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
