import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'openrouter_service.dart';

class ImageGenerationService {
  final OpenRouterService _openRouter = OpenRouterService();

  /// Pollinations.ai ile görsel oluşturma (ücretsiz, API key gerektirmez)
  /// Not: Artık ana yol Grok/OpenRouter, bu metod sadece FALBACK olarak kullanılıyor.
  Future<String> generateImage(
    String prompt, {
    String? referenceImageUrl,
    String? negativePrompt,
  }) async {
    final List<String> models = ['flux', 'turbo', 'unity'];
    int maxRetries = 2;
    Exception? lastException;

    for (String currentModel in models) {
      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          print(
            '🌸 Pollinations.ai ($currentModel) ile görsel oluşturuluyor... Deneme: ${attempt + 1}',
          );

          String finalPrompt = prompt.trim();
          if (negativePrompt != null && negativePrompt.trim().isNotEmpty) {
            finalPrompt += " [NOT: ${negativePrompt.trim()}]";
          }

          String imageUrl =
              'https://gen.pollinations.ai/image/${Uri.encodeComponent(finalPrompt)}'
              '?model=$currentModel'
              '&width=1024'
              '&height=1024'
              '&enhance=true'
              '&nologo=true'
              '&quality=hd';

          if (referenceImageUrl != null && referenceImageUrl.isNotEmpty) {
            imageUrl += '&image=${Uri.encodeComponent(referenceImageUrl)}';
          }

          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 45));

          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            if (bytes.length < 1000) {
              throw Exception('Oluşturulan görsel çok küçük veya geçersiz.');
            }
            final base64Image = base64Encode(bytes);

            print('✅ Pollinations.ai ($currentModel) ile görsel oluşturuldu!');

            final watermarkedImage = await _addWatermark(
              'data:image/jpeg;base64,$base64Image',
            );

            return watermarkedImage;
          } else {
            throw Exception(
              'Pollinations.ai ($currentModel) hatası: ${response.statusCode}',
            );
          }
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          print('⚠️ Deneme ${attempt + 1} ($currentModel) başarısız: $e');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
          }
        }
      }
      print('🔄 Model $currentModel başarısız, sıradaki modele geçiliyor...');
    }

    throw lastException ??
        Exception('Tüm modeller ve denemeler başarısız oldu.');
  }

  /// Görsel oluşturma - şu an ana yol Pollinations.ai, Grok/OpenRouter devre dışı
  Future<String> generateImageWithFallback(
    String prompt, {
    bool isTransparent = false,
    String? referenceImageUrl,
    String? negativePrompt,
  }) async {
    // Şimdilik doğrudan Pollinations.ai üzerinden üretim yap
    // generateImage zaten filigran ekleyerek döner.
    return await generateImage(
      prompt,
      referenceImageUrl: referenceImageUrl,
      negativePrompt: negativePrompt,
    );
  }

  // Görsel düzenleme metodu (artık sadece metin tabanlı yeniden üretim)
  Future<String> editImage(String imageBase64, String editPrompt) async {
    print('🎨 Görsel düzenleniyor (yeniden üretim): $editPrompt');

    // FAL AI kaldırıldı; mevcut görseli gerçekten editlemek yerine,
    // düzenleme prompt'una göre yeni bir görsel üretiyoruz.
    // düzenleme prompt'una göre yeni bir görsel üretiyoruz.
    // Burada imageBase64 parametresi ileride istenirse farklı bir sağlayıcıya
    // geçmek için tutuluyor.
    return await generateImageWithFallback('$editPrompt, high quality');
  }

  /// Görsele filigran ekler (sağ alt köşe, %20 saydamlık)
  Future<String> _addWatermark(String imageBase64) async {
    try {
      // Ana görseli decode et
      String base64Part;
      final commaIndex = imageBase64.indexOf(',');
      if (commaIndex != -1) {
        base64Part = imageBase64.substring(commaIndex + 1).trim();
      } else {
        base64Part = imageBase64.trim();
      }

      // Olası boşluk ve satır sonlarını temizle
      base64Part = base64Part.replaceAll(RegExp(r'\s'), '');

      Uint8List imageBytes;
      try {
        imageBytes = base64Decode(base64Part);
      } on FormatException catch (e) {
        print('❌ Filigran için base64 çözümlenemedi: $e');
        // Hata durumunda orijinal görseli hiç dokunmadan döndür
        return imageBase64;
      }
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image mainImage = frameInfo.image;

      // Logo4.png'yi yükle
      final ByteData logoData = await rootBundle.load('assets/logo3.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final ui.Codec logoCodec = await ui.instantiateImageCodec(logoBytes);
      final ui.FrameInfo logoFrameInfo = await logoCodec.getNextFrame();
      final ui.Image logoImage = logoFrameInfo.image;

      // Canvas oluştur
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Ana görseli çiz
      canvas.drawImage(mainImage, ui.Offset.zero, ui.Paint());

      // Logo boyutunu hesapla (ana görselin %8'i)
      final double logoSize = (mainImage.width * 0.08).clamp(30.0, 80.0);
      final double logoWidth = logoSize;
      final double logoHeight = logoSize * (logoImage.height / logoImage.width);

      // Sağ alt köşe pozisyonu (10px margin)
      final double logoX = mainImage.width - logoWidth - 10;
      final double logoY = mainImage.height - logoHeight - 10;

      // Logo için paint (%70 opacity)
      final ui.Paint logoPaint = ui.Paint()
        ..colorFilter = ui.ColorFilter.mode(
          Colors.white.withOpacity(0.7),
          ui.BlendMode.modulate,
        )
        ..filterQuality = ui.FilterQuality.high;

      // Logoyu çiz
      canvas.drawImageRect(
        logoImage,
        ui.Rect.fromLTWH(
          0,
          0,
          logoImage.width.toDouble(),
          logoImage.height.toDouble(),
        ),
        ui.Rect.fromLTWH(logoX, logoY, logoWidth, logoHeight),
        logoPaint,
      );

      // Picture'ı image'a çevir
      final ui.Picture picture = recorder.endRecording();
      final ui.Image finalImage = await picture.toImage(
        mainImage.width,
        mainImage.height,
      );

      // ByteData'ya çevir
      final ByteData? byteData = await finalImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('Filigran eklenirken hata oluştu');
      }

      // Base64'e çevir
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final String base64Result = base64Encode(pngBytes);

      print('✅ Filigran eklendi! Boyut: ${pngBytes.length} bytes');
      return 'data:image/png;base64,$base64Result';
    } catch (e) {
      print('❌ Filigran ekleme hatası: $e');
      // Hata durumunda orijinal görseli döndür
      return imageBase64;
    }
  }
}
