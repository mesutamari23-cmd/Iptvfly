import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'models.dart';
import 'theme.dart';
import 'store.dart';
import 'xtream_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// شاشة الحسابات (مثل ملفات Netflix): كل حساب بطاقة + بطاقة فارغة لإضافة حساب جديد
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  bool _edit = false;

  static const _palette = [
    [Color(0xFF7C5CFF), Color(0xFF3B2A99)],
    [Color(0xFFE0A526), Color(0xFF8A5A00)],
    [Color(0xFF1FB5A0), Color(0xFF0B5C52)],
    [Color(0xFFE5484D), Color(0xFF8A1F24)],
    [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
  ];

  Future<void> _open(int i) async {
    await Store.setActive(i);
    final a = Store.active;
    if (!mounted || a == null) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => HomeScreen(service: XtreamService.fromAccount(a)),
    ));
  }

  Future<void> _add() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _delete(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text('هل تريد حذف هذا الحساب؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await Store.removeAccount(i);
    if (!mounted) return;
    if (Store.accounts().isEmpty) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
    } else {
      setState(() => _edit = Store.accounts().isEmpty ? false : _edit);
    }
  }

  Widget _tile(int i, Account a) {
    final c = _palette[i % _palette.length];
    final name = a.name.trim().isEmpty ? '?' : a.name.trim();
    final initial = String.fromCharCode(name.runes.first).toUpperCase();
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: TvFocus(
              radius: 20,
              onTap: () => _edit ? _delete(i) : _open(i),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: c,
                      ),
                    ),
                    child: Center(
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 46, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_edit)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                          child: Icon(Icons.delete_outline_rounded, size: 40)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _addTile() {
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: TvFocus(
              radius: 20,
              onTap: _add,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  border: Border.all(color: Colors.white24, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, size: 52, color: Colors.white70),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('إضافة حساب',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accs = Store.accounts();
    return Scaffold(
      body: Container(
        decoration: kBgGradient,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    if (accs.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _edit = !_edit),
                        child: Text(_edit ? 'تم' : 'إدارة الحسابات'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('من يشاهد؟',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 36),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 24,
                          runSpacing: 28,
                          children: [
                            for (var i = 0; i < accs.length; i++) _tile(i, accs[i]),
                            if (!_edit) _addTile(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
