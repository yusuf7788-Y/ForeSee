import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemePickerPanel extends StatefulWidget {
  final List<AppTheme> themes;
  final int initialThemeIndex;

  const ThemePickerPanel({
    super.key,
    required this.themes,
    required this.initialThemeIndex,
  });

  @override
  State<ThemePickerPanel> createState() => _ThemePickerPanelState();
}

class _ThemePickerPanelState extends State<ThemePickerPanel> {
  late int _selectedThemeIndex;


  @override
  void initState() {
    super.initState();
    _selectedThemeIndex = widget.initialThemeIndex;
  }

  void _onDone() {
    Navigator.of(context).pop({
      'themeIndex': _selectedThemeIndex,
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: widget.themes.length,
                  itemBuilder: (context, index) {
                    final theme = widget.themes[index];
                    final isSelected = index == _selectedThemeIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedThemeIndex = index;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.white24,
                            width: isSelected ? 3 : 1,
                          ),
                          // Sistem teması için dinamik önizleme
                          color: theme.name == 'Sistem'
                              ? (MediaQuery.of(context).platformBrightness == Brightness.dark
                                  ? const Color(0xFF000000) // Saf siyah
                                  : const Color(0xFFFFFFFF)) // Beyaz
                              : theme.backgroundColor,
                        ),
                        child: Center(
                          child: Text(
                            theme.name,
                            style: TextStyle(
                              // Sistem teması için dinamik metin rengi
                              color: theme.name == 'Sistem'
                                  ? (MediaQuery.of(context).platformBrightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black)
                                  : (theme.brightness == Brightness.dark ? Colors.white : Colors.black),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text('Tema & Renkler', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton(
          onPressed: _onDone,
          child: Text('Bitti', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16)),
        ),
      ],
    );
  }
}
