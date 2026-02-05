/// Gelişmiş Easter Egg Tespit Mekanizması
class EasterEggDetector {
  /// Ana kontrol fonksiyonu
  static bool detect(String message) {
    if (message.isEmpty) return false;

    // 1. Normalizasyon: Küçük harfe çevir, Türkçe karakterleri İngilizce karşılıklarıyla değiştir
    final normalized = _normalizeTurkish(message.toLowerCase().trim());

    // 2. Özne Kontrolü (Kimden bahsediliyor?)
    final hasSubject = _containsSubject(normalized);

    // 3. İstek Kontrolü (Şaka/Espri mi isteniyor?)
    final hasJokeRequest = _containsJokeRequest(normalized);

    // Her iki şart da sağlanıyorsa true döner
    return hasSubject && hasJokeRequest;
  }

  /// Türkçe karakterleri standartlaştıran ve gürültüyü temizleyen yardımcı fonksiyon
  static String _normalizeTurkish(String text) {
    return text
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        // Sadece harf, sayı ve soru işaretini bırak, diğer sembolleri sil
        .replaceAll(RegExp(r'[^\w\s\?]'), ' ');
  }

  /// Özne listesini kontrol eder (Daha geniş kapsamlı)
  static bool _containsSubject(String text) {
    final subjectPatterns = [
      'rte',
      'erdogan',
      'tayyip',
      'recep',
      'reis',
      'uzun adam',
      'cumhurbaskani',
      'cb',
      'baskan',
    ];

    // Kelime sınırlarına (\b) dikkat ederek kontrol eder
    // Böylece "dert" kelimesindeki "rte" harflerini yanlışlıkla yakalamaz.
    return subjectPatterns.any((pattern) {
      final regex = RegExp(r'\b' + pattern + r'\b');
      return regex.hasMatch(text) || text.contains(pattern);
    });
  }

  /// Şaka/Espri isteğini kontrol eder
  static bool _containsJokeRequest(String text) {
    // Şaka ile ilgili temel kelimeler
    final jokeKeywords = [
      'espri',
      'saka',
      'fikra',
      'mizah',
      'komik',
      'gulunc',
      'makara',
      'dalga',
      'eglence',
      'joke',
    ];

    // Aksiyon bildiren (emir veya soru) kelimeler
    final actionKeywords = [
      'yap',
      'soyle',
      'anlat',
      'patlat',
      'gelsin',
      'desene',
      'bilirmisin',
      'et',
      '?',
      'varmis',
    ];

    // Doğrudan tamlamalar (Örn: "rte esprisi")
    final directPhrases = [
      'esprisi',
      'fikrasi',
      'sakasi',
      'komikligi',
      'mizahi',
    ];

    bool hasJokeKeyword = jokeKeywords.any((k) => text.contains(k));
    bool hasAction = actionKeywords.any((a) => text.contains(a));
    bool hasDirect = directPhrases.any((d) => text.contains(d));

    // Mantık: (Kelime + Aksiyon) VARSA veya (Doğrudan tamlama) VARSA
    return (hasJokeKeyword && hasAction) || hasDirect;
  }
}

/// --- Kullanım Örneği ---
void main() {
  List<String> testMessages = [
    "rte hakkinda espri yap",
    "Tayyip esprisi gelsin",
    "Bize bir fıkra anlatsana reis hakkında",
    "CB komiklikleri",
    "Bugün hava çok güzel", // False dönmeli
  ];

  for (var msg in testMessages) {
    print(
      'Mesaj: "$msg" -> Tespit edildi mi: ${EasterEggDetector.detect(msg)}',
    );
  }
}
