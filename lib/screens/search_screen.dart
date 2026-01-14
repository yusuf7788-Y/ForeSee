import "package:flutter/material.dart";
import "../models/search_engine.dart";
import "../services/search_service.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<SearchEngine> _searchEngines = [];
  SearchEngine? _selectedEngine;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSearchEngines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchEngines() async {
    try {
      final engines = await SearchService.getSearchEngines();
      final defaultEngine = await SearchService.getDefaultEngine();
      setState(() {
        _searchEngines = engines;
        _selectedEngine = defaultEngine;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(SearchEngine engine) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final url = SearchService.buildSearchUrl(engine, query);
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("Arama"),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Arama motoru seçici
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text(
                  "Arama Motoru:",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<SearchEngine>(
                    value: _selectedEngine,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A1A),
                    items: _searchEngines.map((engine) {
                      return DropdownMenuItem<SearchEngine>(
                        value: engine,
                        child: Row(
                          children: [
                            Text(
                              engine.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              engine.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (SearchEngine? engine) {
                      if (engine != null) {
                        setState(() {
                          _selectedEngine = engine;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Arama kutusu
          Container(
            margin: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "İnternette ara...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: const Icon(Icons.search, color: Colors.blue),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
              onSubmitted: (_) => _performSearch(_selectedEngine!),
            ),
          ),
        ],
      ),
    );
  }
}