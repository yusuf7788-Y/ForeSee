import 'package:shared_preferences/shared_preferences.dart';

class Bookmark {
  final String id;
  final String title;
  final String url;
  final String favicon;
  final DateTime createdAt;
  final int order;

  Bookmark({
    required this.id,
    required this.title,
    required this.url,
    this.favicon = '',
    required this.createdAt,
    this.order = 0,
  });

  Bookmark copyWith({
    String? id,
    String? title,
    String? url,
    String? favicon,
    DateTime? createdAt,
    int? order,
  }) {
    return Bookmark(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      favicon: favicon ?? this.favicon,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'favicon': favicon,
      'createdAt': createdAt.toIso8601String(),
      'order': order,
    };
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'],
      title: json['title'],
      url: json['url'],
      favicon: json['favicon'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      order: json['order'] ?? 0,
    );
  }
}

class BookmarksService {
  static const String _bookmarksKey = 'browser_bookmarks';

  static Future<List<Bookmark>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getStringList(_bookmarksKey) ?? [];
      
      final bookmarks = bookmarksJson
          .map((json) => Bookmark.fromJson(
                Map<String, dynamic>.from(
                  Uri.decodeComponent(json).split(',').fold(
                    <String, String>{},
                    (map, item) {
                      final parts = item.split('=');
                      if (parts.length == 2) {
                        map[parts[0]] = parts[1];
                      }
                      return map;
                    },
                  ),
                ),
              ))
          .toList();

      // Sıralama order'a göre
      bookmarks.sort((a, b) => a.order.compareTo(b.order));
      return bookmarks;
    } catch (e) {
      return [];
    }
  }

  static Future<void> addBookmark(String title, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await getBookmarks();
      
      final newBookmark = Bookmark(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isNotEmpty ? title : url,
        url: url,
        createdAt: DateTime.now(),
        order: bookmarks.length,
      );

      bookmarks.add(newBookmark);
      
      // Kaydet
      final bookmarksJson = bookmarks.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_bookmarksKey, bookmarksJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> deleteBookmark(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await getBookmarks();
      bookmarks.removeWhere((item) => item.id == id);
      
      // Sıralama düzenle
      for (int i = 0; i < bookmarks.length; i++) {
        bookmarks[i] = bookmarks[i].copyWith(order: i);
      }
      
      final bookmarksJson = bookmarks.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_bookmarksKey, bookmarksJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> reorderBookmarks(List<Bookmark> reorderedBookmarks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Sıralamayı güncelle
      for (int i = 0; i < reorderedBookmarks.length; i++) {
        reorderedBookmarks[i] = reorderedBookmarks[i].copyWith(order: i);
      }
      
      final bookmarksJson = reorderedBookmarks.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_bookmarksKey, bookmarksJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> clearAllBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bookmarksKey);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<List<Bookmark>> searchBookmarks(String query) async {
    final bookmarks = await getBookmarks();
    final lowerQuery = query.toLowerCase();
    
    return bookmarks.where((item) =>
        item.title.toLowerCase().contains(lowerQuery) ||
        item.url.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}
