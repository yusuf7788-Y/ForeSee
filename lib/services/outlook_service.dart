import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:convert';
import 'dart:async';
import 'storage_service.dart';

class OutlookService {
  static final OutlookService instance = OutlookService._internal();
  OutlookService._internal();
  factory OutlookService() => instance;

  // Keys will be provided by user
  static final String _clientId = dotenv.get('OUTLOOK_CLIENT_ID', fallback: '');
  // static final String _clientSecret = dotenv.get('OUTLOOK_CLIENT_SECRET', fallback: ''); // Authorization Code Flow usually requires Secret if not PKCE, but for Mobile Apps (Public Client) sometimes ID is enough.
  // Standard OAuth2 for Mobile usually implies PKCE, but Microsoft Graph often uses Client Secret for "Confidential Clients".
  // For "Public Clients" (Mobile/Desktop), we don't use Client Secret. We use PKCE.
  // However, simplicity sake, if the user provides a secret, we use it. If not, we might fail if the Azure app app requires it.
  // Assuming commonly used "Web" app type registration for simplicity in these AI integrations unless specified "Mobile/Native".

  static const String _redirectUri = "foresee://outlook-auth";
  static const String _authority = "https://login.microsoftonline.com/common";
  static const String _scope = "offline_access User.Read Mail.Read Mail.Send";

  final _storageService = StorageService();

  String? _accessToken;
  bool isConnected() => _accessToken != null;
  String? get accessToken => _accessToken;

  Future<void> initialize() async {
    _accessToken = await _storageService.getOutlookAccessToken();
  }

  Future<void> signOut() async {
    _accessToken = null;
    await _storageService.setOutlookAccessToken(null);
    await _storageService.setIsOutlookConnected(false);
  }

  final _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;

  Future<bool> authenticate() async {
    // Cancel any existing subscription to prevent duplicates
    await _linkSubscription?.cancel();
    _linkSubscription = null;

    final completer = Completer<bool>();

    if (_clientId.isEmpty) {
      throw Exception("OUTLOOK_CLIENT_ID .env dosyasında bulunamadı.");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'foresee' && uri.host == 'outlook-auth') {
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (code != null) {
          if (!completer.isCompleted) {
            final success = await _exchangeCodeForToken(code);
            if (!completer.isCompleted) completer.complete(success);
            await _linkSubscription?.cancel();
          }
        } else if (error != null) {
          print("Outlook Auth Error: $error");
          if (!completer.isCompleted) completer.complete(false);
          await _linkSubscription?.cancel();
        }
        // If code/error are null, ignore (invalid event)
      }
    });

    final url = Uri.parse(
      '$_authority/oauth2/v2.0/authorize?client_id=$_clientId&response_type=code&redirect_uri=$_redirectUri&response_mode=query&scope=$_scope',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!completer.isCompleted) completer.complete(false);
      await _linkSubscription?.cancel();
    }

    return completer.future;
  }

  Future<bool> _exchangeCodeForToken(String code) async {
    // For public clients, we don't send client_secret usually.
    // If the user registered as Web App, they have a secret. If Native, they don't.
    // Let's try without secret first (Public Client flow) or check if we have one.
    // final secret = dotenv.get('OUTLOOK_CLIENT_SECRET', fallback: '');

    final body = {
      'client_id': _clientId,
      'scope': _scope,
      'code': code,
      'redirect_uri': _redirectUri,
      'grant_type': 'authorization_code',
      // if (secret.isNotEmpty) 'client_secret': secret,
    };

    final response = await http.post(
      Uri.parse('$_authority/oauth2/v2.0/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      if (_accessToken != null) {
        await _storageService.setOutlookAccessToken(_accessToken);
        await _storageService.setIsOutlookConnected(true);
      }
      return _accessToken != null;
    } else {
      print("Outlook Token Error: ${response.body}");
      return false;
    }
  }

  Future<Map<String, dynamic>> readInbox({
    String? query,
    int maxResults = 10,
  }) async {
    if (_accessToken == null) throw Exception('Outlook bağlı değil');

    // Graph API select/filter
    String url =
        'https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages?\$top=$maxResults&\$select=sender,subject,bodyPreview,receivedDateTime';

    if (query != null && query.isNotEmpty) {
      // OData filter syntax: $filter=contains(subject, 'text')
      // Simple search: $search="text"
      url += '&\$search="$query"';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Prefer': 'outlook.body-content-type="text"',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> value = data['value'];

      return {
        'messages': value
            .map(
              (m) => {
                'from':
                    m['sender']['emailAddress']['name'] ??
                    m['sender']['emailAddress']['address'],
                'subject': m['subject'],
                'snippet': m['bodyPreview'],
                'date': m['receivedDateTime'],
              },
            )
            .toList(),
      };
    } else {
      if (response.statusCode == 401) {
        // Token might be expired. Handle refresh later.
        await signOut(); // For now, force logout
        throw Exception('Oturum süresi doldu. Lütfen tekrar giriş yapın.');
      }
      throw Exception('Outlook API Hatası: ${response.statusCode}');
    }
  }

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (_accessToken == null) throw Exception('Outlook bağlı değil');

    final url = Uri.parse('https://graph.microsoft.com/v1.0/me/sendMail');

    final payload = {
      "message": {
        "subject": subject,
        "body": {"contentType": "Text", "content": body},
        "toRecipients": [
          {
            "emailAddress": {"address": to},
          },
        ],
      },
      "saveToSentItems": "true",
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 202) {
      throw Exception(
        'Outlook Mail Gönderme Hatası: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
