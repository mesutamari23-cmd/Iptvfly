import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'utils.dart';
import 'xtream_service.dart';

/// مشغل الأفلام والمسلسلات (محرك mpv: يدعم mkv و avi وكل الترميزات)
class PlayerScreen extends StatefulWidget {
  final List<PlayItem> items;
  final int index;
  const PlayerScreen({super.key, required this.items, this.index = 0});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _p = Player();
  late final VideoController _vc = VideoController(_p);
  final List<StreamSubscription> _subs = [];
  late int _i = widget.index;

  bool _show = true, _loading = true, _playing = false;
  String? _err;
  Duration _pos = Duration.zero, _dur = Duration.zero;
  double? _drag;
  double _speed = 1;
  BoxFit _fit = BoxFit.contain;
  Timer? _hide, _saveTimer;
  int _tok = 0;

  PlayItem get _item => widget.items[_i];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _subs.addAll([
      _p.stream.position.listen((d) {
        final changed = d.inSeconds != _pos.inSeconds;
        _pos = d;
        if (changed && _show && mounted) setState(() {});
      }),
      _p.stream.duration.listen((d) {
        _dur = d;
        if (mounted) setState(() {});
      }),
      _p.stream.playing.listen((v) {
        _playing = v;
        if (mounted) setState(() {});
      }),
      _p.stream.buffering.listen((v) {
        _loading = v;
        if (mounted) setState(() {});
      }),
      _p.stream.completed.listen((done) {
        if (done) {
          _saveProgress();
          _next();
        }
      }),
      _p.stream.error.listen((e) {
        if (mounted && e.isNotEmpty) {
          setState(() {
            _loading = false;
            _err = 'تعذر تشغيل الفيديو';
          });
        }
      }),
    ]);

    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
    _open();
  }

  @override
  void dispose() {
    _saveProgress();
    _hide?.cancel();
    _saveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _p.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _open() async {
    final token = ++_tok;
    setState(() {
      _err = null;
      _loading = true;
      _pos = Duration.zero;
      _dur = Duration.zero;
    });
    try {
      await _p.open(
        Media(_item.url, httpHeaders: const {'User-Agent': kUserAgent}),
        play: true,
      );
      final saved = Store.position(_item.key);
      if (saved > 5000) {
        var d = _p.state.duration;
        if (d <= Duration.zero) {
          d = await _p.stream.duration
              .firstWhere((x) => x > Duration.zero)
              .timeout(const Duration(seconds: 20));
        }
        if (mounted && token == _tok && saved < d.inMilliseconds - 15000) {
          await _p.seek(Duration(milliseconds: saved));
        }
      }
      if (_speed != 1) await _p.setRate(_speed);
      _autoHide();
    } catch (_) {
      if (mounted && token == _tok) {
        setState(() {
          _loading = false;
          _err = 'تعذر تشغيل الفيديو';
        });
      }
    }
  }

  void _saveProgress() {
    if (_dur <= Duration.zero) return;
    Store.saveProgress(_item, _pos.inMilliseconds, _dur.inMilliseconds);
  }

  void _next() {
    if (_i + 1 < widget.items.length) {
      _i++;
      _open();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (_i > 0) {
      _saveProgress();
      _i--;
      _open();
    }
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing) setState(() => _show = false);
    });
  }

  void _toggleUi() {
    setState(() => _show = !_show);
    if (_show) _autoHide();
  }

  void _playPause() {
    _p.playOrPause();
    setState(() => _show = true);
    _autoHide();
  }

  void _seek(int seconds) {
    var t = _pos + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (_dur > Duration.zero && t > _dur) t = _dur;
    _p.seek(t);
    setState(() => _show = true);
    _autoHide();
  }

  void _cycleSpeed() {
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
    _speed = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    _p.setRate(_speed);
    setState(() {});
    _autoHide();
  }

  void _cycleFit() {
    setState(() {
      _fit = _fit == BoxFit.contain
          ? BoxFit.cover
          : _fit == BoxFit.cover
              ? BoxFit.fill
              : BoxFit.contain;
    });
    _autoHide();
  }

  @override
  Widget build(BuildContext context) {
    final total = max(1, _dur.inMilliseconds).toDouble();
    final pos = min(_pos.inMilliseconds.toDouble(), total);
    final multi = widget.items.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          final k = e.logicalKey;
          if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.mediaRewind) {
            _seek(-10);
            return KeyEventResult.handled;
          }
          if (k == LogicalKeyboardKey.arrowRight ||
              k == LogicalKeyboardKey.mediaFastForward) {
            _seek(10);
            return KeyEventResult.handled;
          }
          if (k == LogicalKeyboardKey.select ||
              k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.mediaPlayPause) {
            _playPause();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleUi,
          child: Stack(
            children: [
              Positioned.fill(
                child: Video(
                  controller: _vc,
                  controls: NoVideoControls,
                  fit: _fit,
                  fill: Colors.black,
                ),
              ),
              if (_loading && _err == null)
                const Center(child: CircularProgressIndicator()),
              if (_err != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: Colors.white54),
                      const SizedBox(height: 8),
                      Text(_err!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _open,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              if (_show) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(I18n.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(_item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            children: [
                              Text(mmss(_pos), style: const TextStyle(fontSize: 12)),
                              Expanded(
                                child: Slider(
                                  activeColor: kGold,
                                  value: _drag ?? pos,
                                  max: total,
                                  onChanged: (x) => setState(() => _drag = x),
                                  onChangeEnd: (x) {
                                    _p.seek(Duration(milliseconds: x.toInt()));
                                    setState(() => _drag = null);
                                    _autoHide();
                                  },
                                ),
                              ),
                              Text(mmss(_dur), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _cycleSpeed,
                                child: Text('${_speed}x'),
                              ),
                              if (multi)
                                IconButton(
                                  iconSize: 32,
                                  icon: const Icon(Icons.skip_previous_rounded),
                                  onPressed: _i > 0 ? _prev : null,
                                ),
                              IconButton(
                                iconSize: 32,
                                icon: const Icon(Icons.replay_10_rounded),
                                onPressed: () => _seek(-10),
                              ),
                              IconButton(
                                iconSize: 52,
                                color: kGold,
                                icon: Icon(_playing
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded),
                                onPressed: _playPause,
                              ),
                              IconButton(
                                iconSize: 32,
                                icon: const Icon(Icons.forward_10_rounded),
                                onPressed: () => _seek(10),
                              ),
                              if (multi)
                                IconButton(
                                  iconSize: 32,
                                  icon: const Icon(Icons.skip_next_rounded),
                                  onPressed:
                                      _i + 1 < widget.items.length ? _next : null,
                                ),
                              IconButton(
                                icon: const Icon(Icons.aspect_ratio_rounded),
                                onPressed: _cycleFit,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
