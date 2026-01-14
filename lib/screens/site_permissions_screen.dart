import 'package:flutter/material.dart';
import '../services/site_permissions_service.dart';

class SitePermissionsScreen extends StatefulWidget {
  const SitePermissionsScreen({super.key});

  @override
  State<SitePermissionsScreen> createState() => _SitePermissionsScreenState();
}

class _SitePermissionsScreenState extends State<SitePermissionsScreen> {
  bool _isLoading = true;
  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    try {
      final permissions = await SitePermissionsManager.getPermissions();
      setState(() {
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePermission(String permission, bool value) async {
    await SitePermissionsManager.updatePermission(permission, value);
    setState(() {
      _permissions[permission] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'Site İzinleri',
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
                        'Site İzinleri',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Kamera', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Sitelerin kameraya erişimine izin ver', style: TextStyle(color: Colors.white54)),
                        value: _permissions['camera'] ?? false,
                        onChanged: (value) => _updatePermission('camera', value),
                        activeColor: Colors.blue,
                      ),
                      SwitchListTile(
                        title: const Text('Mikrofon', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Sitelerin mikrofona erişimine izin ver', style: TextStyle(color: Colors.white54)),
                        value: _permissions['microphone'] ?? false,
                        onChanged: (value) => _updatePermission('microphone', value),
                        activeColor: Colors.blue,
                      ),
                      SwitchListTile(
                        title: const Text('Konum', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Sitelerin konum bilgisine erişimine izin ver', style: TextStyle(color: Colors.white54)),
                        value: _permissions['location'] ?? false,
                        onChanged: (value) => _updatePermission('location', value),
                        activeColor: Colors.blue,
                      ),
                      SwitchListTile(
                        title: const Text('Bildirimler', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Sitelerin bildirim göndermesine izin ver', style: TextStyle(color: Colors.white54)),
                        value: _permissions['notifications'] ?? false,
                        onChanged: (value) => _updatePermission('notifications', value),
                        activeColor: Colors.blue,
                      ),
                      SwitchListTile(
                        title: const Text('Tam Ekran', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Sitelerin tam ekran modunu kullanmasına izin ver', style: TextStyle(color: Colors.white54)),
                        value: _permissions['fullscreen'] ?? false,
                        onChanged: (value) => _updatePermission('fullscreen', value),
                        activeColor: Colors.blue,
                      ),
                      SwitchListTile(
                        title: const Text('Pano', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Sitelerin panoya erişimine izin ver', style: TextStyle(color: Colors.white54)),
                        value: _permissions['clipboard'] ?? false,
                        onChanged: (value) => _updatePermission('clipboard', value),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
