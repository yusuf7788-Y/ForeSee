import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:convert';
import 'dart:async';
import 'storage_service.dart';

class GitHubService {
  static final GitHubService instance = GitHubService._internal();
  GitHubService._internal();
  factory GitHubService() => instance;

  static final String _clientId = dotenv.get('GITHUB_CLIENT_ID');
  static final String _clientSecret = dotenv.get('GITHUB_CLIENT_SECRET');
  static const String _redirectUri = "foresee://github-auth";

  final _storageService = StorageService();

  String? _accessToken;
  bool isConnected() => _accessToken != null;
  String? get accessToken => _accessToken;

  Future<void> initialize() async {
    _accessToken = await _storageService.getGithubAccessToken();
  }

  Future<void> signOut() async {
    _accessToken = null;
    await _storageService.setGithubAccessToken(null);
  }

  final _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;

  Future<bool> authenticate() async {
    // Cancel any existing subscription to prevent duplicates
    await _linkSubscription?.cancel();
    _linkSubscription = null;

    final completer = Completer<bool>();

    // 1. Listen for the redirect
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'foresee' && uri.host == 'github-auth') {
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (code != null) {
          if (!completer.isCompleted) {
            final success = await _exchangeCodeForToken(code);
            if (!completer.isCompleted) completer.complete(success);
            await _linkSubscription?.cancel();
          }
        } else if (error != null) {
          if (!completer.isCompleted) completer.complete(false);
          await _linkSubscription?.cancel();
        }
        // Use ignoring logic for robustness
      }
    });

    // 2. Open GitHub Login
    final url = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': 'repo,user:email',
    });

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!completer.isCompleted) completer.complete(false);
      await _linkSubscription?.cancel();
    }

    return completer.future;
  }

  Future<bool> _exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse('https://github.com/login/oauth/access_token'),
      headers: {'Accept': 'application/json'},
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'code': code,
        'redirect_uri': _redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      if (_accessToken != null) {
        await _storageService.setGithubAccessToken(_accessToken);
      }
      return _accessToken != null;
    }
    return false;
  }

  Future<Map<String, dynamic>> getRepoContent({
    required String owner,
    required String repo,
    String path = '',
  }) async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$path',
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        if (_accessToken != null) 'Authorization': 'token $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return {
        'status': 'success',
        'title': '$owner/$repo${path.isNotEmpty ? '/$path' : ''}',
        'content': decoded,
        'added': 0, // Diffs are not applicable for simple read
        'removed': 0,
      };
    } else {
      throw Exception('GitHub Hatası: ${response.statusCode}');
    }
  }

  Future<void> starRepo(String owner, String repo) async {
    if (_accessToken == null) throw Exception('GitHub bağlı değil');

    final url = Uri.https('api.github.com', '/user/starred/$owner/$repo');
    final response = await http.put(
      url,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': 'token $_accessToken',
        'Content-Length': '0',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Yıldızlama hatası: ${response.statusCode}');
    }
  }

  Future<void> unstarRepo(String owner, String repo) async {
    if (_accessToken == null) throw Exception('GitHub bağlı değil');

    final url = Uri.https('api.github.com', '/user/starred/$owner/$repo');
    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': 'token $_accessToken',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Yıldız kaldırma hatası: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getStarredRepos({
    String? username,
    int page = 1,
    int perPage = 10,
  }) async {
    final String path = username != null
        ? '/users/$username/starred'
        : '/user/starred';

    final url = Uri.https('api.github.com', path, {
      'page': page.toString(),
      'per_page': perPage.toString(),
      'sort': 'created',
      'direction': 'desc',
    });

    final headers = {'Accept': 'application/vnd.github.v3+json'};
    if (_accessToken != null) {
      headers['Authorization'] = 'token $_accessToken';
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return _parseRepos(response.body);
    } else {
      throw Exception(
        'Yıldızlı Repoları Getirme Hatası: ${response.statusCode}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getUserRepos({
    String? username,
    int page = 1,
    int perPage = 10,
  }) async {
    final String path = username != null
        ? '/users/$username/repos'
        : '/user/repos';

    final url = Uri.https('api.github.com', path, {
      'page': page.toString(),
      'per_page': perPage.toString(),
      'sort': 'updated',
      'direction': 'desc',
    });

    final headers = {'Accept': 'application/vnd.github.v3+json'};
    if (_accessToken != null) {
      headers['Authorization'] = 'token $_accessToken';
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return _parseRepos(response.body);
    } else {
      throw Exception('Repo Listeleme Hatası: ${response.statusCode}');
    }
  }

  // Legacy support for existing tool, redirect to getUserRepos (self)
  Future<List<Map<String, dynamic>>> listRepositories() async {
    return getUserRepos();
  }

  List<Map<String, dynamic>> _parseRepos(String jsonBody) {
    final List<dynamic> repos = jsonDecode(jsonBody);
    return repos
        .map(
          (r) => {
            'name': r['name'],
            'full_name': r['full_name'],
            'description': r['description'],
            'private': r['private'],
            'updated_at': r['updated_at'],
            'stargazers_count': r['stargazers_count'],
            'language': r['language'],
            'html_url': r['html_url'],
          },
        )
        .toList();
  }
}
