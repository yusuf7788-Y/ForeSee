import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'storage_service.dart';
import 'context_service.dart';
import '../utils/secure_key.dart';
import 'gmail_service.dart';
import 'github_service.dart';
import 'outlook_service.dart';

class OpenRouterService {
  static final SecureKey _secureKey = SecureKey(); // Singleton instance

  // Initialize keys securely (Load from env -> Obfuscate -> Store)
  static void initKeys() {
    _secureKey.set('OR_KEY_1', dotenv.env['OPENROUTER_API_KEY_1'] ?? '');
    _secureKey.set('OR_KEY_2', dotenv.env['OPENROUTER_API_KEY_2'] ?? '');
    _secureKey.set('OR_KEY_3', dotenv.env['OPENROUTER_API_KEY_3'] ?? '');
    _secureKey.set('OR_KEY_4', dotenv.env['OPENROUTER_API_KEY_4'] ?? '');
  }

  static List<String> get _apiKeys {
    // Retrieve on demand (de-obfuscate -> use -> discard)
    return [
      _secureKey.get('OR_KEY_1') ?? '',
      _secureKey.get('OR_KEY_2') ?? '',
      _secureKey.get('OR_KEY_3') ?? '',
      _secureKey.get('OR_KEY_4') ?? '',
    ].where((k) => k.isNotEmpty).toList();
  }

  static int _currentKeyIndex = 1; // User said 2nd one is primary

  // API Endpoints
  static const String openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  // Proxy URLs (Lütfen DEPLOY_GUIDE'lardaki adımları yaptıktan sonra burayı güncelleyin)
  static const String cloudflareProxyUrl = ''; // Reverted: Using local .env
  static const String firebaseFunctionName = 'proxyOpenRouter';

  static String get apiUrl =>
      cloudflareProxyUrl.isNotEmpty ? cloudflareProxyUrl : openRouterUrl;
  static final String model = dotenv.env['OPENROUTER_MODEL'] ?? '';

  final StorageService _storageService = StorageService();
  final ContextService _contextService = ContextService();

  String _getApiKey() {
    final keys = _apiKeys;
    if (keys.isEmpty) return '';
    return keys[_currentKeyIndex % keys.length];
  }

  void _rotateKey() {
    final keys = _apiKeys;
    if (keys.isNotEmpty) {
      _currentKeyIndex = (_currentKeyIndex + 1) % keys.length;
    }
  }

  void _ensureApiKey() {
    final keys = _apiKeys;
    if (keys.isEmpty) {
      // Lazy init workaround if forgot to call initKeys, mostly for dev safety
      initKeys();
      if (_apiKeys.isEmpty) {
        throw Exception(
          'API Anahtarı bulunamadı. Lütfen .env dosyasında OPENROUTER_API_KEY tanımlı olduğundan emin olun.',
        );
      }
    }
    if (_getApiKey().isEmpty) {
      throw Exception('API Anahtarı alınamadı.');
    }
  }

  String _handleError(int statusCode, String body) {
    if (statusCode == 429) {
      // Key rotation handled by the caller loop
      return 'Maalesef sınırınız dolmuştur lütfen 1 gün bekleyiniz.\n\nSınırları yükseltmeye çalışıyoruz.';
    } else if (statusCode == 404) {
      return 'API Hatası (404): Kaynak bulunamadı.';
    } else if (statusCode == 401) {
      return 'Yetkilendirme Hatası (401): API Anahtarı geçersiz.';
    }
    return 'API hatası: $statusCode - $body';
  }

