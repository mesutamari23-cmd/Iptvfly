import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'ads.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'xtream_service.dart';
import 'live_screen.dart';
import 'media_grid_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'profiles_screen.dart';

class HomeScreen extends StatefulWidget {
  final XtreamService service;
  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Map<String, String>> _acc = widget.service.account();

  XtreamService get s => widget.service;

  Future<void> _push(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    if (mounted) setState(() {});
  }

  Widget _cards(bool wide) {
    final cards = <Widget>[
      _HomeCard(
        title: 'TV Direct',
        subtitle: 'البث المباشر',
        icon: Icons.live_tv_rounded,
        colors: const [Color(0xFF7C5CFF), Color(0xFF3B2A99)],
        onTap: () => _push(LiveScreen(service: s)),
      ),
      _HomeCard(
        title: 'Films',
        subtitle: 'الأفلام',
        icon: Icons.movie_rounded,
        colors: const [Color(0xFFE0A526), Color(0xFF8A5A00)],
        onTap: () => _push(MediaGridScreen(
          title: 'Films',
          type: 'vod',
          loadCats: s.vodCategories,
          loadItems: s.vodStreams,
          onOpen: (c, it) => Navigator.of(c).push<void>(MaterialPageRoute<void>(
              builder: (_) => MovieDetailScreen(service: s, item: it))),
        )),
      ),
      _HomeCard(
        title: 'Séries',
        subtitle: 'المسلسلات',
        icon: Icons.video_library_rounded,
        colors: const [Color(0xFF1FB5A0), Color(0xFF0B5C52)],
        onTap: () => _push(MediaGridScreen(
          title: 'Séries',
          type: 'series',
          loadCats: s.seriesCategories,
          loadItems: s.seriesList,
          onOpen: (c, it) => Navigator.of(c).push<void>(MaterialPageRoute<void>(
              builder: (_) => SeriesDetailScreen(service: s, item: it))),
        )),
      ),
    ];
    return wide ? Row(children: cards) : Column(children: cards);
  }

  Widget _continueRow() {
    final hist = Store.history();
    if (hist.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Text('متابعة المشاهدة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: hist.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final h = hist[i];
              final p = h.dur > 0 ? (h.pos / h.dur).clamp(0.0, 1.0) : 0.0;
              return SizedBox(
                width: 180,
                child: TvFocus(
                  radius: 14,
                  onTap: () => _push(PlayerScreen(items: [h.item])),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      h.item.image.isEmpty
                          ? Container(color: Colors.white10)
                          : Image.network(h.item.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.white10)),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      const Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              size: 34, color: Colors.white70)),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 10,
                        child: Text(h.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                            value: p, minHeight: 3, color: kGold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: kBgGradient,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.live_tv_rounded, color: kGold, size: 30),
                    const SizedBox(width: 10),
                    const Text('Mesut IPTV',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      tooltip: tr('تبديل الحساب'),
                      icon: const Icon(Icons.switch_account_rounded),
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
                        (r) => false,
                      ),
                    ),
                    IconButton(
                      tooltip: tr('الإعدادات'),
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () => _push(SettingsScreen(service: s)),
                    ),
                  ],
                ),
              ),
              _continueRow(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (_, box) => _cards(box.maxWidth >= 600),
                  ),
                ),
              ),
              const AdBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: GlassBox(
                  radius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: FutureBuilder<Map<String, String>>(
                    future: _acc,
                    builder: (_, snap) {
                      final a = snap.data;
                      return Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 20, color: kGold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s.name,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr),
                          ),
                          const Icon(Icons.event_rounded, size: 18, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(a == null ? '...' : '${tr('ينتهي')}: ${a['exp']}',
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 14),
                          const Icon(Icons.devices_rounded, size: 18, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(a == null ? '...' : '${a['conn']}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      );
                    },
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

class _HomeCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox.expand(
          child: TvFocus(
            radius: 24,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [colors[0].withOpacity(0.55), colors[1].withOpacity(0.35)],
                ),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(24),
              ),
              child: LayoutBuilder(
                builder: (_, box) {
                  final horizontal = box.maxWidth > box.maxHeight * 1.5;
                  final iconBox = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white12),
                    child: Icon(icon, size: 40, color: Colors.white),
                  );
                  final texts = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: Colors.white70)),
                    ],
                  );
                  if (horizontal) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        children: [
                          iconBox,
                          const SizedBox(width: 18),
                          texts,
                          const Spacer(),
                          Icon(
                              I18n.rtl
                                  ? Icons.chevron_left_rounded
                                  : Icons.chevron_right_rounded,
                              size: 30,
                              color: Colors.white54),
                        ],
                      ),
                    );
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [iconBox, const SizedBox(height: 10), texts],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
