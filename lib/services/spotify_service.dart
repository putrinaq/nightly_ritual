import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'ritual_storage_service.dart';

class SpotifyService {
  // ---------------------------------------------------------------------------
  // CONFIGURATION
  // ---------------------------------------------------------------------------

  // 🔴 BYPASS MODE: Paste your temporary token here to work while dashboard is broken.
  // If this string is NOT empty, the app will ignore login and use this token.
  static const String tempAccessToken = '';

  static const String clientId = '35ce1665a3584353861e6e4155d2d0b6';
  static const String clientSecret = '3ef1f171627e4c03b3e26c8e39e27155';

  // The secure redirect URI we discussed (requires Dashboard update eventually)
  static const String redirectUri = 'ritual://callback';
  static const String redirectScheme = 'ritual';

  // YOUR SPECIFIC PLAYLIST
  static const String playlistUri = 'spotify:playlist:3U6Qv1uKzBbxK7EwKYO9Ou';
  static const String playlistUrl =
      'https://open.spotify.com/playlist/3U6Qv1uKzBbxK7EwKYO9Ou';

  // ---------------------------------------------------------------------------
  // OFFICIAL ENDPOINTS (Corrected)
  // ---------------------------------------------------------------------------
  static const String _authEndpoint = 'https://accounts.spotify.com/authorize';
  static const String _tokenEndpoint = 'https://accounts.spotify.com/api/token';
  static const String _baseApiUrl = 'https://api.spotify.com/v1';
  static const String _playerEndpoint = '$_baseApiUrl/me/player';

  final RitualStorageService _storage;
  String? _accessToken;
  bool _isConnected = false;

  SpotifyService(this._storage);

  bool get isConnected => _isConnected;

  /// Initialize the service
  Future<void> init() async {
    // 1. Check if we are using the manual bypass token
    if (tempAccessToken.isNotEmpty) {
      debugPrint('⚠️ SPOTIFY: Using temporary hardcoded token');
      _accessToken = tempAccessToken;
      _isConnected = await _validateToken();
      return;
    }

    // 2. Otherwise, load from storage
    _accessToken = _storage.getSpotifyAccessToken();
    if (_accessToken != null) {
      _isConnected = await _validateToken();
      if (!_isConnected) {
        // Token might be expired, try refresh
        debugPrint('Spotify token invalid, attempting refresh...');
        await refreshToken();
      }
    }
  }

  /// Check if the current token actually works
  Future<bool> _validateToken() async {
    if (_accessToken == null) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseApiUrl/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Validation error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  Future<bool> authenticate() async {
    try {
      final scopes = [
        'user-read-playback-state',
        'user-modify-playback-state',
        'user-read-currently-playing',
        'streaming',
        'app-remote-control',
        'user-read-private', // Added to get profile info
        'user-read-email' // Added to get profile info
      ].join(' ');

      final authUrl = '$_authEndpoint?'
          'client_id=$clientId&'
          'response_type=code&'
          'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
          'scope=${Uri.encodeComponent(scopes)}';

      debugPrint('Launching Spotify Auth: $authUrl');

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: redirectScheme,
        options: const FlutterWebAuth2Options(
          preferEphemeral: true,
        ),
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null) {
        debugPrint('Spotify auth failed: No code returned');
        return false;
      }

      return await _exchangeCodeForToken(code);
    } catch (e) {
      debugPrint('Spotify authentication error: $e');
      return false;
    }
  }

  Future<bool> _exchangeCodeForToken(String code) async {
    try {
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data);
        return true;
      }

      debugPrint('Token exchange failed: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return false;
    }
  }

  Future<bool> refreshToken() async {
    // Cannot refresh a hardcoded manual token
    if (tempAccessToken.isNotEmpty) return false;

    final refreshToken = _storage.getSpotifyRefreshToken();
    if (refreshToken == null) return false;

    try {
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Provide the old refresh token if the new response doesn't include one
        if (!data.containsKey('refresh_token')) {
          data['refresh_token'] = refreshToken;
        }
        await _saveTokens(data);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    _accessToken = data['access_token'];
    _isConnected = true;
    await _storage.saveSpotifyTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
      expiresIn: data['expires_in'],
    );
  }

  // ---------------------------------------------------------------------------
  // PLAYBACK CONTROL
  // ---------------------------------------------------------------------------

  Future<bool> playPlaylist() async {
    if (_accessToken == null) {
      if (!await refreshToken()) return false;
    }

    try {
      // 1. Get active devices
      final devicesResponse = await http.get(
        Uri.parse('$_playerEndpoint/devices'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (devicesResponse.statusCode == 200) {
        final devices = jsonDecode(devicesResponse.body)['devices'] as List;

        if (devices.isEmpty) {
          debugPrint('No active devices found. Opening Spotify app...');
          await openSpotifyPlaylist();
          return false;
        }

        // 2. Find best device (Smartphone > Computer > First Available)
        String? deviceId;
        for (var device in devices) {
          if (device['is_active'] == true) {
            deviceId = device['id'];
            break;
          }
        }
        deviceId ??= devices.first['id'];

        // 3. Command Play
        final playResponse = await http.put(
          Uri.parse('$_playerEndpoint/play?device_id=$deviceId'),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'context_uri': playlistUri,
            // Optional: Start from offset 0 (first song)
            'offset': {'position': 0}
          }),
        );

        if (playResponse.statusCode == 204 || playResponse.statusCode == 200) {
          return true;
        } else {
          debugPrint('Play command failed: ${playResponse.body}');
        }
      }
      return false;
    } catch (e) {
      debugPrint('Play error: $e');
      return false;
    }
  }

  Future<bool> pausePlayback() async {
    if (_accessToken == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$_playerEndpoint/pause'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

// Resume playback (continue where left off)
  Future<bool> resumePlayback() async {
    if (_accessToken == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$_playerEndpoint/play'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Resume error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentPlayback() async {
    if (_accessToken == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$_playerEndpoint'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> openSpotifyPlaylist() async {
    final uri = Uri.parse(playlistUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> disconnect() async {
    await _storage.clearSpotifyTokens();
    _accessToken = null;
    _isConnected = false;
  }
}
