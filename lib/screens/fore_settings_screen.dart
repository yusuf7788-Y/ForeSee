import 'package:flutter/material.dart';
import '../services/fore_settings_service.dart';

class ForeSettingsScreen extends StatefulWidget {
  const ForeSettingsScreen({super.key});

  @override
  State<ForeSettingsScreen> createState() => _ForeSettingsScreenState();
}

class _ForeSettingsScreenState extends State<ForeSettingsScreen> {
  bool _isLoading = true;
  Map<String, bool> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ForeSettingsService.loadSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    await ForeSettingsService.updateSetting(key, value);
    setState(() {
      _settings[key] = value;
    });
  }

  Widget _buildSettingTile(String title, String subtitle, String key) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      value: _settings[key] ?? false,
      onChanged: (value) => _updateSetting(key, value),
      activeColor: Colors.blue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'ForWeb Ayarları',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Genel Ayarlar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSettingTile(
                        'JavaScript',
                        'Sitelerin JavaScript çalıştırmasına izin ver',
                        'javascript',
                      ),
                      _buildSettingTile(
                        'Otomatik Oynatma',
                        'Videoları otomatik oynat',
                        'autoplay',
                      ),
                      _buildSettingTile(
                        'Resim Yükleme',
                        'Resimleri otomatik yükle',
                        'images',
                      ),
                      _buildSettingTile(
                        'Pop-up\'ları Engelle',
                        'Pop-up pencereleri engelle',
                        'popups',
                      ),
                      _buildSettingTile(
                        'Konum Servisi',
                        'Konum servislerini kullan',
                        'location',
                      ),
                      _buildSettingTile(
                        'Kamera Erişimi',
                        'Kamera erişimine izin ver',
                        'camera',
                      ),
                      _buildSettingTile(
                        'Mikrofon Erişimi',
                        'Mikrofon erişimine izin ver',
                        'microphone',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
