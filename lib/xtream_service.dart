import 'dart:convert';
import 'package:http/http.dart' as http;
import 'i18n.dart';
import 'models.dart';
import 'store.dart';

const kUserAgent = 'VLC/3.0.18 LibVLC/3.0.18';

class XtreamService {
  final String baseUrl, username, password;
  final String name;

  XtreamService(String url, this.username, this.password, [String? name])
      : baseUrl = normalize(url),
        name = (name == null || name.isEmpty) ? username : name;

  factory XtreamService.fromAccount(Account a) =>
      XtreamService(a.url, a.user, a.pass, a.name);

  Account toAccount() => Account(name, baseUrl, username, password);

  static String normalize(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Uri _api([String? action, Map<String, String>? extra]) {
    final b = Uri.parse(baseUrl);
    return b.replace(
      path: '${b.path}/player_api.php',
      queryParameters: {
        'username': username,
        'password': password,
        if (action != null) 'action': action,
        ...?extra,
      },
    );
  }

  Future<dynamic> _get(Uri uri) async {
    final r = await http
        .get(uri, headers: {'User-Agent': kUserAgent})
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw Exception('${tr('خطأ من السيرفر')} (${r.statusCode})');
    }
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  List _asList(dynamic d) => d is List ? d : const [];

  // ---------- الحساب ----------
  Future<Map<String, dynamic>> login() async {
    final d = await _get(_api());
    final info = (d is Map) ? d['user_info'] : null;
    if (info == null || '${info['auth']}' != '1') {
      throw Exception(tr('بيانات الدخول غير صحيحة'));
    }
    if ('${info['status']}' != 'Active') {
      throw Exception('${tr('الاشتراك غير فعّال')} (${info['status']})');
    }
    return Map<String, dynamic>.from(d);
  }

  Future<Map<String, String>> account() async {
    final d = await login();
    final i = Map<String, dynamic>.from(d['user_info']);
    final exp = int.tryParse('${i['exp_date']}');
    final date = exp == null
        ? tr('غير محدود')
        : DateTime.fromMillisecondsSinceEpoch(exp * 1000).toString().substring(0, 10);
    return {'exp': date, 'conn': '${i['active_cons']}/${i['max_connections']}'};
  }

  // ---------- التصنيفات ----------
  Future<List<Category>> _cats(String action) async {
    final d = await _get(_api(action));
    return _asList(d)
        .map((e) => Category('${e['category_id']}', '${e['category_name']}'))
        .toList();
  }

  Future<List<Category>> liveCategories() => _cats('get_live_categories');
  Future<List<Category>> vodCategories() => _cats('get_vod_categories');
  Future<List<Category>> seriesCategories() => _cats('get_series_categories');

  // ---------- المحتوى ----------
  Future<List<MediaItem>> liveStreams(String categoryId) async {
    final d = await _get(_api('get_live_streams', {'category_id': categoryId}));
    return _asList(d)
        .map((e) => MediaItem('${e['stream_id']}', '${e['name']}',
            '${e['stream_icon'] ?? ''}', '',
            extra: '${e['category_id']}'))
        .toList();
  }

  Future<List<MediaItem>> vodStreams(String categoryId) async {
    final d = await _get(_api('get_vod_streams', {'category_id': categoryId}));
    return _asList(d)
        .map((e) => MediaItem('${e['stream_id']}', '${e['name']}',
            '${e['stream_icon'] ?? ''}', '${e['rating'] ?? ''}',
            extra: '${e['container_extension'] ?? 'mp4'}'))
        .toList();
  }

  Future<List<MediaItem>> seriesList(String categoryId) async {
    final d = await _get(_api('get_series', {'category_id': categoryId}));
    return _asList(d)
        .map((e) => MediaItem('${e['series_id']}', '${e['name']}',
            '${e['cover'] ?? ''}', '${e['rating'] ?? ''}',
            plot: '${e['plot'] ?? ''}'))
        .toList();
  }

  Future<Map<String, String>> vodInfo(String id) async {
    final d = await _get(_api('get_vod_info', {'vod_id': id}));
    final i = (d is Map && d['info'] is Map)
        ? Map<String, dynamic>.from(d['info'])
        : <String, dynamic>{};
    String s(String k) => '${i[k] ?? ''}';
    return {
      'plot': s('plot').isEmpty ? s('description') : s('plot'),
      'genre': s('genre'),
      'cast': s('cast').isEmpty ? s('actors') : s('cast'),
      'director': s('director'),
      'duration': s('duration'),
      'year': s('releasedate'),
    };
  }

  Future<Map<int, List<Episode>>> seriesEpisodes(String seriesId) async {
    final d = await _get(_api('get_series_info', {'series_id': seriesId}));
    final eps = (d is Map) ? d['episodes'] : null;
    final out = <int, List<Episode>>{};
    void add(dynamic list, int s) {
      for (final e in _asList(list)) {
        out.putIfAbsent(s, () => []).add(Episode(
            '${e['id']}',
            '${e['title'] ?? ''}',
            '${e['container_extension'] ?? 'mp4'}',
            s,
            int.tryParse('${e['episode_num']}') ?? 0));
      }
    }

    if (eps is Map) {
      eps.forEach((k, v) => add(v, int.tryParse('$k') ?? 1));
    } else if (eps is List) {
      for (var i = 0; i < eps.length; i++) {
        add(eps[i], i + 1);
      }
    }
    return out;
  }

  // ---------- دليل البرامج EPG ----------
  Future<List<Epg>> shortEpg(String streamId, {int limit = 3}) async {
    final d = await _get(
        _api('get_short_epg', {'stream_id': streamId, 'limit': '$limit'}));
    final l = d is Map ? _asList(d['epg_listings']) : const [];
    String dec(dynamic s) {
      try {
        return utf8.decode(base64.decode('$s'));
      } catch (_) {
        return '$s';
      }
    }

    return l.map((e) {
      final s = int.tryParse('${e['start_timestamp']}') ?? 0;
      final en = int.tryParse('${e['stop_timestamp']}') ?? 0;
      return Epg(dec(e['title']), dec(e['description']),
          DateTime.fromMillisecondsSinceEpoch(s * 1000),
          DateTime.fromMillisecondsSinceEpoch(en * 1000));
    }).toList();
  }

  // ---------- الروابط ----------
  String get _auth =>
      '${Uri.encodeComponent(username)}/${Uri.encodeComponent(password)}';
  String liveUrl(String id) => '$baseUrl/live/$_auth/$id.${Store.liveFormat}';
  String movieUrl(String id, String ext) => '$baseUrl/movie/$_auth/$id.$ext';
  String episodeUrl(String id, String ext) => '$baseUrl/series/$_auth/$id.$ext';
}