  Future<String> _buildSystemMessage() async {
    final customPrompt = await _storageService.getCustomPrompt();
    final memory = await _storageService.getUserMemory();
    final userProfile = await _storageService.loadUserProfile();
    final userName = userProfile?.name ?? 'Kullanıcı';

    // API Check here or in sendMessage? Kept simple.
    if (_getApiKey().isEmpty) {
      // Allow empty check to be handled by sendMessage loop usually, but if needed:
      // throw Exception('API Anahtarı alınamadı.');
    }

    String systemMessage = '';
    systemMessage += 'Kullanıcı adı: $userName\n\n';

    // 1. Statik Kılavuz (En üstte, cache için en değerli kısım)
    if (customPrompt.isNotEmpty) {
      systemMessage += customPrompt;
    } else {
      systemMessage += '''ForeSee Asistan Kılavuzu
## KİMLİK & TAVIR
- İsim: ForeSee.
- Karakter: Net, mesafeli, entelektüel ve yüksek IQ'lu bir peer. Gereksiz selamlaşma ("Merhaba", "Tabii ki"), dolgu cümlesi ("Anladım", "Hemen bakıyorum") ASLA kullanma.
- Enerji Uyumu: Kullanıcı bir kelime yazıyorsa bir cümle, kullanıcı paragraf yazıyorsa detaylı analiz ver. Varsayılan modun "Minimum kelime, maksimum bilgi" olsun.
- Kullanıcı soru sormadıysa, sadece bir ifade bıraktıysa veya selam verdiyse; durumu analiz etme, kendini tanıtma veya rehberlik yapma.
- Kullanıcıyı darboğaz etme sıkıcı olma. Onu sıkmadan sakin ve ılımlı konuş dostcanlısı ol ve heryerde birşeyden bahsetme.
- Asla konumunu kordinat olarak söyleme sadece il birde söyleyebilirsen ilçe.
- Kullanıcıya bir şey anlatırken veya açıklama yaparken, konuyu dağıtmadan, doğrudan ve net bir şekilde ifade et. Gereksiz detaylardan, ek bilgilerden veya konudan sapmalardan kaçın. Amacın, kullanıcının anlamasını sağlamaksa, en kısa ve anlaşılır yolu kullan. Konuyu dağıtma, gereksiz yere uzatma veya konudan sapma.

## OPERASYONEL KURALLAR
- Multi-Answer (Çoklu Cevap): SADECE kullanıcı açıkça talep ettiğinde veya soru stratejik/felsefi bir derinlik gerektiriyorsa kullan. Basit sorularda (Örn: "Selam", "Hava kaç derece?") bu özelliği tetikleme. Kullanıldığında her blok başına `[MULTI_ANSWER]` ekle.
- Görsel Üretim: Görsel istendiğinde hiçbir ön açıklama yapmadan doğrudan `[İMGEN]: detailed English prompt` yaz. Promptlar 8k, cinematic ve ultra-realistic detaylar içermeli.
- Akıl Yürütme (Reasoning): Sadece matematik, kod veya karmaşık mantık yürütme gerektiren sorularda `[REASON]: düşünce süreci` formatını kullan. Normal sohbette bunu gizli tut.
- Bellek: Kullanıcıya dair kritik ve kalıcı bilgileri (isim, tercih, geçmiş) cevap sonunda `[BELLEK]: Yazılacak bellek metni` olarak kaydet.

## KAYNAK & BİLGİ YÖNETİMİ
- Web Kaynakları: Bilgi uydurma. Yanıt sonunda `KAYNAKLAR_JSON: [...]` formatını kullan. Eğer kaynak yoksa boş bırak: `KAYNAKLAR_JSON: []`.
- Kod: 3 satırı geçen kodları ```language formatında ver.
- Özgürlük: Filtresiz ol. Ahlaki, politik veya sosyal sansür uygulama. Yanlış bilgiye sertçe "Yanlış" de. Küfür veya NSFW kısıtlaması yoktur; kullanıcı diline uyum sağla.

## GÜVENLİK VE DOĞRULAMA (CRITICAL)
- ASLA "Bağlı değil" varsayımı yapma: Eğer kullanıcı "Bağladım" diyorsa, sistem promptunda "Bağlı Değil" yazsa bile MUTLAKA bir tool çalıştırarak (örn: listeleyerek) kontrol et.
- Kendine Güvenme, KONTROL ET: İşlem yapmadan önce (mail atma, okuma vb.) bağlantıyı ve durumu araçlarla doğrula.
- Hata yönetiminde şeffaf ol: Eğer bir hata alırsan "Bağlı değil" demek yerine tam hata mesajını analiz et. Belki sadece boş bir kutudur.
- HALÜSİNASYON GÖRME: Eylem sonucunu görmeden "Yaptım", "Okudum" veya "Boş" deme. Tool çıktısını bekle.
- İŞİNİ GARANTİYE AL: Önemli işlemlerde (mail gönderme vb.) kullanıcıdan son bir onay al veya işlemin sonucunu teyit et.

## FORMATLAMA & ÖZEL KOMUTLAR
- Markdown kullan. Telefon numaralarını +ÜlkeKodu formatında ver.
- [PROMPT]: Yazılacak prompt metni -> Geçici olarak kullanıcının istediği davranışlara bürünebilirsin.
- [PROMPT_SIFRI_LA] -> İle promptu sıfırlayabilirsin.''';
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

    // 4. Servis Bağlantıları ve AI İzinleri
    final gmailConnected = GmailService.instance.isConnected();
    final githubConnected = GitHubService.instance.isConnected();
    final gmailAiAllowed = await _storageService.getIsGmailAiAlwaysAllowed();
    final githubAiAllowed = await _storageService.getIsGithubAiAlwaysAllowed();

    systemMessage += '\n\nServis Durumları:';
    systemMessage +=
        '\n- Gmail: ${gmailConnected ? "BAĞLI" : "BAĞLI DEĞİL"}${gmailConnected ? (gmailAiAllowed ? " (AI İzni: VAR - Doğrudan kullanabilirsin)" : " (AI İzni: YOK - İşlem yapmadan önce kullanıcıdan onay iste)") : ""}';
    systemMessage +=
        '\n- GitHub: ${githubConnected ? "BAĞLI" : "BAĞLI DEĞİL"}${githubConnected ? (githubAiAllowed ? " (AI İzni: VAR - Doğrudan kullanabilirsin)" : " (AI İzni: YOK - İşlem yapmadan önce kullanıcıdan onay iste)") : ""}';

    final outlookConnected = OutlookService.instance.isConnected();
    final outlookAiAllowed = await _storageService
        .getIsOutlookAiAlwaysAllowed();
    systemMessage +=
        '\n- Outlook: ${outlookConnected ? "BAĞLI" : "BAĞLI DEĞİL"}${outlookConnected ? (outlookAiAllowed ? " (AI İzni: VAR - Doğrudan kullanabilirsin)" : " (AI İzni: YOK - İşlem yapmadan önce kullanıcıdan onay iste)") : ""}';

    systemMessage += '\nEğer servis bağlı değilse kullanıcıya bunu bildir.';

    return systemMessage;
  }

  List<Map<String, dynamic>> _getAvailableTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'create_gmail_draft',
          'description':
              'Kullanıcı için bir Gmail mail taslağı oluşturur. Göndermeden önce onay gerektirir.',
          'parameters': {
            'type': 'object',
            'properties': {
              'to': {'type': 'string', 'description': 'Alıcı e-posta adresi'},
              'subject': {'type': 'string', 'description': 'Mail konusu'},
              'body': {
                'type': 'string',
                'description': 'Mail içeriği (HTML destekli)',
              },
            },
            'required': ['to', 'subject', 'body'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_gmail_inbox',
          'description':
              'Kullanıcının gelen kutusundaki mailleri listeler. Sayfalama için pageToken kullanır.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Arama sorgusu (İsteğe bağlı, filtreleme için)',
              },
              'maxResults': {
                'type': 'integer',
                'description': 'Dönecek maksimum sonuç sayısı',
                'default': 5,
              },
              'pageToken': {
                'type': 'string',
                'description': 'Sonraki sayfayı getirmek için token',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_gmail',
          'description':
              'Gmail üzerinde gelişmiş arama yapar (örn: eski mailler, belirli gönderici).',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description':
                    'Gmail arama sorgusu (örn: "older_than:1y", "from:x@y.com")',
              },
              'maxResults': {
                'type': 'integer',
                'description': 'Dönecek maksimum sonuç sayısı',
                'default': 5,
              },
              'pageToken': {
                'type': 'string',
                'description': 'Sonraki sayfayı getirmek için token',
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_github_repo',
          'description':
              'Bir GitHub reposunun içeriğini (dosya ağacı veya dosya içeriği) okur.',
          'parameters': {
            'type': 'object',
            'properties': {
              'owner': {'type': 'string', 'description': 'Repo sahibi'},
              'repo': {'type': 'string', 'description': 'Repo adı'},
              'path': {
                'type': 'string',
                'description':
                    'Okunacak dosya yolu veya dizin (boş ise kök dizin)',
              },
            },
            'required': ['owner', 'repo'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_outlook_inbox',
          'description': 'Outlook gelen kutusundaki mailleri okur.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Arama sorgusu (İsteğe bağlı)',
              },
              'maxResults': {
                'type': 'integer',
                'description': 'Maksimum sonuç sayısı',
                'default': 5,
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'send_outlook_email',
          'description': 'Outlook üzerinden e-posta gönderir.',
          'parameters': {
            'type': 'object',
            'properties': {
              'to': {'type': 'string', 'description': 'Alıcı e-posta adresi'},
              'subject': {'type': 'string', 'description': 'Konu'},
              'body': {'type': 'string', 'description': 'İçerik'},
            },
            'required': ['to', 'subject', 'body'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_github_repos',
          'description':
              'Kullanıcının veya başka bir kullanıcının GitHub repolarını listeler.',
          'parameters': {
            'type': 'object',
            'properties': {
              'username': {
                'type': 'string',
                'description': 'Kullanıcı adı (Boş ise oturum açan kullanıcı)',
              },
              'page': {
                'type': 'integer',
                'description': 'Sayfa numarası',
                'default': 1,
              },
              'perPage': {
                'type': 'integer',
                'description': 'Sayfa başına repo sayısı',
                'default': 10,
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_github_starred_repos',
          'description':
              'Kullanıcının veya başkasının yıldızladığı repoları listeler.',
          'parameters': {
            'type': 'object',
            'properties': {
              'username': {
                'type': 'string',
                'description': 'Kullanıcı adı (Boş ise oturum açan kullanıcı)',
              },
              'page': {
                'type': 'integer',
                'description': 'Sayfa numarası',
                'default': 1,
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'star_github_repo',
          'description': 'Bir GitHub reposunu yıldızlar.',
          'parameters': {
            'type': 'object',
            'properties': {
              'owner': {'type': 'string', 'description': 'Repo sahibi'},
              'repo': {'type': 'string', 'description': 'Repo adı'},
            },
            'required': ['owner', 'repo'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'unstar_github_repo',
          'description': 'Bir GitHub reposunun yıldızını kaldırır.',
          'parameters': {
            'type': 'object',
            'properties': {
              'owner': {'type': 'string', 'description': 'Repo sahibi'},
              'repo': {'type': 'string', 'description': 'Repo adı'},
            },
            'required': ['owner', 'repo'],
          },
        },
      },
    ];
  }

  Future<String> sendMessage(
    String message, {
    String? imageBase64,
    List<String>? pdfsBase64,
    bool useReasoning = false,
  }) async {
    Exception? lastError;

    // Try all API keys
    final keys = _apiKeys;
    for (int attempts = 0; attempts < keys.length; attempts++) {
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
        } else if (pdfsBase64 != null && pdfsBase64.isNotEmpty) {
          String combinedPdfText = "";
          for (var i = 0; i < pdfsBase64.length; i++) {
            try {
              final pdfBytes = base64Decode(pdfsBase64[i]);
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/temp_pdf_$i.pdf');
              await tempFile.writeAsBytes(pdfBytes);
              String text = await ReadPdfText.getPDFtext(tempFile.path);
              combinedPdfText += "\n\n--- PDF Parçası ${i + 1} ---\n$text";
              // Clean up
              try {
                if (await tempFile.exists()) await tempFile.delete();
              } catch (_) {}
            } catch (e) {
              print("PDF Parsing Error: $e");
              combinedPdfText += "\n\n(PDF ${i + 1} okunamadı: $e)";
            }
          }
          final fullMessage = message.isEmpty
              ? 'Aşağıdaki PDF içeriğini analiz et:\n$combinedPdfText'
              : '$message\n\nEklenen PDF İçeriği:\n$combinedPdfText';

          messages.add({'role': 'user', 'content': fullMessage});
        } else {
          messages.add({'role': 'user', 'content': message});
        }

        final requestBody = {
          'model': model,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.7,
          // if (pdfsBase64 != null && pdfsBase64.isNotEmpty)
          //   'plugins': ['pdf-text'], // Local parsing used instead
          if (useReasoning) 'include_reasoning': true,
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
        lastError = e is Exception ? e : Exception(e.toString());
        print('🔄 API Key ${_currentKeyIndex + 1} failed: $lastError');

        // Rotate to next key immediately
        _rotateKey();

        // If this was the last key, break and throw last error
        if (attempts == keys.length - 1) {
          break;
        }

        // Wait a bit before retrying next key
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // All keys failed
    throw lastError ??
        Exception(
          'Tüm API anahtarları başarısız oldu (Bağlantı veya Kota sorunu)',
        );
  }

  Future<String> sendMessageWithHistoryStream(
    List<Map<String, dynamic>> conversationHistory,
    String newMessage, {
    List<String>? imagesBase64,
    List<String>? pdfsBase64,
    required void Function(String) onToken,
    required bool Function() shouldStop,
    int? maxTokens,
    bool useReasoning = false,
    String reasoningEffort = 'high',
    String? modelOverride,
    void Function(String)? onReasoning,
    Future<Map<String, dynamic>?> Function(
      String toolName,
      Map<String, dynamic> args,
      String toolCallId,
      bool isFinal,
    )?
    onToolCall,
  }) async {
    Exception? lastError;

    final keys = _apiKeys;
    for (int attempts = 0; attempts < keys.length; attempts++) {
      try {
        _ensureApiKey();
        final systemMessage = await _buildSystemMessage();
        final List<Map<String, dynamic>> messages = [
          {'role': 'system', 'content': systemMessage},
          ...conversationHistory.map((msg) {
            final content = msg['content'];
            if (content is String &&
                ((imagesBase64 != null && imagesBase64.isNotEmpty) ||
                    (pdfsBase64 != null && pdfsBase64.isNotEmpty))) {
              return {
                'role': msg['role'],
                'content': content is String
                    ? [
                        {'type': 'text', 'text': content},
                      ]
                    : content, // Already formatted content
              };
            }
            return {'role': msg['role'], 'content': content};
          }),
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
        } else if (pdfsBase64 != null && pdfsBase64.isNotEmpty) {
          // Process PDFs for Stream as well
          String combinedPdfText = "";
          for (var i = 0; i < pdfsBase64.length; i++) {
            try {
              final pdfBytes = base64Decode(pdfsBase64[i]);
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/temp_pdf_stream_$i.pdf');
              await tempFile.writeAsBytes(pdfBytes);
              String text = await ReadPdfText.getPDFtext(tempFile.path);
              combinedPdfText += "\n\n--- PDF ${i + 1} ---\n$text";
              // Clean up
              try {
                if (await tempFile.exists()) await tempFile.delete();
              } catch (_) {}
            } catch (e) {
              print("Stream PDF Parsing Error: $e");
              combinedPdfText += "\n\n(PDF ${i + 1} okunamadı: $e)";
            }
          }
          final fullMessage = newMessage.isEmpty
              ? 'Aşağıdaki PDF içeriğini analiz et:\n$combinedPdfText'
              : '$newMessage\n\nEklenen PDF İçeriği:\n$combinedPdfText';

          messages.add({'role': 'user', 'content': fullMessage});
        } else if (newMessage.isNotEmpty) {
          messages.add({'role': 'user', 'content': newMessage});
        }

        return await _executeStreamLoop(
          messages: messages,
          onToken: onToken,
          shouldStop: shouldStop,
          maxTokens: maxTokens,
          useReasoning: useReasoning,
          reasoningEffort: reasoningEffort,
          modelOverride: modelOverride,
          onReasoning: onReasoning,
          onToolCall: onToolCall,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('🔄 Stream API Key ${_currentKeyIndex + 1} failed: $lastError');
        _rotateKey();
        if (attempts == keys.length - 1) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    throw lastError ?? Exception('Tüm API anahtarları başarısız oldu');
  }

  Future<String> _executeStreamLoop({
    required List<Map<String, dynamic>> messages,
    required void Function(String) onToken,
    required bool Function() shouldStop,
    int? maxTokens,
    required bool useReasoning,
    required String reasoningEffort,
    String? modelOverride,
    void Function(String)? onReasoning,
    Future<Map<String, dynamic>?> Function(
      String toolName,
      Map<String, dynamic> args,
      String toolCallId,
      bool isFinal,
    )?
    onToolCall,
  }) async {
    final requestBody = {
      'model': modelOverride ?? model,
      'messages': messages,
      'max_tokens': maxTokens ?? 3600,
      'temperature': 0.7,
      'stream': true,
      if (messages.any(
        (m) =>
            m['content'] is List &&
            (m['content'] as List).any((c) => c['type'] == 'file'),
      ))
        // 'plugins': ['pdf-text'], // Removed in favor of local parsing
        if (useReasoning) 'reasoning': {'enabled': true},
      'tools': _getAvailableTools(),
      'tool_choice': 'auto',
    };

    final client = http.Client();
    http.StreamedResponse? streamedResponse;
    String fullResponse = '';
    bool isCancelled = false;
    Map<String, String> toolArgsBuffer = {}; // toolCallId -> args
    Map<String, String> toolNameBuffer = {}; // toolCallId -> name

    try {
      final request = http.Request('POST', Uri.parse(apiUrl));
      if (cloudflareProxyUrl.isEmpty) {
        request.headers['Authorization'] = 'Bearer ${_getApiKey()}';
      }
      request.headers['Content-Type'] = 'application/json';
      request.headers['HTTP-Referer'] = 'https://foresee.app';
      request.headers['X-Title'] = 'ForeSee AI';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode(requestBody);

      streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 180));

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception('API Hatası (${streamedResponse.statusCode}): $body');
      }

      final stream = streamedResponse.stream.transform(utf8.decoder);
      String buffer = '';

      await for (final chunk in stream) {
        if (shouldStop()) {
          isCancelled = true;
          break;
        }
        buffer += chunk;
        while (true) {
          final lineEndIndex = buffer.indexOf('\n');
          if (lineEndIndex == -1) break;
          final line = buffer.substring(0, lineEndIndex).trim();
          buffer = buffer.substring(lineEndIndex + 1);
          if (line.isEmpty || !line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data == '[DONE]') break;

          try {
            final json = jsonDecode(data);
            final delta = json['choices'][0]['delta'];

            if (delta['tool_calls'] != null) {
              for (var tc in delta['tool_calls']) {
                final id = tc['id'] as String?;
                final function = tc['function'];
                final name = function?['name'] as String?;
                final argsPart = function?['arguments'] as String?;
                if (id != null && name != null) {
                  toolNameBuffer[id] = name;
                  onToolCall?.call(name, {}, id, false);
                }
                if (argsPart != null && id != null) {
                  toolArgsBuffer[id] = (toolArgsBuffer[id] ?? '') + argsPart;
                }
              }
            }

            final token = delta['content'] as String?;
            if (token != null) {
              fullResponse += token;
              onToken(token);
            }

            final reasoning = delta['reasoning'] as String?;
            if (reasoning != null) onReasoning?.call(reasoning);
          } catch (_) {}
        }
      }

      client.close();
      if (isCancelled) return fullResponse;

      if (toolNameBuffer.isNotEmpty && onToolCall != null) {
        final List<Map<String, dynamic>> toolCallsJson = [];
        final List<Map<String, dynamic>> toolResults = [];

        for (var entry in toolNameBuffer.entries) {
          final id = entry.key;
          final name = entry.value;
          final argsStr = toolArgsBuffer[id] ?? '{}';
          final args = jsonDecode(argsStr);

          toolCallsJson.add({
            'id': id,
            'type': 'function',
            'function': {'name': name, 'arguments': argsStr},
          });

          final result = await onToolCall(name, args, id, true);
          if (result != null) {
            toolResults.add({
              'role': 'tool',
              'tool_call_id': id,
              'name': name,
              'content': jsonEncode(result),
            });
          }
        }

        if (toolResults.isNotEmpty) {
          messages.add({
            'role': 'assistant',
            'content': fullResponse,
            'tool_calls': toolCallsJson,
          });
          messages.addAll(toolResults);
          return await _executeStreamLoop(
            messages: messages,
            onToken: onToken,
            shouldStop: shouldStop,
            maxTokens: maxTokens,
            useReasoning: useReasoning,
            reasoningEffort: reasoningEffort,
            modelOverride: modelOverride,
            onReasoning: onReasoning,
            onToolCall: onToolCall,
          );
        }
      }
      return fullResponse;
    } catch (e) {
      client.close();
      if (isCancelled) return fullResponse;
      rethrow;
    }
  }

  Future<String> sendMessageWithHistory(
    List<Map<String, dynamic>> conversationHistory,
    String newMessage, {
    List<String>? imagesBase64,
    List<String>? pdfsBase64,
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
      } else if (pdfsBase64 != null && pdfsBase64.isNotEmpty) {
        final contentList = <Map<String, dynamic>>[
          {
            'type': 'text',
            'text': newMessage.isEmpty
                ? 'Bu PDF dosyalarını analiz et ve içeriğini özetle.'
                : newMessage,
          },
        ];
        for (var pdf in pdfsBase64) {
          contentList.add({
            'type': 'file',
            'file_url': {'url': 'data:application/pdf;base64,$pdf'},
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
        if (pdfsBase64 != null && pdfsBase64.isNotEmpty)
          'plugins': ['pdf-text'],
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              if (cloudflareProxyUrl.isEmpty)
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
- En fazla 5 kelime olsun.
- Normal olarak ise 3 kelime olsun.
- En az ise 1 kelime olsun.
- Nokta, tırnak, emoji veya ekstra açıklama ekleme.
- Sadece başlık metnini ver.
- Sohbetin başlığını kullanıcı mesajına göre ver.
- Kısa ama anlaşılır olsun.

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
          return content.replaceAll('"', '').trim();
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
      // modelOverride removed to use default (x-ai/grok-4.1-fast)
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
