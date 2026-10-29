import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Spotify settings from `.env`, so anyone can plug in their own app from
/// the Spotify developer dashboard:
///
///   SPOTIFY_CLIENT_ID=<your client id>
///   SPOTIFY_REDIRECT_URI=ritual://callback          (mobile)
///   SPOTIFY_WEB_REDIRECT_URI=https://…/auth.html     (web, optional)
///
/// Each redirect URI must be added, exactly, under "Redirect URIs" in the
/// dashboard. No client secret is used: the app authenticates with PKCE,
/// which is Spotify's recommended flow for apps that can't keep a secret.
class SpotifyConfig {
  final String clientId;
  final String redirectUri;

  const SpotifyConfig({required this.clientId, required this.redirectUri});

  factory SpotifyConfig.fromEnv() {
    String env(String k) => (dotenv.maybeGet(k) ?? '').trim();
    final mobile = env('SPOTIFY_REDIRECT_URI');
    final web = env('SPOTIFY_WEB_REDIRECT_URI');
    return SpotifyConfig(
      clientId: env('SPOTIFY_CLIENT_ID'),
      redirectUri: kIsWeb
          ? (web.isNotEmpty ? web : '${Uri.base.origin}/auth.html')
          : (mobile.isNotEmpty ? mobile : 'ritual://callback'),
    );
  }

  bool get isConfigured => clientId.isNotEmpty;

  /// The scheme the auth browser hands control back on (`ritual`).
  String get callbackScheme => Uri.parse(redirectUri).scheme;
}

enum SpotifyStatus { notConfigured, disconnected, connecting, connected }

enum PlaybackResult { playing, noDevice, premiumRequired, notConnected, failed }

class SpotifyPlaylist {
  final String name;
  final String url;
  final String uri;
  final String? imageUrl;
  final int? trackCount;

  const SpotifyPlaylist({
    required this.name,
    required this.url,
    required this.uri,
    this.imageUrl,
    this.trackCount,
  });
}

class SpotifyAuthException implements Exception {
  final String message;
  const SpotifyAuthException(this.message);
  @override
  String toString() => message;
}

class SpotifyService extends ChangeNotifier {
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal();

  static const _scopes = [
    'playlist-read-private',
    'playlist-read-collaborative',
    'user-read-playback-state',
    'user-modify-playback-state',
  ];

  static const _kAccess = 'spotify.access_token';
  static const _kRefresh = 'spotify.refresh_token';
  static const _kExpiry = 'spotify.expires_at';
  static const _kName = 'spotify.display_name';

  final _accounts = Uri.parse('https://accounts.spotify.com');
  static const _api = 'https://api.spotify.com/v1';

  SharedPreferences? _prefs;
  SpotifyConfig _config = const SpotifyConfig(clientId: '', redirectUri: '');
  SpotifyStatus _status = SpotifyStatus.notConfigured;
  String? _displayName;
  Future<bool>? _refreshing;

  SpotifyStatus get status => _status;
  bool get isConnected => _status == SpotifyStatus.connected;
  String? get displayName => _displayName;
  SpotifyConfig get config => _config;

  Future<void> init() async {
    _config = SpotifyConfig.fromEnv();
    _prefs = await SharedPreferences.getInstance();
    if (!_config.isConfigured) {
      _set(SpotifyStatus.notConfigured);
      return;
    }
    final hasSession = _prefs!.getString(_kRefresh) != null;
    _displayName = _prefs!.getString(_kName);
    _set(hasSession ? SpotifyStatus.connected : SpotifyStatus.disconnected);
  }

  void _set(SpotifyStatus s) {
    _status = s;
    notifyListeners();
  }

  // ── Auth ────────────────────────────────────────────────────────────────

  static String _randomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static String _challengeFor(String verifier) =>
      base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');

  /// Opens Spotify's sign-in page. Returns false if the person cancels;
  /// throws [SpotifyAuthException] with a readable message on failure.
  Future<bool> connect() async {
    if (!_config.isConfigured) {
      throw const SpotifyAuthException('Add SPOTIFY_CLIENT_ID to your .env file first.');
    }
    final verifier = _randomString(64);
    final state = _randomString(16);
    final authUrl = _accounts.replace(path: '/authorize', queryParameters: {
      'client_id': _config.clientId,
      'response_type': 'code',
      'redirect_uri': _config.redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': _challengeFor(verifier),
      'scope': _scopes.join(' '),
      'state': state,
    });

    _set(SpotifyStatus.connecting);
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _config.callbackScheme,
      );
      final params = Uri.parse(result).queryParameters;
      final error = params['error'];
      if (error == 'access_denied') {
        _set(SpotifyStatus.disconnected);
        return false;
      }
      if (error != null) throw SpotifyAuthException('Spotify said: $error');
      if (params['state'] != state) {
        throw const SpotifyAuthException('Sign-in response did not match. Try again.');
      }
      final code = params['code'];
      if (code == null) throw const SpotifyAuthException('Spotify returned no code.');

