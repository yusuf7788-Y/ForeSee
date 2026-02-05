import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'grey_notification.dart';

class FullscreenImageViewer extends StatefulWidget {
  final String imageData; // Base64 veya file path
  final String? heroTag;

  const FullscreenImageViewer({
    super.key,
    required this.imageData,
    this.heroTag,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: widget.heroTag ?? 'image_${widget.imageData.hashCode}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate safe area for the image
                    // Leave space for top bar (~80px) and bottom buttons (~120px)
                    final availableHeight =
                        MediaQuery.of(context).size.height - 200;

                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: availableHeight,
                        maxWidth: MediaQuery.of(context).size.width,
                      ),
                      child: _buildImage(),
                    );
                  },
                ),
              ),
            ),
          ),

          // Üst bar - Kapat butonu
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),

          // Alt bar - Kaydet ve Paylaş butonları
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Kaydet butonu
                    _buildActionButton(
                      icon: Icons.download,
                      label: 'Kaydet',
                      onTap: _isLoading ? null : _saveImage,
                      isDarkMode: isDarkMode,
                    ),
                    // Paylaş butonu
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'Paylaş',
                      onTap: _isLoading ? null : _shareImage,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.5)
                  : Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<Uint8List?> _getImageBytes() async {
    try {
      if (widget.imageData.startsWith('data:image')) {
        final parts = widget.imageData.split(',');
        if (parts.length < 2) return null;
        String base64String = parts[1].trim();
        base64String = base64String.replaceAll(RegExp(r'\s'), '');
        return base64Decode(base64String);
      } else {
        final file = File(widget.imageData);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Widget _buildImage() {
    if (widget.imageData.startsWith('data:image')) {
      return FutureBuilder<Uint8List?>(
        future: _getImageBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator(color: Colors.white);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _buildErrorWidget();
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          );
        },
      );
    } else {
      return Image.file(
        File(widget.imageData),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }
  }

  Widget _buildErrorWidget() {
    return Icon(
      Icons.broken_image_outlined,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white54
          : Colors.black45,
      size: 64,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ için photos izni, altı için storage izni
    if (Platform.isAndroid) {
      // Not: Modern Android versiyonlarında bazen permission gerekmez Scoped Storage için
      // ama Download klasörüne yazmak için gerekebilir.
      final status = await Permission.storage.request();
      if (status.isGranted) return true;

      // Android 13+ kontrolü (Tiramisu = 33)
      // plugin bazen storage iznini direkt red verebilir, manageExternalStorage gerekebilir
      // veya media permissions.
      if (await Permission.photos.request().isGranted) return true;
    }
    return false;
  }

  Future<void> _saveImage() async {
    if (!await _checkStoragePermission()) {
      _showPermissionDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageBytes = await _getImageBytes();
      if (imageBytes == null) throw Exception('Görsel verisi alınamadı');

      String fileName;
      if (widget.imageData.startsWith('data:image')) {
        fileName = 'foresee_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else {
        fileName = widget.imageData.split(Platform.pathSeparator).last;
      }

      String? savePath;
      if (Platform.isAndroid) {
        // Android 11+ için daha sağlam yaklaşım
        final List<Directory>? extDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (extDirs != null && extDirs.isNotEmpty) {
          // Bu uygulama özelindeki indirme klasörü yerine direkt /Download'a gitmeyi deneyelim
          final appDownloadPath = extDirs.first.path;
          savePath = '$appDownloadPath/$fileName';

          // Eğer /storage/emulated/0/Download erişilebilir ise orayı tercih edelim
          final publicDownload = Directory('/storage/emulated/0/Download');
          if (await publicDownload.exists()) {
            savePath = '${publicDownload.path}/$fileName';
          }
        }
      } else if (Platform.isIOS) {
        final docDir = await getApplicationDocumentsDirectory();
        savePath = '${docDir.path}/$fileName';
      } else {
        final downDir = await getDownloadsDirectory();
        if (downDir != null) savePath = '${downDir.path}/$fileName';
      }

      if (savePath == null)
        throw const FileSystemException('Kayıt konumu bulunamadı');

      final savedFile = File(savePath);
      await savedFile.writeAsBytes(imageBytes);

      if (mounted) {
        GreyNotification.show(context, 'Görsel kaydedildi');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum: $savePath'),
            backgroundColor: Colors.blueAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) GreyNotification.show(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: Text(
          'İzin Gerekli',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
        content: Text(
          'Görseli cihazınıza kaydetmek için depolama iznine ihtiyacımız var. Lütfen ayarlardan izni etkinleştirin.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text(
              'Ayarlar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _isLoading = true);

    try {
      final imageBytes = await _getImageBytes();
      if (imageBytes == null) throw Exception('Görsel verisi alınamadı');

      String fileName;
      if (widget.imageData.startsWith('data:image')) {
        fileName = 'share_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else {
        fileName = widget.imageData.split(Platform.pathSeparator).last;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      await Share.shareXFiles([XFile(tempFile.path)], text: 'ForeSee Görseli');

      // Not: Silme işlemi riskli olabilir çünkü paylaşım menüsü açıkken
      // arka planda silinirse bazı uygulamalar dosyayı okuyamaz.
      // Sistemin temp temizliğine bırakmak daha güvenli.
    } catch (e) {
      if (mounted) GreyNotification.show(context, 'Paylaşma hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
