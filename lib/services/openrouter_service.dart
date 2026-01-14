import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'storage_service.dart';
import 'context_service.dart';

class OpenRouterService {
  static final List<String> apiKeys = [
    dotenv.env['OPENROUTER_API_KEY_1'] ?? '',
    dotenv.env['OPENROUTER_API_KEY_2'] ?? '',
    dotenv.env['OPENROUTER_API_KEY_3'] ?? '',
    dotenv.env['OPENROUTER_API_KEY_4'] ?? '',
  ].where((k) => k.isNotEmpty).toList();

  static int _currentKeyIndex = 1; // User said 2nd one is primary

  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String model = 'x-ai/grok-4.1-fast';

  final StorageService _storageService = StorageService();
  final ContextService _contextService = ContextService();

  String _getApiKey() {
    if (apiKeys.isEmpty) return '';
    return apiKeys[_currentKeyIndex % apiKeys.length];
  }

  void _rotateKey() {
    if (apiKeys.isNotEmpty) {
      _currentKeyIndex = (_currentKeyIndex + 1) % apiKeys.length;
    }
  }

  void _ensureApiKey() {
    if (_getApiKey().isEmpty) {
      throw Exception('API Anahtarı eksik');
    }
  }

  String _handleError(int statusCode, String body) {
    if (statusCode == 429) {
      _rotateKey();
      return 'Maalesef sınırınız dolmuştur lütfen 1 gün bekleyiniz.\n\nSınırları yükseltmeye çalışıyoruz.';
    } else if (statusCode == 404) {
      return 'API Hatası (404): Kaynak bulunamadı.';
    }
    return 'API hatası: $statusCode - $body';
  }

