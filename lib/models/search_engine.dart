class SearchEngine {
  final String id;
  final String name;
  final String icon;
  final String baseUrl;

  const SearchEngine({
    required this.id,
    required this.name,
    required this.icon,
    required this.baseUrl,
  });

  @override
  String toString() => name;
}
