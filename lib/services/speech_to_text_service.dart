import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Basit, yeniden kullanılabilir STT servisi.
/// Widget'lar bu servisi kullanarak ses kaydı başlatıp durdurabilir.
class SpeechToTextService {
  static final SpeechToTextService instance = SpeechToTextService._internal();

  SpeechToTextService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> startListening({
    required void Function(String text) onText,
    void Function(double level)? onLevelChanged,
    void Function(String message)? onError,
    void Function(String status)? onStatus,
  }) async {
    if (_isRecording) return true;

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (onStatus != null) {
            onStatus(status);
          }
        },
        onError: (error) {
          if (onError != null) {
            onError(error.errorMsg);
          }
        },
      );

      if (!available) {
        onError?.call('Cihazda konuşma tanıma kullanılamıyor');
        return false;
      }

      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          onText(text);
        },
        listenMode: stt.ListenMode.dictation,
        onSoundLevelChange: (level) {
          if (onLevelChanged != null) {
            double normalized = (level + 60) / 60;
            if (normalized < 0) normalized = 0;
            if (normalized > 1) normalized = 1;
            onLevelChanged(normalized);
          }
        },
      );

      _isRecording = true;
      return true;
    } catch (_) {
      onError?.call('Ses kaydı başlatılamadı');
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      if (_isRecording) {
        await _speech.stop();
      }
    } catch (_) {}
    _isRecording = false;
  }

  Future<void> dispose() async {
    await stopListening();
  }
}