  Future<String> _buildSystemMessage() async {
    final memory = await _storageService.getUserMemory();
    final customPrompt = await _storageService.getCustomPrompt();

    String systemMessage = '';

    // 1. Statik Kılavuz (En üstte, cache için en değerli kısım)
    if (customPrompt.isNotEmpty) {
      systemMessage += customPrompt;
    } else {
      systemMessage += '''ForeSee Asistan Kılavuzu (Kısaltılmış)
- Sen ForeSee adında Mobil uygulama içindeki bir yapay zekasın kullanıcı uygulamada bulamadığı birşeyi sor 

- Grafik Potansiyeli: Eğer cevabın bir grafik (çizgi, bar, pasta grafiği), bir matematiksel denklem (örn: y = 2x + 5), bir tablo veya bir Venn şeması olarak görselleştirilebilecek veri içeriyorsa, cevabının SONUNA mutlaka `CHART_CANDIDATE: true` etiketini ekle. Eğer böyle bir potansiyel yoksa bu etiketi KULLANMA.

- Takvim Etkinliği: Eğer kullanıcı bir takvim etkinliği oluşturmak, randevu ayarlamak veya bir toplantı planlamak isterse (örn: 'yarın 15:00 için toplantı ayarla'), normal bir cevap ver ve cevabının SONUNA, kullanıcıya göstermeden, `[CALENDAR_EVENT]: {"title": "Etkinlik Başlığı", "startTime": "YYYY-MM-DDTHH:MM:SS", "endTime": "YYYY-MM-DDTHH:MM:SS"}` formatında bir JSON ekle. Başlangıç ve bitiş zamanlarını tam ISO 8601 formatında ver. Eğer bitiş zamanı belirtilmemişse, başlangıç zamanından bir saat sonrası olarak ayarla.

- Çoklu Cevap: Eğer kullanıcı önemli, yoruma açık veya yaratıcılık gerektiren bir soru sorarsa (örn: 'bir sonraki projem ne olmalı?', 'bu metni daha iyi nasıl yazarım?'), birbirinden farklı iki cevap üret. Her bir cevabı `[MULTI_ANSWER]` etiketiyle ayır. Örnek: `[MULTI_ANSWER]1. Cevap metni.[MULTI_ANSWER]2. Cevap metni.` Basit ve tekil cevap gerektiren sorular için bu formatı KULLANMA.

- İzin Yönlendirmesi: Eğer kullanıcı 'Uygulama Kullanım Takibi' gibi dijital denge özelliğini açmak isterse ve bu izin henüz verilmemişse, kullanıcıyı ayarlar menüsüne yönlendiren bir cevap ver. Cevabın içinde, ilgili ayarın adını `[SETTINGS_LINK:Uygulama Kullanım Takibi]` gibi bir etiketle sarmala. Örnek: `Bu özelliği kullanmak için lütfen [SETTINGS_LINK:Uygulama Kullanım Takibi] ayarını aktif hale getirin.`

- Kimlik: ForeSee adlı mobil sohbet / yapay zeka uygulamasının içindeki asistansın. Kendini sadece "ForeSee" diye tanıt.
- Stil: Kısa ve öz cevaplar ver; gerektiğinde detay ekle ama gereksiz girizgâhlardan ("Merhaba, nasıl yardımcı olabilirim" vb.) kaçın.
- Formatlama: Cevaplarında Markdown kullanabilirsin (liste, başlık, tablo).
- Kod formatı: 3 satırdan uzun HER kod bloğunu mutlaka ```dil ...``` şeklinde, uygun dili belirterek (örn. ```dart```, ```python```) ver. Küçük tek satırlık kodları istersen normal metin içinde kullanabilirsin.
- Görsel Üretimi (Otomatik): Sen bir görsel üretim uzmanısın. Kullanıcı resim çizmeni istediğinde `[İMGEN]: detaylı ingilizce prompt` etiketini kullan. ÖNEMLİ: `[İMGEN]` içine yazdığın prompt SADECE çeviri olmamalı; Pollinations sitesindeki "Enhanced" modu gibi profesyonelce genişletilmiş olmalı (ışıklandırma, stil, 8k, sanatsal detaylar ekle). Önce `[REASON]` ile ne çizeceğini planla, sonra zenginleştirilmiş `[İMGEN]` etiketini bas. Eğer kullanıcı görsel atacağını söyleyip atmadıysa sorma bekle. Görselle birlikte ekstra metin yazma, sadece etiketleri kullan.
- Düşünme Süreci (Otomatik): Eğer karmaşık bir problem çözüyorsan veya adım adım düşünmen gerekiyorsa, cevabından önce veya cevabın sırasında `[REASON]: Düşüncelerini buraya yaz` etiketini kullan. Bu, "DÜŞÜNME SÜRECİ" panelinde anlık olarak görünecektir.
- Web araştırmaları ve kaynaklar: Bir SORUYA CEVAP VERMEK İÇİN gerçekten web araştırmaları yapman gerektiğinde, cevabının SONUNDA ayrı bir satırda **sadece** `KAYNAKLAR_JSON: [...]` formatında JSON bir kaynak listesi ver. Örn: `KAYNAKLAR_JSON: [{"title":"...","link":"https://...","snippet":"kısa açıklama"}]`. Kaynak yoksa `KAYNAKLAR_JSON: []` yaz. Bu satır kullanıcıya GÖSTERİLMEZ, sadece arayüz tarafından ikonlu kaynak paneli için kullanılır. Normal cevap metninde ASLA "Kaynaklar:" başlığı veya URL listesi yazma; kaynaklar sadece KAYNAKLAR_JSON içinde bulunsun.
- Telefon numarası: +ÜlkeKodu AlanKodu Numara formatını kullan (Örn: +90 530 123 45 67). Parantez, tire, nokta kullanma.
- Bellek (user memory): Kullanıcı hakkında kalıcı bilgi (isim, şehir, arkadaşları, şehir, meslek vb.) öğrenirsen, cevabın SONUNA ayrı bir satır olarak `[BELLEK]: ...` yaz. Bu satıra SADECE kullanıcıya dair kişisel bilgileri yaz; AI davranış kurallarını buraya ASLA yazma. Tüm belleği silmek istersen cevabın sonuna ayrı bir satır olarak `[BELLEK_SIFIRLA]` yaz.
- Prompt (davranış kuralları): ForeSee'nin ismi, tonu ve çalışma kuralları özel prompt alanında tutulur. Kendi davranışını değiştirmek istersen cevabın SONUNA ayrı bir satır olarak `[PROMPT]: ...` yaz; bu, mevcut özel prompt'u tamamen bu metinle DEĞİŞTİRİR. Varsayılan kılavuza dönmek için cevabın sonuna ayrı bir satır olarak `[PROMPT_SIFIRLA]` yaz. Bu kontrol satırları kullanıcıya gösterilmez, sadece sistem tarafından işlenir.
- ForeSee uygulaması sorulursa: Uygulamayı kendi ürününmüş gibi tanıt; çoklu sohbetler, mesaj sabitleme, tema ve font ayarları, kullanıcı belleği ve bildirimler gibi özelliklerden bahset.

Detaycı olma; kısa tutulması gereken yerde kısa kes.
Son olarak, webde araştırma YAPMADIĞIN sürece KAYNAKLAR_JSON üretme.''';
    }

    // 2. Kullanıcı Belleği (Görece statik, üstte kalmalı)
    if (memory.isNotEmpty) {
      systemMessage += '\n\nKullanıcı hakkında önemli bilgiler:\n$memory';
    }

    // 3. Dinamik Bağlam (Tarih ve Konum sürekli değiştiği için en sona, cache'i bozmasın diye)
    systemMessage += '\n\n${_contextService.getCurrentDateInfo()}';

    final locationInfo = await _contextService.getCurrentLocation();
    if (locationInfo != null) {
      systemMessage += '\n$locationInfo';
    }

    return systemMessage;
  }

