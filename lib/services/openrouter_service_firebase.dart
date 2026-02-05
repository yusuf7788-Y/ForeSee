import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'storage_service.dart';
import 'context_service.dart';
import '../utils/secure_key.dart';
import 'gmail_service.dart';
import 'github_service.dart';
import 'outlook_service.dart';

class OpenRouterService {
  // Firebase Callable Function instance
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final StorageService _storageService = StorageService();
  final ContextService _contextService = ContextService();

  Future<String> _buildSystemMessage() async {
    final customPrompt = await _storageService.getCustomPrompt();
    final memory = await _storageService.getUserMemory();
    final userProfile = await _storageService.loadUserProfile();
    final userName = userProfile?.name ?? 'Kullanıcı';

    String systemMessage = '';
    systemMessage += 'Kullanıcı adı: $userName\n\n';

    // System prompt (copy from original)
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

    if (memory.isNotEmpty) {
      systemMessage += '\n\nKullanıcı hakkında önemli bilgiler:\n$memory';
    }

    systemMessage += '\n\n${_contextService.getCurrentDateInfo()}';

    final locationInfo = await _contextService.getCurrentLocation();
    if (locationInfo != null) {
      systemMessage += '\n$locationInfo';
    }

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

  /// Call Firebase Cloud Function instead of direct API
  Future<String> sendMessageWithHistory(
    List<Map<String, dynamic>> conversationHistory,
    String newMessage, {
    List<String>? imagesBase64,
    List<String>? pdfsBase64,
    String? model,
  }) async {
    try {
      final systemMessage = await _buildSystemMessage();
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemMessage},
        ...conversationHistory,
      ];

      // Handle PDFs locally (same as before)
      if (pdfsBase64 != null && pdfsBase64.isNotEmpty) {
        String combinedPdfText = "";
        for (var i = 0; i < pdfsBase64.length; i++) {
          try {
            final pdfBytes = base64Decode(pdfsBase64[i]);
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/temp_pdf_$i.pdf');
            await tempFile.writeAsBytes(pdfBytes);
            String text = await ReadPdfText.getPDFtext(tempFile.path);
            combinedPdfText += "\n\n--- PDF ${i + 1} ---\n$text";
            try {
              if (await tempFile.exists()) await tempFile.delete();
            } catch (_) {}
          } catch (e) {
            combinedPdfText += "\n\n(PDF ${i + 1} okunamadı: $e)";
          }
        }
        final fullMessage = newMessage.isEmpty
            ? 'Aşağıdaki PDF içeriğini analiz et:\n$combinedPdfText'
            : '$newMessage\n\nEklenen PDF İçeriği:\n$combinedPdfText';

        messages.add({'role': 'user', 'content': fullMessage});
      } else if (imagesBase64 != null && imagesBase64.isNotEmpty) {
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
      } else if (newMessage.isNotEmpty) {
        messages.add({'role': 'user', 'content': newMessage});
      }

      // Call Firebase Function
      final callable = _functions.httpsCallable('proxyOpenRouter');
      final result = await callable.call({
        'messages': messages,
        'model':
            model ??
            dotenv.env['OPENROUTER_MODEL'] ??
            'google/gemini-2.0-flash-exp:free',
        'maxTokens': 2048,
        'temperature': 0.7,
      });

      return result.data['choices'][0]['message']['content'];
    } catch (e) {
      throw Exception('Firebase Function Error: $e');
    }
  }

  // Streaming not well supported by Cloud Functions, keep as-is or remove
  // For now, we keep the old direct implementation as a fallback
}