      await _token({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _config.redirectUri,
        'client_id': _config.clientId,
        'code_verifier': verifier,
      });
      await _loadProfile();
      _set(SpotifyStatus.connected);
      return true;
    } on PlatformException catch (e) {
      _set(SpotifyStatus.disconnected);
      if (e.code == 'CANCELED') return false;
      throw SpotifyAuthException('Couldn\'t open Spotify sign-in (${e.code}).');
    } catch (e) {
      _set(SpotifyStatus.disconnected);
      if (e is SpotifyAuthException) rethrow;
      debugPrint('Spotify connect failed: $e');
      throw const SpotifyAuthException('Couldn\'t connect to Spotify. Try again.');
    }
  }

  Future<void> _token(Map<String, String> form) async {
    final res = await http.post(
      _accounts.replace(path: '/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: form,
    );
    if (res.statusCode != 200) {
      debugPrint('Spotify token error ${res.statusCode}: ${res.body}');
      final body = _tryJson(res.body);
      final desc = body?['error_description'] ?? body?['error'];
      throw SpotifyAuthException(
        desc == 'Invalid redirect URI'
            ? 'Redirect URI ${_config.redirectUri} isn\'t registered in your Spotify app.'
            : 'Spotify rejected the sign-in${desc == null ? '' : ': $desc'}.',
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final p = _prefs!;
    await p.setString(_kAccess, data['access_token'] as String);
    // PKCE refresh tokens rotate; keep the old one only if none came back.
    final refresh = data['refresh_token'] as String?;
    if (refresh != null) await p.setString(_kRefresh, refresh);
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    await p.setInt(_kExpiry, DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch);
  }

  /// A valid access token, refreshing it first if it's about to expire.
  Future<String?> _accessToken({bool force = false}) async {
    final p = _prefs;
    // Checked against stored tokens, not status: connect() calls the API
    // while still in the "connecting" state.
    if (p == null || p.getString(_kRefresh) == null && p.getString(_kAccess) == null) {
      return null;
    }
    final expiry = p.getInt(_kExpiry) ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch < expiry - 60000;
    if (fresh && !force) return p.getString(_kAccess);

    // Coalesce concurrent refreshes so a rotating refresh token isn't spent twice.
    _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
    return await _refreshing! ? p.getString(_kAccess) : null;
  }

  Future<bool> _refresh() async {
    final refresh = _prefs?.getString(_kRefresh);
    if (refresh == null) return false;
    try {
      await _token({
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'client_id': _config.clientId,
      });
      return true;
    } catch (e) {
      // A revoked or expired session: sign out locally so the UI offers
      // "Connect" again rather than failing quietly forever.
      debugPrint('Spotify refresh failed: $e');
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    final p = _prefs;
    if (p != null) {
      await p.remove(_kAccess);
      await p.remove(_kRefresh);
      await p.remove(_kExpiry);
      await p.remove(_kName);
    }
    _displayName = null;
    _set(_config.isConfigured ? SpotifyStatus.disconnected : SpotifyStatus.notConfigured);
  }

  // ── API ─────────────────────────────────────────────────────────────────

  Future<http.Response?> _call(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _accessToken(force: attempt == 1);
      if (token == null) return null;
      final uri = Uri.parse('$_api$path').replace(queryParameters: query);
      final req = http.Request(method, uri)
        ..headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 401) return res;
    }
    return null;
  }

  Future<void> _loadProfile() async {
    final res = await _call('GET', '/me');
    if (res?.statusCode == 200) {
      final me = jsonDecode(res!.body) as Map<String, dynamic>;
      _displayName = (me['display_name'] as String?) ?? (me['id'] as String?);
      if (_displayName != null) await _prefs!.setString(_kName, _displayName!);
    }
  }

  /// The signed-in person's playlists (up to 50).
  Future<List<SpotifyPlaylist>> myPlaylists() async {
    final res = await _call('GET', '/me/playlists', query: {'limit': '50'});
    if (res == null || res.statusCode != 200) return const [];
    final items = (jsonDecode(res.body)['items'] as List?) ?? const [];
    return [
      for (final raw in items)
        if (raw is Map<String, dynamic>)
          SpotifyPlaylist(
            name: (raw['name'] as String?) ?? 'Untitled',
            url: (raw['external_urls']?['spotify'] as String?) ?? '',
            uri: (raw['uri'] as String?) ?? '',
            imageUrl: ((raw['images'] as List?)?.isNotEmpty ?? false)
                ? raw['images'][0]['url'] as String?
                : null,
            trackCount: ((raw['tracks'] ?? raw['items']) as Map?)?['total'] as int?,
          ),
    ].where((p) => p.uri.isNotEmpty).toList();
  }

  /// Starts [contextUri] (playlist/album/artist) on the active device, or on
  /// the first available one when nothing is active.
  Future<PlaybackResult> play(String contextUri) async {
    if (!isConnected) return PlaybackResult.notConnected;
    try {
      var res = await _call('PUT', '/me/player/play', body: {'context_uri': contextUri});
      if (res == null) return PlaybackResult.notConnected;
      if (res.statusCode == 404) {
        final devices = await _call('GET', '/me/player/devices');
        final list = devices?.statusCode == 200
            ? (jsonDecode(devices!.body)['devices'] as List? ?? const [])
            : const [];
        if (list.isEmpty) return PlaybackResult.noDevice;
        res = await _call('PUT', '/me/player/play',
            query: {'device_id': list.first['id'] as String},
            body: {'context_uri': contextUri});
        if (res == null) return PlaybackResult.notConnected;
      }
      if (res.statusCode == 204 || res.statusCode == 200 || res.statusCode == 202) {
        return PlaybackResult.playing;
      }
      if (res.statusCode == 403) return PlaybackResult.premiumRequired;
      if (res.statusCode == 404) return PlaybackResult.noDevice;
      debugPrint('Spotify play ${res.statusCode}: ${res.body}');
      return PlaybackResult.failed;
    } catch (e) {
      debugPrint('Spotify play error: $e');
      return PlaybackResult.failed;
    }
  }

  Future<bool> pause() async {
    try {
      final res = await _call('PUT', '/me/player/pause');
      return res != null && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic>? _tryJson(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}