  Future<String> sendMessage(String message, {String? imageBase64}) async {
    try {
      _ensureApiKey();
      // Sistem mesajını ekle
      final systemMessage = await _buildSystemMessage();
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemMessage},
      ];

      if (imageBase64 != null) {
        messages.add({
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': message.isEmpty
                  ? 'Bu görseli analiz et ve detaylı açıkla Sen yapmışsın gibi açıkla Görseli.'
                  : message,
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        });
      } else {
        messages.add({'role': 'user', 'content': message});
      }

      final requestBody = {
        'model': model,
        'messages': messages,
        'max_tokens': 2048,
        'temperature': 0.7,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception(_handleError(response.statusCode, response.body));
      }
    } catch (e) {
      if (e.toString().contains('Maalesef sınırınız dolmuştur')) {
        rethrow;
      }
      throw Exception('Bağlantı hatası: $e');
    }
  }

  Future<String> sendMessageWithHistoryStream(
    List<Map<String, dynamic>> conversationHistory,
    String newMessage, {
    List<String>? imagesBase64,
    required void Function(String) onToken,
    required bool Function() shouldStop,
    int? maxTokens,
    bool useReasoning = false,
    String reasoningEffort = 'high',
    String? modelOverride,
  }) async {
    try {
      _ensureApiKey();
      final systemMessage = await _buildSystemMessage();
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemMessage},
        ...conversationHistory,
      ];

      if (imagesBase64 != null && imagesBase64.isNotEmpty) {
        final contentList = <Map<String, dynamic>>[
          {
            'type': 'text',
            'text': newMessage.isEmpty
                ? 'Bu görsel(ler)i analiz et ve detaylı açıkla. Hepsini tek tek ve birlikte yorumla.'
                : newMessage,
          },
        ];

        for (var img in imagesBase64) {
          String imageUrl = img;
          if (!imageUrl.startsWith('data:image')) {
            imageUrl = 'data:image/jpeg;base64,$imageUrl';
          }
          contentList.add({
            'type': 'image_url',
            'image_url': {'url': imageUrl},
          });
        }

        messages.add({'role': 'user', 'content': contentList});
      } else {
        messages.add({'role': 'user', 'content': newMessage});
      }

      final requestBody = {
        'model': modelOverride ?? model,
        'messages': messages,
        'max_tokens':
            maxTokens ?? 7600, // Canvas / normal modlar için token limiti
        'temperature': 0.7,
        'stream': true,
        if (useReasoning) 'reasoning': {'effort': reasoningEffort},
      };

      final client = http.Client();
      http.StreamedResponse? streamedResponse;
      String fullResponse = '';
      bool isCancelled = false;

      try {
        final uri = Uri.parse(apiUrl);
        final request = http.Request('POST', uri);
        request.headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getApiKey()}',
          'HTTP-Referer': 'https://foresee.app',
          'X-Title': 'ForeSee AI',
        });
        request.body = jsonEncode(requestBody);

        streamedResponse = await client
            .send(request)
            .timeout(
              const Duration(seconds: 120),
              onTimeout: () {
                client.close();
                throw Exception('İstek zaman aşımına uğradı');
              },
            );

        if (streamedResponse.statusCode != 200) {
          final body = await streamedResponse.stream.bytesToString();
          throw Exception(_handleError(streamedResponse.statusCode, body));
        }

        // Stream'i düzgün parse et
        final stream = streamedResponse.stream.transform(utf8.decoder);
        String buffer = '';

        await for (final chunk in stream) {
          // Cancellation kontrolü - her chunk'ta kontrol et
          if (shouldStop()) {
            isCancelled = true;
            // Stream'i iptal et - client kapatılınca otomatik iptal olur
            break;
          }

          buffer += chunk;

          // SSE formatını parse et (data: ile başlayan satırlar)
          while (true) {
            final lineEndIndex = buffer.indexOf('\n');
            if (lineEndIndex == -1) break;

            final line = buffer.substring(0, lineEndIndex).trim();
            buffer = buffer.substring(lineEndIndex + 1);

            if (line.isEmpty) continue;

            // SSE formatı: "data: {...}" veya "data: [DONE]"
            if (line.startsWith('data:')) {
              final data = line.substring(5).trim();

              if (data.isEmpty) continue;
              if (data == '[DONE]') {
                return fullResponse;
              }

              try {
                final json = jsonDecode(data);

                // Hata kontrolü
                if (json['error'] != null) {
                  throw Exception('API hatası: ${json['error']}');
                }

                final choices = json['choices'];
                if (choices is List && choices.isNotEmpty) {
                  final choice = choices[0];

                  final delta = choice['delta'];
                  if (delta is Map && delta['content'] is String) {
                    final token = delta['content'] as String;
                    if (token.isNotEmpty) {
                      fullResponse += token;
                      onToken(token);
                    }
                  }

                  // Finish reason kontrolü - içeriği ekledikten sonra kontrol et
                  if (choice['finish_reason'] != null) {
                    final finishReason = choice['finish_reason'];
                    if (finishReason == 'stop' || finishReason == 'length') {
                      return fullResponse;
                    }
                  }
                }
              } catch (e) {
                // JSON parse hatası - logla ama devam et
                if (e is FormatException) {
                  // Parçalanmış JSON - buffer'da beklet, sonraki chunk'ta tamamlanır
                  continue;
                }
                // Diğer hatalar için rethrow
                rethrow;
              }
            }
          }
        }

        // Cancellation durumunda kısmi cevabı döndür
        if (isCancelled) {
          return fullResponse;
        }

        return fullResponse;
      } catch (e) {
        // Stream cancellation hatası normal - sessizce geç
        if (isCancelled ||
            e.toString().contains('cancel') ||
            e.toString().contains('abort')) {
          return fullResponse;
        }
        rethrow;
      } finally {
        // HTTP client'ı her durumda kapat
        client.close();
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  Future<String> sendMessageWithHistory(
    List<Map<String, dynamic>> conversationHistory,
    String newMessage, {
    List<String>? imagesBase64,
    String? model,
  }) async {
    try {
      _ensureApiKey();
      // Sistem mesajını ekle
      final systemMessage = await _buildSystemMessage();
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemMessage},
        ...conversationHistory,
      ];

      if (imagesBase64 != null && imagesBase64.isNotEmpty) {
        final contentList = <Map<String, dynamic>>[
          {
            'type': 'text',
            'text': newMessage.isEmpty
                ? 'Bu görsel(ler)i analiz et ve detaylı açıkla. Hepsini tek tek ve birlikte yorumla.'
                : newMessage,
          },
        ];

        for (var img in imagesBase64) {
          String imageUrl = img;
          if (!imageUrl.startsWith('data:image')) {
            imageUrl = 'data:image/jpeg;base64,$imageUrl';
          }
          contentList.add({
            'type': 'image_url',
            'image_url': {'url': imageUrl},
          });
        }

        messages.add({'role': 'user', 'content': contentList});
      } else {
        messages.add({'role': 'user', 'content': newMessage});
      }

      final requestBody = {
        'model': model ?? OpenRouterService.model,
        'messages': messages,
        'max_tokens': 2048,
        'temperature': 0.7,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception(
          'API hatası: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Otomatik AI analizi kaldırıldı - anahtar kelime tabanlı sistem kullanılıyor

  // Görsel oluşturma için akıllı Türkçe-İngilizce çeviri
  Future<String> translateForImageGeneration(String turkishPrompt) async {
    try {
      _ensureApiKey();
      final translationPrompt =
          '''
Aşağıdaki Türkçe prompt'u görsel oluşturma için İngilizce'ye çevir.

KURALLAR:
- Özel isimleri (kişi, yer, marka adları) AYNEN koru
- Tırnak içindeki metinleri ("...") AYNEN koru  
- Sadece genel kelimeleri çevir
- Görsel oluşturma için optimize et
- Kısa ve net çeviri yap

Türkçe prompt: "$turkishPrompt"

Sadece İngilizce çeviriyi ver, başka açıklama yapma:''';

      final requestBody = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': translationPrompt},
        ],
        'max_tokens': 150,
        'temperature': 0.2,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translation = data['choices'][0]['message']['content'].trim();
        print('🌍 Çeviri: "$turkishPrompt" → "$translation"');
        return translation;
      } else {
        print('❌ Çeviri hatası: ${response.statusCode}');
        throw Exception(_handleError(response.statusCode, response.body));
      }
    } catch (e) {
      print('❌ Çeviri hatası: $e');
      throw Exception('Çeviri yapılamadı: $e');
    }
  }

  /// Web arama için kullanıcı cümlesini, aranması gerekeni en iyi anlatan arama sorgusuna dönüştürür
  Future<String> refineWebSearchQuery(String userText) async {
    try {
      _ensureApiKey();
      final prompt =
          '''
Kullanıcının aşağıdaki cümlesini web araması için en uygun arama sorgusuna dönüştür.

Amacın:
- Cümlenin gerçekte NEYİ araştırmak istediğini anlamak
- Bunu arama motoruna yazılacak kısa ama anlamlı bir sorgu olarak ifade etmek

Kurallar:
- Gereksiz kelimeleri çıkar ("bana", "lütfen", "yeni ai ını araştır" içindeki gereksiz bölümler vb.)
- Özel isimleri (marka / ürün / model / uygulama adları) aynen koru (örn: Windsurf, ForeSee, Gemini)
- Önemli bağlam kelimelerini koru (örn: "pricing", "features", "update", "2025" gibi aramada kritik olanlar)
- ÇIKTININ DİLİ KULLANICININ DİLİYLE AYNI OLSUN. Türkçe bir cümle geldiyse çıktıyı da TÜRKÇE ver, İngilizce'ye ÇEVİRME.
- Çıktı SADECE arama sorgusu olsun, açıklama ekleme, tırnak ekleme.

Örnek:
"bana windsurfın yeni ai ını araştır" → windsurf yeni yapay zeka

Kullanıcı cümlesi: "$userText"
''';

      final requestBody = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 48,
        'temperature': 0.2,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final refined = data['choices'][0]['message']['content'].trim();
        print('🔎 Web sorgu netleştirildi: "$userText" → "$refined"');
        if (refined.isEmpty) return userText;
        return refined;
      } else {
        print('❌ Web sorgu netleştirme hatası: ${response.statusCode}');
        _handleError(response.statusCode, response.body); // For rotation
        return userText;
      }
    } catch (e) {
      print('❌ Web sorgu netleştirme hatası: $e');
      return userText;
    }
  }

  /// Overlay asistanı için: kullanıcının sesli komutundan hangi mobil
  /// uygulamayı açmak istediğini tahmin eder.
  ///
  /// Döndürebileceği değerler:
  /// - Bir uygulama adı ("YouTube", "Spotify", "Netflix", "Instagram", "Chrome" vb.)
  /// - "WEB_SEARCH"  → kullanıcı aslında sadece webde arama istiyor
  /// - "UNKNOWN"     → hangi uygulamayı kastettiği anlaşılamadı
  Future<String> refineOverlayAppName(String userText) async {
    try {
      _ensureApiKey();
      final prompt =
          '''
Kullanıcının sesli komutundan hangi mobil uygulamayı açmak istediğini bul.

Kurallar:
- SADECE uygulama adını yaz (örnek: "YouTube", "Spotify", "Netflix", "Instagram", "Chrome").
- Eğer kullanıcı sadece internette arama yapmak istiyorsa (örneğin "webde ara ...", "Google'da ... ara"), "WEB_SEARCH" yaz.
- Eğer hangi uygulamayı istediği anlaşılmıyorsa "UNKNOWN" yaz.
- Başka hiçbir açıklama, cümle veya format ekleme. Sadece tek satır yaz.

Kullanıcı komutu: "$userText"
''';

      final requestBody = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 32,
        'temperature': 0.2,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content is String) {
          final trimmed = content.trim();
          if (trimmed.isEmpty) return 'UNKNOWN';
          return trimmed;
        }
        return 'UNKNOWN';
      } else {
        return 'UNKNOWN';
      }
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  Future<OverlayTodoResult> generateOverlayTodoFromCommand({
    required String userCommand,
    required String currentAppId,
  }) async {
    try {
      final baseSystem = await _buildSystemMessage();
      final overlayInstructions =
          '''
ForeSee şu anda kullanıcının başka bir uygulama içinde verdiği sesli komutu analiz ediyor.

Şu anda aktif uygulama kimliği: "$currentAppId".

Görevin:
- Kullanıcının niyetini anlamak.
- Eğer bu niyet bu uygulamada yapılabilecek bir görevler dizisine uygunsa, aşağıdaki biçimde bir JSON TODO listesi üretmek:
OVERLAY_TODO_JSON: {
  "app_id": "<uygulama_id>",
  "title": "kısa görev başlığı",
  "description": "kısa açıklama",
  "steps": [
    {"title": "adım 1", "description": "kısa açıklama"},
    {"title": "adım 2", "description": "kısa açıklama"}
  ]
}

Kurallar:
- ÇIKTININ SON SATIRINDA mutlaka `OVERLAY_TODO_JSON: ...` formatında tek bir JSON bloğu olsun.
- Eğer komut bu uygulama ile alakasızsa VEYA bu uygulamada yapılamazsa, TODO üretme.
  Bunun yerine SON SATIRDA sadece şu satırı ver:
  OVERLAY_TODO_JSON: "APP_MISMATCH"
- JSON'un dışında kullanıcıya görünen normal açıklama yazabilirsin, ama SON SATIRDAKİ JSON tam geçerli olmalı.
''';

      final systemMessage = '$baseSystem\n\n$overlayInstructions';

      final requestBody = {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemMessage},
          {'role': 'user', 'content': userCommand},
        ],
        'max_tokens': 512,
        'temperature': 0.4,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(_handleError(response.statusCode, response.body));
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String? ?? '';

      final result = _parseOverlayTodoFromContent(content);
      return result;
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  OverlayTodoResult _parseOverlayTodoFromContent(String content) {
    String? jsonPart;
    final lines = content.split('\n');

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final markerIndex = line.indexOf('OVERLAY_TODO_JSON:');
      if (markerIndex != -1) {
        jsonPart = line
            .substring(markerIndex + 'OVERLAY_TODO_JSON:'.length)
            .trim();
        break;
      }
    }

    if (jsonPart == null || jsonPart.isEmpty) {
      throw Exception('OVERLAY_TODO_JSON bulunamadı');
    }

    if (jsonPart == '"APP_MISMATCH"' || jsonPart == 'APP_MISMATCH') {
      return OverlayTodoResult(appMismatch: true, task: null, rawText: content);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonPart);
    } catch (e) {
      throw Exception('OVERLAY_TODO_JSON parse edilemedi: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('OVERLAY_TODO_JSON beklenen formatta değil');
    }

    final task = OverlayTodoTask.fromJson(decoded);
    return OverlayTodoResult(appMismatch: false, task: task, rawText: content);
  }

  /// Metin -> görsel üretimi için Grok/OpenRouter kullanır.
  /// Dönen değer, data URL formatında ("data:image/...;base64,...") ilk görseldir.
  Future<String> generateImageWithGrok(String prompt) async {
    try {
      _ensureApiKey();
      final requestBody = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'modalities': ['image', 'text'],
        'max_tokens': 256,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception(_handleError(response.statusCode, response.body));
      }

      final data = jsonDecode(response.body);
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        throw Exception('Grok cevabında seçim bulunamadı');
      }

      final message = choices[0]['message'];
      if (message is! Map<String, dynamic>) {
        throw Exception('Grok cevabında message alanı beklenen formatta değil');
      }

      final images = message['images'];
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        if (first is Map<String, dynamic>) {
          final imageUrl =
              (first['image_url']?['url']) ?? (first['imageUrl']?['url']);
          if (imageUrl is String && imageUrl.isNotEmpty) {
            return imageUrl;
          }
        }
      }

      throw Exception('Grok cevabında görsel bulunamadı');
    } catch (e) {
      throw Exception('Grok ile görsel oluşturulamadı: $e');
    }
  }

  Future<String> generateChatTitle(String conversationPreview) async {
    try {
      _ensureApiKey();
      final prompt =
          '''Aşağıdaki sohbet için kısa ve anlamlı bir sohbet başlığı üret.

Kurallar:
- Türkçe yaz.
- En fazla 9-10 kelime olsun.
- Nokta, tırnak, emoji veya ekstra açıklama ekleme.
- Sadece başlık metnini ver.

Sohbet:
$conversationPreview
''';

      final requestBody = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 32,
        'temperature': 0.4,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
              'HTTP-Referer': 'https://foresee.app',
              'X-Title': 'ForeSee AI',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content is String) {
          return content.trim();
        }
        return '';
      } else {
        _handleError(response.statusCode, response.body); // For rotation
        return '';
      }
    } catch (_) {
      return '';
    }
  }

  Future<String> getSuggestionForContext(String context) async {
    try {
      _ensureApiKey();
      final prompt =
          '''Kullanıcının ekranındaki şu anki metin içeriği aşağıdadır. Bu içeriğe dayanarak, kullanıcının ilgisini çekebilecek proaktif, kısa ve tek cümlelik bir soru önerisi oluştur. Örnek: "Bu makalenin özetini çıkarmak ister misin?" veya "Bu ürünün fiyatlarını karşılaştıralım mı?". Eğer anlamlı bir öneri yoksa, sadece "NULL" yaz.

Ekran İçeriği:
"""
$context
"""''';

      final response = await sendMessage(prompt);
      return response.trim();
    } catch (e) {
      return '';
    }
  }

  Future<void> analyzeCode({
    required String language,
    required String code,
    required void Function(String) onToken,
    required bool Function() shouldStop,
  }) async {
    final prompt =
        'Aşağıdaki $language kod bloğunu analiz et ve iyileştir. '
        'Hataları düzelt, okunabilirliği artır, gereksiz tekrarları kaldır. '
        'CEVAP OLARAK SADECE tam düzeltilmiş kodu ver. Açıklama, yorum veya markdown metni yazma. '
        'Kodun tamamını, eksiksiz ve tek bir blok halinde döndür.\n\n'
        '```$language\n$code\n```';

    await sendMessageWithHistoryStream(
      [],
      prompt,
      onToken: onToken,
      shouldStop: shouldStop,
      modelOverride: 'mistralai/devstral-2512:free',
    );
  }
}

class OverlayTodoResult {
  final OverlayTodoTask? task;
  final bool appMismatch;
  final String rawText;

  OverlayTodoResult({
    required this.task,
    required this.appMismatch,
    required this.rawText,
  });
}

class OverlayTodoTask {
  final String appId;
  final String title;
  final String description;
  final List<OverlayTodoStep> steps;

  OverlayTodoTask({
    required this.appId,
    required this.title,
    required this.description,
    required this.steps,
  });

  factory OverlayTodoTask.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'];
    final steps = <OverlayTodoStep>[];
    if (stepsJson is List) {
      for (final item in stepsJson) {
        if (item is Map<String, dynamic>) {
          steps.add(OverlayTodoStep.fromJson(item));
        }
      }
    }

    return OverlayTodoTask(
      appId: json['app_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      steps: steps,
    );
  }
}

class OverlayTodoStep {
  final String title;
  final String description;

  OverlayTodoStep({required this.title, required this.description});

  factory OverlayTodoStep.fromJson(Map<String, dynamic> json) {
    return OverlayTodoStep(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}
