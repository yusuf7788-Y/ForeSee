import 'package:shared_preferences/shared_preferences.dart';

class TabData {
  final String id;
  final String title;
  final String url;
  final String favicon;
  final DateTime createdAt;
  final bool isActive;

  TabData({
    required this.id,
    required this.title,
    required this.url,
    this.favicon = '',
    required this.createdAt,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'favicon': favicon,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory TabData.fromJson(Map<String, dynamic> json) {
    return TabData(
      id: json['id'],
      title: json['title'],
      url: json['url'],
      favicon: json['favicon'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? false,
    );
  }

  TabData copyWith({
    String? id,
    String? title,
    String? url,
    String? favicon,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return TabData(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      favicon: favicon ?? this.favicon,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class TabsService {
  static const String _tabsKey = 'browser_tabs';

  static Future<List<TabData>> getTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = prefs.getStringList(_tabsKey) ?? [];
      
      final tabs = tabsJson
          .map((json) => TabData.fromJson(
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

      // Aktif sekme en sona gelsin
      tabs.sort((a, b) {
        if (a.isActive == b.isActive) {
          return a.createdAt.compareTo(b.createdAt);
        }
        return a.isActive ? -1 : (b.isActive ? 1 : a.createdAt.compareTo(b.createdAt));
      });

      return tabs;
    } catch (e) {
      return [];
    }
  }

  static Future<void> addTab(String title, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabs = await getTabs();
      
      // Mevcut sekmeleri pasif yap
      final updatedTabs = tabs.map((tab) => tab.copyWith(isActive: false)).toList();
      
      final newTab = TabData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isNotEmpty ? title : url,
        url: url,
        createdAt: DateTime.now(),
        isActive: true,
      );

      updatedTabs.add(newTab);
      
      // Kaydet
      final tabsJson = updatedTabs.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_tabsKey, tabsJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> switchTab(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabs = await getTabs();
      
      final updatedTabs = tabs.map((tab) {
        return tab.copyWith(isActive: tab.id == tab.id);
      }).toList();
      
      final tabsJson = updatedTabs.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_tabsKey, tabsJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> closeTab(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabs = await getTabs();
      
      final updatedTabs = tabs.where((tab) => tab.id != tabId).toList();
      
      // Aktif sekme değişirse, en son sekmeyi aktif yap
      if (updatedTabs.isNotEmpty && !updatedTabs.any((tab) => tab.isActive)) {
        updatedTabs.last = updatedTabs.last.copyWith(isActive: true);
      }
      
      final tabsJson = updatedTabs.map((item) {
        final map = item.toJson();
        return Uri.encodeComponent(
          map.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
      }).toList();

      await prefs.setStringList(_tabsKey, tabsJson);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  static Future<void> clearAllTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tabsKey);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }
}
