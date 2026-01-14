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
          // Tam ekran görsel
          Center(
            child: Hero(
              tag: widget.heroTag ?? 'image_${widget.imageData.hashCode}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: _buildImage(),
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
              color: isDarkMode ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.3),
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

  Widget _buildImage() {
    if (widget.imageData.startsWith('data:image')) {
      // Base64 görsel
      try {
        final parts = widget.imageData.split(',');
        if (parts.length < 2) {
          throw const FormatException('Eksik base64 verisi');
        }
        String base64String = parts[1].trim();
        base64String = base64String.replaceAll(RegExp(r'\s'), '');
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high, // Tam ekranda yüksek kalite
          isAntiAlias: true,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.error, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, size: 64);
          },
        );
      } catch (e) {
        GreyNotification.show(
          context,
          'Görsel çözümlenemedi (geçersiz format).',
        );
        return Icon(Icons.error, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, size: 64);
      }
    } else {
      // Dosya yolu
      return Image.file(
        File(widget.imageData),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.error, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, size: 64);
        },
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDarkMode ? Colors.white : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage() async {
    setState(() => _isLoading = true);

    try {
      Uint8List imageBytes;
      String fileName;

      if (widget.imageData.startsWith('data:image')) {
        // Base64 görsel
        final parts = widget.imageData.split(',');
        if (parts.length < 2) {
          throw const FormatException('Eksik base64 verisi');
        }
        String base64String = parts[1].trim();
        base64String = base64String.replaceAll(RegExp(r'\s'), '');
        imageBytes = base64Decode(base64String);
        fileName = 'foresee_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else {
        // Dosya yolu
        final file = File(widget.imageData);
        imageBytes = await file.readAsBytes();
        fileName = file.path.split('/').last;
      }

      // İzin isteği
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        GreyNotification.show(context, 'Depolama izni reddedildi');
        return;
      }

      // Kaydet
      final directory = await getDownloadsDirectory();
      final savedFile = File('${directory!.path}/$fileName');
      await savedFile.writeAsBytes(imageBytes);

      GreyNotification.show(context, 'Görsel kaydedildi: ${savedFile.path}');
    } catch (e) {
      GreyNotification.show(context, 'Kaydetme hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isLoading = true);

    try {
      Uint8List imageBytes;
      String fileName;

      if (widget.imageData.startsWith('data:image')) {
        // Base64 görsel
        final parts = widget.imageData.split(',');
        if (parts.length < 2) {
          throw const FormatException('Eksik base64 verisi');
        }
        String base64String = parts[1].trim();
        base64String = base64String.replaceAll(RegExp(r'\s'), '');
        imageBytes = base64Decode(base64String);
        fileName = 'foresee_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else {
        // Dosya yolu
        final file = File(widget.imageData);
        imageBytes = await file.readAsBytes();
        fileName = file.path.split('/').last;
      }

      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // Paylaş
      await Share.shareXFiles([XFile(tempFile.path)], text: 'ForeSee Görseli');

      // Geçici dosyayı sil
      await tempFile.delete();
    } catch (e) {
      GreyNotification.show(context, 'Paylaşma hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
