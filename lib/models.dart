class Account {
  final String name, url, user, pass;
  const Account(this.name, this.url, this.user, this.pass);
  String get id => '$user@$url';
  Map<String, String> toJson() =>
      {'name': name, 'url': url, 'user': user, 'pass': pass};
  factory Account.fromJson(Map<String, dynamic> j) =>
      Account('${j['name']}', '${j['url']}', '${j['user']}', '${j['pass']}');
}

class Category {
  final String id, name;
  const Category(this.id, this.name);
}

class MediaItem {
  final String id, name, image, rating, extra, plot;
  const MediaItem(this.id, this.name, this.image, this.rating,
      {this.extra = '', this.plot = ''});
  Map<String, String> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'rating': rating,
        'extra': extra,
        'plot': plot,
      };
  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
      '${j['id']}', '${j['name']}', '${j['image']}', '${j['rating']}',
      extra: '${j['extra']}', plot: '${j['plot']}');
}

class Episode {
  final String id, title, ext;
  final int season, number;
  const Episode(this.id, this.title, this.ext, this.season, this.number);
}

class Epg {
  final String title, desc;
  final DateTime start, end;
  const Epg(this.title, this.desc, this.start, this.end);
}

class PlayItem {
  final String key, title, url, image;
  const PlayItem(this.key, this.title, this.url, [this.image = '']);
}

class HistoryEntry {
  final PlayItem item;
  final int pos, dur, ts;
  const HistoryEntry(this.item, this.pos, this.dur, this.ts);
}
