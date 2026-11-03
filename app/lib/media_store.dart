import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaStore {
  static final _host = RegExp(r'^dishcovery-media\.[a-z0-9-]+\.workers\.dev$');
  static final _key = RegExp(
    r'^r2:[0-9a-f-]{36}/(recipe|avatar)/[0-9a-f]{64}$',
  );
  static Uri? _origin;

  static Future<Uri?> origin(SupabaseClient client) async {
    if (_origin != null) return _origin;
    final row = await client
        .from('dishcovery_media_config')
        .select('origin')
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    if (row == null) return null;
    final uri = Uri.parse(row['origin'] as String);
    if (uri.scheme != 'https' ||
        !_host.hasMatch(uri.host) ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid photo service');
    }
    return _origin = uri;
  }

  static Future<Uint8List> _request(
    SupabaseClient client,
    Uri url, {
    Uint8List? bytes,
  }) async {
    final session = client.auth.currentSession;
    if (session == null) throw StateError('Sign in to access this photo');
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await http.openUrl(bytes == null ? 'GET' : 'POST', url);
      request.followRedirects = false;
      request.headers.set('Authorization', 'Bearer ${session.accessToken}');
      if (bytes != null) {
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw HttpException('Photo service returned ${response.statusCode}');
      }
      final result = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        result.add(chunk);
        if (result.length > 3 * 1024 * 1024) {
          throw const FormatException('Photo too large');
        }
      }
      return result.takeBytes();
    } finally {
      http.close(force: true);
    }
  }

  static Future<String> upload(
    SupabaseClient client,
    Uint8List bytes,
    String kind,
  ) async {
    final endpoint = await origin(client);
    if (endpoint == null) throw StateError('Photo storage is not activated');
    final result = await _request(
      client,
      endpoint.resolve('/photos/$kind'),
      bytes: bytes,
    );
    final value = jsonDecode(utf8.decode(result))['image'] as String;
    if (!_key.hasMatch(value)) {
      throw const FormatException('Invalid photo reference');
    }
    return value;
  }

  static Future<Uint8List> read(String reference) async {
    if (!_key.hasMatch(reference)) throw const FormatException('Invalid photo');
    final client = Supabase.instance.client;
    final endpoint = await origin(client);
    if (endpoint == null) throw StateError('Photo storage unavailable');
    return _request(
      client,
      endpoint.resolve('/photos/${reference.substring(3)}'),
    );
  }
}
