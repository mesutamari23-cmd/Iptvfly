import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'ads.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'utils.dart';

class MediaGridScreen extends StatefulWidget {
  final String title;
  final String type; // vod | series
  final Future<List<Category>> Function() loadCats;
  final Future<List<MediaItem>> Function(String) loadItems;
  final Future<void> Function(BuildContext, MediaItem) onOpen;
  const MediaGridScreen({
    super.key,
    required this.title,
    required this.type,
    required this.loadCats,
    required this.loadItems,
    required this.onOpen,
  });

  @override
  State<MediaGridScreen> createState() => _MediaGridScreenState();
}

class _MediaGridScreenState extends State<MediaGridScreen> {
  static const _favCat = Category('__fav__', '⭐ المفضلة');

  List<Category> _cats = [];
  List<MediaItem> _items = [];
  Category? _cat;
  bool _loading = true;
  String _q = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await widget.loadCats();
      if (!mounted) return;
      setState(() => _cats = [_favCat, ...c]);
      if (c.isNotEmpty) {
        await _select(c.first, check: false);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _select(Category c, {bool check = true}) async {
    if (check && isAdult(c.name) && Store.pin != null) {
      if (!await askPin(context)) return;
    }
    if (c.id == _favCat.id) {
      setState(() {
        _cat = c;
        _items = Store.favs(widget.type);
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _cat = c;
      _loading = true;
      _error = null;
    });
    try {
      final it = await widget.loadItems(c.id);
      if (!mounted || _cat?.id != c.id) return;
      setState(() {
        _items = it;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل المحتوى';
        });
      }
    }
  }

  Future<void> _open(MediaItem it) async {
    await Ads.maybeInterstitial();
    if (!mounted) return;
    await widget.onOpen(context, it);
    if (mounted && _cat?.id == _favCat.id) {
      setState(() => _items = Store.favs(widget.type));
    }
  }

  Future<void> _longPress(MediaItem it) async {
    final added = await Store.toggleFav(widget.type, it);
    if (!mounted) return;
    if (_cat?.id == _favCat.id) setState(() => _items = Store.favs(widget.type));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      content: Text(added ? 'أُضيف إلى المفضلة' : 'أُزيل من المفضلة'),
    ));
  }

  Widget _placeholder() => Container(
        color: Colors.white10,
        child: const Center(
            child: Icon(Icons.image_not_supported_rounded, color: Colors.white38)),
      );

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final shown = q.isEmpty
        ? _items
        : _items.where((e) => e.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Container(
        decoration: kBgGradient,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: tr('بحث...'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kGold, width: 2)),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _cats[i];
                  final locked = Store.pin != null && isAdult(c.name);
                  return ChoiceChip(
                    avatar: locked ? const Icon(Icons.lock_rounded, size: 14) : null,
                    label: Text(c.name),
                    selected: c.id == _cat?.id,
                    onSelected: (_) => _select(c),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('اضغط مطولاً على أي عنصر لإضافته للمفضلة',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : shown.isEmpty
                          ? const Center(
                              child: Text('لا يوجد محتوى',
                                  style: TextStyle(color: Colors.white54)))
                          : GridView.builder(
                              padding: const EdgeInsets.all(14),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150,
                                childAspectRatio: 0.64,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: shown.length,
                              itemBuilder: (_, i) {
                                final it = shown[i];
                                final r = double.tryParse(it.rating) ?? 0;
                                return TvFocus(
                                  radius: 14,
                                  onTap: () => _open(it),
                                  onLongPress: () => _longPress(it),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      it.image.isEmpty
                                          ? _placeholder()
                                          : Image.network(it.image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _placeholder()),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.fromLTRB(6, 18, 6, 6),
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black87
                                              ],
                                            ),
                                          ),
                                          child: Text(it.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      if (r > 0)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star_rounded,
                                                    size: 13, color: kGold),
                                                const SizedBox(width: 2),
                                                Text(r.toStringAsFixed(1),
                                                    style: const TextStyle(
                                                        fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
