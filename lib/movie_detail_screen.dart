import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'utils.dart';
import 'xtream_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final XtreamService service;
  final MediaItem item;
  const MovieDetailScreen({super.key, required this.service, required this.item});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Map<String, String>? _info;
  late bool _fav = Store.isFav('vod', widget.item.id);

  String get _key => 'vod_${widget.item.id}';

  @override
  void initState() {
    super.initState();
    widget.service.vodInfo(widget.item.id).then((m) {
      if (mounted) setState(() => _info = m);
    }).catchError((_) {});
  }

  Future<void> _play() async {
    final it = widget.item;
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(items: [
        PlayItem(_key, it.name, widget.service.movieUrl(it.id, it.extra), it.image),
      ]),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _toggleFav() async {
    final v = await Store.toggleFav('vod', widget.item);
    if (mounted) setState(() => _fav = v);
  }

  Widget _line(IconData icon, String? t) {
    if (t == null || t.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kGold),
          const SizedBox(width: 6),
          Expanded(child: Text(t, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final i = _info;
    final pos = Store.position(_key);
    final plot = (i?['plot'] ?? '').isEmpty ? 'لا يوجد وصف' : i!['plot']!;
    final r = double.tryParse(it.rating) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(it.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_fav ? Icons.star_rounded : Icons.star_border_rounded,
                color: _fav ? kGold : null),
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: Container(
        decoration: kBgGradient,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 120,
                      height: 180,
                      child: it.image.isEmpty
                          ? Container(color: Colors.white10)
                          : Image.network(it.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.white10)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        if (r > 0) _line(Icons.star_rounded, r.toStringAsFixed(1)),
                        _line(Icons.category_rounded, i?['genre']),
                        _line(Icons.schedule_rounded, i?['duration']),
                        _line(Icons.calendar_month_rounded, i?['year']),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _play,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    pos > 5000
                        ? '${tr('متابعة من')} ${mmss(Duration(milliseconds: pos))}'
                        : 'تشغيل',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(plot, style: const TextStyle(height: 1.6, color: Colors.white70)),
              const SizedBox(height: 14),
              if ((i?['cast'] ?? '').isNotEmpty)
                Text('${tr('الممثلون')}: ${i!['cast']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              if ((i?['director'] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${tr('المخرج')}: ${i!['director']}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
