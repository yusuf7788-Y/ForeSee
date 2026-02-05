import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';

class GmailService {
  static final GmailService instance = GmailService._internal();
  GmailService._internal();
  factory GmailService() => instance;

  static final String _clientId = dotenv.get('GOOGLE_CLIENT_ID');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _clientId,
    scopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.compose',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  final StorageService _storageService = StorageService();

  GoogleSignInAccount? _currentUser;
  bool isConnected() => _currentUser != null;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> initialize() async {
    final shouldConnect = await _storageService.getIsGmailConnected();
    if (shouldConnect) {
      try {
        _currentUser = await _googleSignIn.signInSilently();
      } catch (e) {
        print('Gmail Silent Sign-In Error: $e');
      }
    }
  }

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _storageService.setIsGmailConnected(true);
        return true;
      }
      return false;
    } catch (error) {
      print('Gmail Login Error: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (e) {
      print('Gmail SignOut Error (ignoring): $e');
    }
    _currentUser = null;
    await _storageService.setIsGmailConnected(false);
  }

  Future<Map<String, dynamic>> createDraft({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (_currentUser == null) throw Exception('Gmail bağlı değil');

    final authHeaders = await _currentUser!.authHeaders;
    final url = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/drafts',
    );

    final String rawMessage = _createRawEmail(to, subject, body);
    final String encodedMessage = base64UrlEncode(utf8.encode(rawMessage));

    final response = await http.post(
      url,
      headers: {...authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': {'raw': encodedMessage},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Taslak oluşturulamadı: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return {
      'status': 'draft_created',
      'id': data['id'],
      'title': subject,
      'added': body.split('\n').length,
      'removed': 0,
    };
  }

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (_currentUser == null) throw Exception('Gmail bağlı değil');

    final authHeaders = await _currentUser!.authHeaders;
    final url = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
    );

    final String rawMessage = _createRawEmail(to, subject, body);
    final String encodedMessage = base64UrlEncode(utf8.encode(rawMessage));

    final response = await http.post(
      url,
      headers: {...authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'raw': encodedMessage}),
    );

    if (response.statusCode != 200) {
      throw Exception('Mail gönderilemedi: ${response.statusCode}');
    }
  }

  String _createRawEmail(String to, String subject, String body) {
    return 'To: $to\r\n'
        'Subject: $subject\r\n'
        'Content-Type: text/plain; charset="UTF-8"\r\n'
        'Content-Transfer-Encoding: 7bit\r\n'
        '\r\n'
        '$body';
  }

  Future<Map<String, dynamic>> readInbox({
    String? query,
    int maxResults = 10,
    String? pageToken,
  }) async {
    return _fetchEmails(
      query: query,
      maxResults: maxResults,
      pageToken: pageToken,
    );
  }

  Future<Map<String, dynamic>> searchEmails({
    required String query,
    int maxResults = 10,
    String? pageToken,
  }) async {
    return _fetchEmails(
      query: query,
      maxResults: maxResults,
      pageToken: pageToken,
    );
  }

  Future<Map<String, dynamic>> _fetchEmails({
    String? query,
    int maxResults = 10,
    String? pageToken,
  }) async {
    if (_currentUser == null) throw Exception('Gmail bağlı değil');

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final queryParams = {
        'maxResults': maxResults.toString(),
        if (query != null && query.isNotEmpty) 'q': query,
        if (pageToken != null) 'pageToken': pageToken,
      };

      final listUrl = Uri.https(
        'gmail.googleapis.com',
        '/gmail/v1/users/me/messages',
        queryParams,
      );

      final response = await http.get(listUrl, headers: authHeaders);

      if (response.statusCode != 200) {
        if (response.statusCode == 403) {
          throw Exception('Gmail Erişim Hatası (403): İzin reddedildi.');
        }
        throw Exception('Gmail List Hatası: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final messages = data['messages'] as List?;
      final nextPageToken = data['nextPageToken'] as String?;

      if (messages == null || messages.isEmpty) {
        return {'messages': <Map<String, dynamic>>[], 'nextPageToken': null};
      }

      final List<Map<String, dynamic>> result = [];

      for (var msg in messages) {
        final detail = await _getMessageDetail(msg['id'], authHeaders);
        if (detail != null) {
          result.add(detail);
        }
      }

      return {'messages': result, 'nextPageToken': nextPageToken};
    } catch (e) {
      print('❌ Gmail Fetch Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getMessageDetail(
    String id,
    Map<String, String> headers,
  ) async {
    final url = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/$id',
    );
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final payload = data['payload'];
      final headersList = payload['headers'] as List;

      String from = '';
      String subject = '';

      for (var header in headersList) {
        if (header['name'].toString().toLowerCase() == 'from') {
          from = header['value'];
        }
        if (header['name'].toString().toLowerCase() == 'subject') {
          subject = header['value'];
        }
      }

      return {
        'id': id,
        'snippet': data['snippet'],
        'from': from,
        'subject': subject,
        'date': data['internalDate'],
      };
    }
    return null;
  }
}
