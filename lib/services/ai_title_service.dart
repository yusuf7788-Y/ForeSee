import '../services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AITitleService {
  static const List<String> _greetingPatterns = [
    'selam',
    'merhaba',
    'hi',
    'hello',
    'hey',
    'naberler',
    'nasılsın',
    'iyi günler',
    'arkadaşlar',
  ];

  static const List<String> _questionPatterns = [
    '?',
    'nedir',
    'nasıl',
    'ne yapıyorsun',
    'kimdir',
    'nereye',
    'hangi',
    'kaç',
  ];

  static String generateTitle(String input) {
    // Input'i küçük harfe çevir
    final cleanInput = input.toLowerCase().trim();
    
    // Selamlama kalıplarını kontrol et
    for (final pattern in _greetingPatterns) {
      if (cleanInput == pattern) {
        return 'Basit selamlaşma';
      }
    }
    
    // Soru kalıplarını kontrol et
    for (final pattern in _questionPatterns) {
      if (cleanInput.contains(pattern)) {
        return _generateQuestionTitle(cleanInput);
      }
    }
    
    // Varsayılan başlık
    return '';
  }

  static String _generateQuestionTitle(String input) {
    // Basit soru kalıpları
    if (input.contains('nedir')) return 'Nasılsın?';
    if (input.contains('nasıl')) return 'Nasıl yapıyorsun?';
    if (input.contains('ne yapıyorsun')) return 'Ne yapıyorsun?';
    if (input.contains('kimdir')) return 'Kimdir?';
    if (input.contains('nereye')) return 'Nereye gidiyorsun?';
    if (input.contains('hangi')) return 'Hangi?';
    if (input.contains('kaç')) return 'Kaç?';
    
    // Karmaşık sorular için carousel
    if (input.length > 15) {
      final words = input.split(' ');
      if (words.length > 3) {
        return '${words[0]} ${words.sublist(1, 3).join(' ')}...';
      }
    }
    
    return input;
  }

  static Future<void> saveCurrentTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_ai_title', title);
  }

  static Future<String> getCurrentTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_ai_title') ?? '';
  }
}
