import 'dart:convert';

class SecureKey {
  static final SecureKey _instance = SecureKey._internal();
  factory SecureKey() => _instance;
  SecureKey._internal();

  // Simple XOR cipher to prevent plain text strings in memory dump (basic protection)
  String _xor(String text, String key) {
    List<int> result = [];
    List<int> textBytes = utf8.encode(text);
    List<int> keyBytes = utf8.encode(key);

    for (int i = 0; i < textBytes.length; i++) {
      result.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64.encode(result);
  }

  String _dexor(String text, String key) {
    List<int> result = [];
    List<int> textBytes = base64.decode(text);
    List<int> keyBytes = utf8.encode(key);

    for (int i = 0; i < textBytes.length; i++) {
      result.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return utf8.decode(result);
  }

  // Not strictly "secure" storage (use FlutterSecureStorage for persistence),
  // but this is for runtime memory obfuscation of keys loaded from env
  final Map<String, String> _obfuscatedStore = {};
  final String _memKey =
      "ForeSee_Runtime_Salt_${DateTime.now().millisecondsSinceEpoch}";

  void set(String key, String value) {
    _obfuscatedStore[key] = _xor(value, _memKey);
  }

  String? get(String key) {
    if (!_obfuscatedStore.containsKey(key)) return null;
    return _dexor(_obfuscatedStore[key]!, _memKey);
  }
}
