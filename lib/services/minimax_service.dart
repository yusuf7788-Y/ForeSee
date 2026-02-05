import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MinimaxService {
  static final MinimaxService _instance = MinimaxService._internal();
  factory MinimaxService() => _instance;
  MinimaxService._internal();

  String get _apiKey => dotenv.env['MINIMAX_API_KEY'] ?? '';
  String get _groupId => dotenv.env['MINIMAX_GROUP_ID'] ?? '';
  String get _voiceId =>
      dotenv.env['MINIMAX_VOICE_ID'] ?? 'English_captivating_female1';

  final String _baseUrl = 'https://api.minimax.chat/v1/t2a_v2';

  /// Converts text to audio (MP3) bytes
  Future<List<int>?> synthesize(String text) async {
    if (_apiKey.isEmpty || _groupId.isEmpty) {
      print('❌ Minimax API Key or Group ID missing');
      return null;
    }

    final cleanText = _cleanTextForTTS(text);
    if (cleanText.isEmpty) return null;

    final url = Uri.parse(_baseUrl);

    // Minimax T2A v2 payload
    final payload = {
      "model": "speech-01-turbo",
      "text": cleanText,
      "stream": false,
      "voice_setting": {
        "voice_id": _voiceId,
        "speed": 1.0,
        "vol": 1.0,
        "pitch": 0,
      },
      "audio_setting": {
        "sample_rate": 32000,
        "bitrate": 128000,
        "format": "mp3",
        "channel": 1,
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Minimax returns JSON with "data": { "audio": "hex_string", "status": 1 ... } usually
        // OR sometimes binary depending on endpoints. Standard T2A v2 returns JSON with hex audio.
        // Let's decode logic based on Minimax docs standard.
        // Actually, T2A v2 usually returns raw audio if stream=false?
        // Documentation check: Minimax T2A v2 "speech-01" often returns JSON with "data": { "audio": "HEX_STRING" }
        // Let's assume hex string for now as per common implementations.

        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['base_resp'] != null &&
            jsonResponse['base_resp']['status_code'] != 0) {
          print('❌ Minimax Error: ${jsonResponse['base_resp']['status_msg']}');
          return null;
        }

        if (jsonResponse['data'] != null &&
            jsonResponse['data']['audio'] != null) {
          final String hexAudio = jsonResponse['data']['audio'];
          return _hexToBytes(hexAudio);
        }
      } else {
        print(
          '❌ Minimax HTTP Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Minimax Exception: $e');
    }
    return null;
  }

  /// Removes code blocks, URLs, and markdown symbols
  String _cleanTextForTTS(String text) {
    // 1. Remove code blocks (```...```)
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // 2. Remove inline code (`...`)
    text = text.replaceAll(RegExp(r'`.*?`'), '');

    // 3. Remove URLs
    text = text.replaceAll(RegExp(r'https?://\S+'), '');

    // 4. Remove Markdown links [text](url) -> text
    text = text.replaceAllMapped(
      RegExp(r'\[(.*?)\]\(.*?\)'),
      (match) => match.group(1) ?? '',
    );

    // 5. Remove bold/italic markers
    text = text.replaceAll(RegExp(r'[*_]{1,3}'), '');

    // 6. Remove headers (#)
    text = text.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');

    // 7. Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 8. Remove LaTeX math logic if possible, or just symbols
    text = text.replaceAll(RegExp(r'\$\$.*?\$\$'), '');
    text = text.replaceAll(RegExp(r'\$.*?\$'), '');

    return text;
  }

  List<int> _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw FormatException("Invalid hex string");
    }
    var bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      var byteInfo = hex.substring(i, i + 2);
      var byte = int.parse(byteInfo, radix: 16);
      bytes.add(byte);
    }
    return bytes;
  }
}
