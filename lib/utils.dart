import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'store.dart';

bool isAdult(String name) {
  final n = name.toLowerCase();
  return n.contains('xxx') ||
      n.contains('adult') ||
      n.contains('porn') ||
      n.contains('+18') ||
      n.contains('18+') ||
      n.contains('للكبار');
}

/// إذا كان هناك رمز سري يطلبه، وإلا يسمح مباشرة
Future<bool> askPin(BuildContext context) async {
  final pin = Store.pin;
  if (pin == null) return true;
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('أدخل الرمز السري'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text == pin),
            child: const Text('تأكيد')),
      ],
    ),
  );
  if (ok != true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('الرمز غير صحيح')));
  }
  return ok == true;
}

String hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String mmss(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0
      ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
      : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}
