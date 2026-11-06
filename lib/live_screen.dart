import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'utils.dart';
import 'xtream_service.dart';

class LiveScreen extends StatefulWidget {
  final XtreamService service;
  const LiveScreen({super.key, required this.service});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  static const _favCat = Category('__fav__', '⭐ المفضلة');

  List<Category> _cats = [];
  List<MediaItem> _channels = [];
  List<MediaItem> _favs = [];
  List<Epg> _epg = [];
  Category? _cat;
  MediaItem? _current;
  VideoPlayerController? _ctrl;
  bool _loadingList = true, _loadingVideo = false, _full = false, _search = false;
  bool _ov = true;
  String? _error;
  String _q = '';
  final _sc = TextEditingController();
  Timer? _ovTimer;
  int _token = 0, _retries = 0;

  List<MediaItem> get _shown {
    if (_q.isEmpty) return _channels;
    final q = _q.toLowerCase();
    return _channels.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  @override
  void dispose() {
    _ovTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ctrl?.removeListener(_onVideo);
    _ctrl?.dispose();
    _sc.dispose();
    super.dispose();
  }

  // ---------- واجهة التحكم فوق الفيديو ----------
  void _pokeOv() {
    _ovTimer?.cancel();
    if (!_ov && mounted) setState(() => _ov = true);
    _ovTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_ctrl?.value.isPlaying ?? false)) setState(() => _ov = false);
    });
  }

  void _toggleOv() {
    if (_ov) {
      _ovTimer?.cancel();
      setState(() => _ov = false);
    } else {
      _pokeOv();
    }
  }

  Future<void> _setFull(bool v) async {
    setState(() => _full = v);
    if (v) {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _zap(int d) {
    final list = _shown;
    if (list.isEmpty || _current == null) return;
    final i = list.indexWhere((c) => c.id == _current!.id);
    if (i < 0) return;
    _play(list[(i + d + list.length) % list.length]);
  }

  Future<void> _toggleFav(MediaItem ch) async {
    await Store.toggleFav('live', ch);
    if (!mounted) return;
    setState(() {
      _favs = Store.favs('live');
      if (_cat?.id == _favCat.id) _channels = List.of(_favs);
    });
  }

  // ---------- التحميل ----------
  Future<void> _loadCats() async {
    try {
      _favs = Store.favs('live');
      final c = await widget.service.liveCategories();
      if (!mounted) return;
      setState(() => _cats = c);
      if (c.isNotEmpty) {
        await _selectCat(c.first, check: false);
      } else {
        setState(() => _loadingList = false);
      }
      final last = Store.lastLive();
      if (last != null && mounted) _play(last);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingList = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _selectCat(Category c, {bool check = true}) async {
    if (check && isAdult(c.name) && Store.pin != null) {
      if (!await askPin(context)) return;
    }
    if (c.id == _favCat.id) {
      setState(() {
        _cat = c;
        _channels = List.of(_favs);
        _loadingList = false;
      });
      return;
    }
    setState(() {
      _cat = c;
      _loadingList = true;
    });
    try {
      final ch = await widget.service.liveStreams(c.id);
      if (!mounted || _cat?.id != c.id) return;
      setState(() {
        _channels = ch;
        _loadingList = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  // إعادة اتصال تلقائية عند انقطاع البث
  void _onVideo() {
    final c = _ctrl;
    if (c == null || !mounted) return;
    if (c.value.hasError && _current != null && _retries < 3) {
      c.removeListener(_onVideo);
      _retries++;
      final ch = _current!;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _current?.id == ch.id) _play(ch, auto: true);
      });
    }
  }

  Future<void> _play(MediaItem ch, {bool auto = false}) async {
    if (!auto) _retries = 0;
    final token = ++_token;
    final old = _ctrl;
    old?.removeListener(_onVideo);
    setState(() {
      _current = ch;
      _loadingVideo = true;
      _error = null;
      _ctrl = null;
      _epg = [];
    });
    await old?.dispose();

    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.service.liveUrl(ch.id)),
      httpHeaders: const {'User-Agent': kUserAgent},
    );
    try {
      await c.initialize();
      if (token != _token || !mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideo);
      await c.play();
      WakelockPlus.enable();
      Store.saveLast(ch);
      setState(() {
        _ctrl = c;
        _loadingVideo = false;
      });
      _pokeOv();
      _loadEpg(ch);
    } catch (_) {
      await c.dispose();
      if (token == _token && mounted) {
        if (_retries < 3) {
          _retries++;
          setState(() => _error = 'إعادة المحاولة...');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _current?.id == ch.id && token == _token) {
              _play(ch, auto: true);
            }
          });
        } else {
          setState(() {
            _loadingVideo = false;
            _error = 'تعذر تشغيل القناة';
          });
        }
      }
    }
  }

  Future<void> _loadEpg(MediaItem ch) async {
    try {
      final l = await widget.service.shortEpg(ch.id);
      if (mounted && _current?.id == ch.id) setState(() => _epg = l);
    } catch (_) {}
  }

  // ---------- عناصر الواجهة ----------
  Widget _player() {
    if (_loadingVideo) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          if (_current != null) ...[
            const SizedBox(height: 12),
            Text(_current!.name, style: const TextStyle(color: Colors.white70)),
          ],
        ],
      );
    }
    if (_ctrl != null && _ctrl!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _ctrl!.value.aspectRatio == 0 ? 16 / 9 : _ctrl!.value.aspectRatio,
        child: VideoPlayer(_ctrl!),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_error == null ? Icons.live_tv_rounded : Icons.error_outline_rounded,
            size: 42, color: Colors.white24),
        const SizedBox(height: 8),
        Text(_error ?? 'اختر قناة للتشغيل',
            style: const TextStyle(color: Colors.white54)),
      ],
    );
  }

  Widget _liveBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
        child: const Text('LIVE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _videoArea(double h) {
    final cur = _current;
    final fav = cur != null && _favs.any((f) => f.id == cur.id);
    return GestureDetector(
      onTap: _toggleOv,
      child: Container(
        height: h,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: Center(child: _player())),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_ov,
                child: AnimatedOpacity(
                  opacity: _ov ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 6, 22),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black87, Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              if (cur != null) _liveBadge(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(cur?.name ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              if (cur != null)
                                IconButton(
                                  icon: Icon(
                                    fav ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: fav ? kGold : Colors.white,
                                  ),
                                  onPressed: () => _toggleFav(cur),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 18, 6, 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.skip_previous_rounded, size: 28),
                                  onPressed: () => _zap(-1),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded, size: 28),
                                  onPressed: () => _zap(1),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen_rounded, size: 30),
                                  onPressed: () => _setFull(true),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _epgStrip() {
    if (_epg.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final cur = _epg.firstWhere(
      (e) => e.start.isBefore(now) && e.end.isAfter(now),
      orElse: () => _epg.first,
    );
    final idx = _epg.indexOf(cur);
    final next = idx + 1 < _epg.length ? _epg[idx + 1] : null;
    final total = cur.end.difference(cur.start).inSeconds;
    final p = total <= 0
        ? 0.0
        : (now.difference(cur.start).inSeconds / total).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [kViolet.withOpacity(0.25), Colors.transparent]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(cur.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              ),
              Text('${hm(cur.start)} - ${hm(cur.end)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: p, minHeight: 3, color: kGold, backgroundColor: Colors.white12),
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${tr('التالي')}: ${next.title} (${hm(next.start)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
            ),
        ],
      ),
    );
  }

  Widget _catTile(Category c) {
    final sel = c.id == _cat?.id;
    final locked = Store.pin != null && isAdult(c.name);
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: sel
            ? const LinearGradient(colors: [kViolet, Color(0xFF4B36B8)])
            : null,
        color: sel ? null : Colors.white.withOpacity(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          focusColor: kGold.withOpacity(0.25),
          onTap: () => _selectCat(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? Colors.white : Colors.white70,
                      )),
                ),
                if (locked) const Icon(Icons.lock_rounded, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _channelTile(MediaItem ch, int i) {
    final sel = ch.id == _current?.id;
    final fav = _favs.any((f) => f.id == ch.id);
    return Container(
      height: 62,
      margin: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: sel
            ? LinearGradient(
                colors: [kViolet.withOpacity(0.45), kViolet.withOpacity(0.10)])
            : null,
        color: sel ? null : Colors.white.withOpacity(0.05),
        border: Border.all(color: sel ? kGold.withOpacity(0.7) : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          focusColor: kGold.withOpacity(0.25),
          onTap: () => _play(ch),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Center(
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.white38)),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(4),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ch.image.isEmpty
                    ? const Icon(Icons.tv_rounded, color: Colors.white38)
                    : Image.network(
                        ch.image,
                        fit: BoxFit.contain,
                        cacheWidth: 96,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.tv_rounded, color: Colors.white38),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500)),
                    if (sel)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.graphic_eq_rounded, size: 14, color: kGold),
                            SizedBox(width: 4),
                            Text('يعرض الآن',
                                style: TextStyle(fontSize: 11, color: kGold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  fav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: fav ? kGold : Colors.white38,
                ),
                onPressed: () => _toggleFav(ch),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelList(List<MediaItem> shown) {
    Widget child;
    if (_loadingList) {
      child = const Center(child: CircularProgressIndicator());
    } else if (shown.isEmpty) {
      child = const Center(
          child: Text('لا توجد قنوات', style: TextStyle(color: Colors.white54)));
    } else {
      child = ListView.builder(
        itemExtent: 68,
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        itemCount: shown.length,
        itemBuilder: (_, i) => _channelTile(shown[i], i),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey('${_cat?.id}_${_loadingList}_$_q'),
        child: child,
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      title: _search
          ? TextField(
              controller: _sc,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                  hintText: tr('ابحث عن قناة...'), border: InputBorder.none),
            )
          : const Text('TV Direct'),
      actions: [
        IconButton(
          icon: Icon(_search ? Icons.close_rounded : Icons.search_rounded),
          onPressed: () => setState(() {
            _search = !_search;
            _q = '';
            _sc.clear();
          }),
        ),
      ],
    );
  }

  Widget _fullView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          final k = e.logicalKey;
          if (k == LogicalKeyboardKey.arrowUp) {
            _zap(-1);
            return KeyEventResult.handled;
          }
          if (k == LogicalKeyboardKey.arrowDown) {
            _zap(1);
            return KeyEventResult.handled;
          }
          if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
            _setFull(false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setFull(false),
          onVerticalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) _zap(1);
            if (v > 200) _zap(-1);
          },
          child: Stack(
            children: [
              SizedBox.expand(child: Center(child: _player())),
              if (_current != null)
                Positioned(
                  top: 16,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _liveBadge(),
                        const SizedBox(width: 8),
                        Text(_current!.name),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _normalView() {
    final size = MediaQuery.of(context).size;
    final videoH = min(size.width * 9 / 16, size.height * 0.40);
    final cats = [_favCat, ..._cats];
    final shown = _shown;

    return Scaffold(
      appBar: _appBar(),
      body: Container(
        decoration: kBgGradient,
        child: Column(
          children: [
            _videoArea(videoH),
            _epgStrip(),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: min(135, size.width * 0.31),
                    color: Colors.black.withOpacity(0.18),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: cats.length,
                      itemBuilder: (_, i) => _catTile(cats[i]),
                    ),
                  ),
                  Expanded(child: _channelList(shown)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_full,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setFull(false);
      },
      child: _full ? _fullView() : _normalView(),
    );
  }
}
