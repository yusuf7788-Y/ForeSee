import '../models/search_engine.dart';

class SearchService {
  static const List<SearchEngine> _searchEngines = [
    SearchEngine(
      id: 'google',
      name: 'Google',
      icon: '🔍',
      baseUrl: 'https://www.google.com/search?q=',
    ),
    SearchEngine(
      id: 'duckduckgo',
      name: 'DuckDuckGo',
      icon: '🦆',
      baseUrl: 'https://duckduckgo.com/?q=',
    ),
    SearchEngine(
      id: 'bing',
      name: 'Bing',
      icon: '🔷',
      baseUrl: 'https://www.bing.com/search?q=',
    ),
  ];

  static Future<List<SearchEngine>> getSearchEngines() async {
    return Future.value(_searchEngines);
  }

  static Future<SearchEngine> getDefaultEngine() async {
    return Future.value(_searchEngines.first);
  }

  static String buildSearchUrl(SearchEngine engine, String query) {
    return '${engine.baseUrl}$query';
  }

  static Future<void> setDefaultEngine(String engineId) async {
    // Implementation for setting default engine
  }
}
