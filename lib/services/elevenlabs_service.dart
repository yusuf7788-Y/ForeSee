import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

class ElevenLabsService {
  static final ElevenLabsService instance = ElevenLabsService._internal();
  ElevenLabsService._internal();
  factory ElevenLabsService() => instance;

  final String _apiKey = dotenv.get('ELEVEN_LABS_API_KEY');
  String _voiceId = dotenv.get('ELEVEN_LABS_VOICE_ID');
  static const String _baseUrl = 'https://api.elevenlabs.io/v1/text-to-speech';

  Future<File?> generateSpeech(String text, {String? voiceId}) async {
    if (text.isEmpty) return null;

    try {
      final targetVoiceId = voiceId ?? _voiceId;
      final url = Uri.parse('$_baseUrl/$targetVoiceId');

      final response = await http.post(
        url,
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {'stability': 0.5, 'similarity_boost': 0.75},
        }),
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/elevenlabs_speech_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        print(
          'ElevenLabs API Error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('ElevenLabs Service Exception: $e');
      return null;
    }
  }
}
