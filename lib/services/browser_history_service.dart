import 'package:shared_preferences/shared_preferences.dart';

class BrowserHistory {
  final String url;
  final String title;
  final DateTime timestamp;
  final String favicon;

  BrowserHistory({
    required this.url,
    required this.title,
    required this.timestamp,
    this.favicon = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'timestamp': timestamp.toIso8601String(),
      'favicon': favicon,
    };
  }

  factory BrowserHistory.fromJson(Map<String, dynamic> json) {
    return BrowserHistory(
      url: json['url'],
      title: json['title'],
      timestamp: DateTime.parse(json['timestamp']),
      favicon: json['favicon'] ?? '',
    );
  }
}

class BrowserHistoryService {
  static const String _historyKey = 'browser_history';
  static const int _maxHistoryItems = 1000;

  static Future<List<BrowserHistory>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      
      final history = historyJson
          .map((json) => BrowserHistory.fromJson(
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

      // Tarihe göre sırala (en yeni üstte)
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return history;
    } catch (e) {
      return [];
    }
  }

  static Future<void> addToHistory(String url, String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();

      // Aynı URL varsa eskisini kaldır
      history.removeWhere((item) => item.url == url);

      // Yeni ekle
      final newHistory = BrowserHistory(
        url: url,
        title: title.isNotEmpty ? title : url,
        timestamp: DateTime.now(),
      );

      history.insert(0, newHistory);

      // Maksimum sayıyı koru
      if (history.length > _maxHistoryItems) {
        history.removeRange(_maxHistoryItems, history.length);
      }

      // Kaydet
      final historyJson = history.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_historyKey, historyJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> deleteHistoryItem(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();
      history.removeWhere((item) => item.url == url);
      
      final historyJson = history.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_historyKey, historyJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<List<BrowserHistory>> searchHistory(String query) async {
    final history = await getHistory();
    final lowerQuery = query.toLowerCase();
    
    return history.where((item) =>
        item.title.toLowerCase().contains(lowerQuery) ||
        item.url.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}
