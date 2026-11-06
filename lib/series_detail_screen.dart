import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'xtream_service.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final XtreamService service;
  final MediaItem item;
  const SeriesDetailScreen({super.key, required this.service, required this.item});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  Map<int, List<Episode>>? _eps;
  int _season = 1;
  String? _error;
  late bool _fav = Store.isFav('series', widget.item.id);

  @override
  void initState() {
    super.initState();
    widget.service.seriesEpisodes(widget.item.id).then((m) {
      if (!mounted) return;
      final keys = m.keys.toList()..sort();
      setState(() {
        _eps = m;
        if (keys.isNotEmpty) _season = keys.first;
      });
    }).catchError((_) {
      if (mounted) setState(() => _error = 'تعذر تحميل الحلقات');
    });
  }

  Future<void> _toggleFav() async {
    final v = await Store.toggleFav('series', widget.item);
    if (mounted) setState(() => _fav = v);
  }

  Future<void> _play(List<Episode> list, int index) async {
    final it = widget.item;
    final items = list.map((e) {
      final t = e.title.isEmpty ? '${tr('الحلقة')} ${e.number}' : e.title;
      return PlayItem('ep_${e.id}', '${it.name} - $t',
          widget.service.episodeUrl(e.id, e.ext), it.image);
    }).toList();
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(items: items, index: index)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
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
        child: _error != null
            ? Center(child: Text(_error!))
            : _eps == null
                ? const Center(child: CircularProgressIndicator())
                : _body(it),
      ),
    );
  }

  Widget _body(MediaItem it) {
    final seasons = _eps!.keys.toList()..sort();
    final list = List<Episode>.of(_eps![_season] ?? []);
    list.sort((a, b) => a.number.compareTo(b.number));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 90,
                  height: 130,
                  child: it.image.isEmpty
                      ? Container(color: Colors.white10)
                      : Image.network(it.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.white10)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  it.plot.isEmpty ? 'لا يوجد وصف' : it.plot,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text('${tr('الموسم')} ${seasons[i]}'),
              selected: seasons[i] == _season,
              onSelected: (_) => setState(() => _season = seasons[i]),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final e = list[i];
              final title = e.title.isEmpty ? '${tr('الحلقة')} ${e.number}' : e.title;
              final pos = Store.position('ep_${e.id}');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TvFocus(
                  radius: 14,
                  onTap: () => _play(list, i),
                  child: Container(
                    color: Colors.white10,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: kViolet,
                          child: Text('${e.number}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (pos > 5000)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('متابعة',
                                style: TextStyle(color: kGold, fontSize: 12)),
                          ),
                        const Icon(Icons.play_circle_fill_rounded, color: kGold),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
