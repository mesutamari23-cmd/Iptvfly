import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class Store {
  static late SharedPreferences _p;
  static const FlutterSecureStorage _vault = FlutterSecureStorage();
  static const String _accountsKey = 'secure_accounts_v1';
  static const String _pinKey = 'secure_parental_pin_v1';
  static const String _fallbackAccountsKey = '_fallback_secure_accounts_v1';
  static const String _fallbackPinKey = '_fallback_parental_pin_v1';

  static List<Account> _accountsCache = [];
  static String? _pinCache;
  static bool _vaultAvailable = true;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _accountsCache = [];
    _pinCache = null;
    _vaultAvailable = true;

    String? storedAccounts;
    try {
      storedAccounts = await _vault.read(key: _accountsKey);
    } catch (_) {
      _vaultAvailable = false;
    }
    storedAccounts ??= _p.getString(_fallbackAccountsKey);

    if (storedAccounts != null && storedAccounts.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedAccounts);
        if (decoded is List) {
          _accountsCache = decoded
              .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (_) {
        // Ignore corrupt stored data and try the legacy migration below.
        _accountsCache = [];
      }
    }

    if (_accountsCache.isEmpty) {
      final legacy = <Account>[];
      for (final s in (_p.getStringList('accounts') ?? <String>[])) {
        try {
          legacy.add(Account.fromJson(
              Map<String, dynamic>.from(jsonDecode(s) as Map)));
        } catch (_) {
          // Skip a damaged legacy account instead of crashing app startup.
        }
      }
      if (legacy.isNotEmpty) {
        _accountsCache = legacy;
      } else if (_p.getString('url') != null) {
        final u = _p.getString('user') ?? '';
        _accountsCache = [
          Account(
            u.isEmpty ? 'حسابي' : u,
            _p.getString('url')!,
            u,
            _p.getString('pass') ?? '',
          )
        ];
      }

      if (_accountsCache.isNotEmpty) {
        await _writeSecureAccounts();
      }
      await _p.remove('accounts');
      await _p.remove('url');
      await _p.remove('user');
      await _p.remove('pass');
    }

    try {
      _pinCache = await _vault.read(key: _pinKey);
    } catch (_) {
      _vaultAvailable = false;
    }
    _pinCache ??= _p.getString(_fallbackPinKey);
    if (_pinCache == null && _p.getString('pin') != null) {
      _pinCache = _p.getString('pin');
      await setPin(_pinCache);
      await _p.remove('pin');
    }
  }

  static String get lang => _p.getString('lang') ?? 'ar';
  static Future<void> setLang(String v) async {
    await _p.setString('lang', v);
  }

  static List<Account> accounts() => List.unmodifiable(_accountsCache);

  static Future<void> _writeSecureAccounts() async {
    final value =
        jsonEncode(_accountsCache.map((a) => a.toJson()).toList());
    if (_vaultAvailable) {
      try {
        await _vault.write(key: _accountsKey, value: value);
        await _p.remove(_fallbackAccountsKey);
        return;
      } catch (_) {
        _vaultAvailable = false;
      }
    }
    // Compatibility fallback for devices where Android Keystore is unavailable.
    // This fallback is not encrypted; secure storage remains the preferred path.
    await _p.setString(_fallbackAccountsKey, value);
  }

  static Account? get active {
    final l = accounts();
    if (l.isEmpty) return null;
    final i = _p.getInt('active') ?? 0;
    return l[i < 0 || i >= l.length ? 0 : i];
  }

  static int get activeIndex => _p.getInt('active') ?? 0;

  static Future<void> addAccount(Account a) async {
    final l = List<Account>.of(_accountsCache);
    final i = l.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      l[i] = a;
    } else {
      l.add(a);
    }
    _accountsCache = l;
    await _writeSecureAccounts();
    await _p.setInt('active', i >= 0 ? i : l.length - 1);
  }

  static Future<void> setActive(int i) async {
    await _p.setInt('active', i);
  }

  static Future<void> removeAccount(int i) async {
    final l = List<Account>.of(_accountsCache);
    if (i < 0 || i >= l.length) return;
    l.removeAt(i);
    _accountsCache = l;
    await _writeSecureAccounts();
    await _p.setInt('active', 0);
  }

  static String get _pre => '${active?.id ?? 'x'}|';

  static String get liveFormat => _p.getString('fmt') ?? 'ts';
  static Future<void> setLiveFormat(String v) async {
    await _p.setString('fmt', v);
  }

  static String? get pin => _pinCache;
  static Future<void> setPin(String? v) async {
    _pinCache = v;
    if (v == null || v.isEmpty) {
      try {
        await _vault.delete(key: _pinKey);
      } catch (_) {
        _vaultAvailable = false;
      }
      await _p.remove(_fallbackPinKey);
    } else if (_vaultAvailable) {
      try {
        await _vault.write(key: _pinKey, value: v);
        await _p.remove(_fallbackPinKey);
        return;
      } catch (_) {
        _vaultAvailable = false;
      }
      await _p.setString(_fallbackPinKey, v);
    } else {
      await _p.setString(_fallbackPinKey, v);
    }
  }

  static List<MediaItem> favs(String type) =>
      (_p.getStringList('${_pre}fav_$type') ?? [])
          .map((s) => MediaItem.fromJson(jsonDecode(s)))
          .toList();

  static bool isFav(String type, String id) =>
      favs(type).any((e) => e.id == id);

  static Future<bool> toggleFav(String type, MediaItem it) async {
    final l = favs(type);
    final i = l.indexWhere((e) => e.id == it.id);
    if (i >= 0) {
      l.removeAt(i);
    } else {
      l.add(it);
    }
    await _p.setStringList(
        '${_pre}fav_$type', l.map((e) => jsonEncode(e.toJson())).toList());
    return i < 0;
  }

  static MediaItem? lastLive() {
    final s = _p.getString('${_pre}last');
    if (s == null) return null;
    return MediaItem.fromJson(jsonDecode(s));
  }

  static Future<void> saveLast(MediaItem it) async {
    await _p.setString('${_pre}last', jsonEncode(it.toJson()));
  }

  static List<Map<String, dynamic>> _histRaw() =>
      (_p.getStringList('${_pre}hist') ?? [])
          .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
          .toList();

  static List<HistoryEntry> history() => _histRaw()
      .map((e) => HistoryEntry(
            PlayItem('${e['key']}', '${e['title']}', '${e['url']}',
                '${e['image']}'),
            (e['pos'] as num?)?.toInt() ?? 0,
            (e['dur'] as num?)?.toInt() ?? 0,
            (e['ts'] as num?)?.toInt() ?? 0,
          ))
      .toList();

  static int position(String key) {
    for (final e in _histRaw()) {
      if (e['key'] == key) return (e['pos'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static Future<void> saveProgress(PlayItem it, int pos, int dur) async {
    final l = _histRaw().where((e) => e['key'] != it.key).toList();
    final finished = dur > 0 && pos > dur * 0.95;
    if (!finished && pos > 3000) {
      l.insert(0, {
        'key': it.key,
        'title': it.title,
        'url': it.url,
        'image': it.image,
        'pos': pos,
        'dur': dur,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _p.setStringList(
        '${_pre}hist', l.take(30).map((e) => jsonEncode(e)).toList());
  }

  static Future<void> clearHistory() async {
    await _p.remove('${_pre}hist');
  }

  static Future<void> clearFavs() async {
    for (final t in ['live', 'vod', 'series']) {
      await _p.remove('${_pre}fav_$t');
    }
  }
}
