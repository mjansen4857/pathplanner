import 'dart:convert';

import 'package:http/http.dart' as http;

/// One file in the deploy-files snapshot. [path] is relative to the
/// project root (e.g. 'src/main/deploy/pathplanner/paths/Example.path').
class SnapshotFile {
  final String path;
  final String content;

  const SnapshotFile({required this.path, required this.content});
}

class DeployFilesException implements Exception {
  final int? statusCode;
  final String message;

  const DeployFilesException({this.statusCode, required this.message});

  @override
  String toString() => 'DeployFilesException($statusCode): $message';
}

/// Typed client for CodeRunner's deploy-files API. Same-origin requests,
/// so the CodeRunner session cookie authenticates automatically.
class DeployFilesClient {
  final String baseUrl;
  final http.Client _http;

  DeployFilesClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<List<SnapshotFile>> fetchSnapshot() async {
    final response = await _http.get(Uri.parse('$baseUrl/snapshot'));
    if (response.statusCode != 200) {
      throw _errorFrom(response);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final files = json['files'] as List<dynamic>;
    return [
      for (final f in files.cast<Map<String, dynamic>>())
        SnapshotFile(path: f['path'] as String, content: f['content'] as String)
    ];
  }

  /// Percent-encode each segment (path/auto names can contain spaces and
  /// parens) while keeping the '/' separators literal.
  Uri _fileUri(String path) => Uri.parse(
      '$baseUrl/${path.split('/').map(Uri.encodeComponent).join('/')}');

  Future<void> putFile(String path, String content) async {
    final response = await _http.put(
      _fileUri(path),
      headers: {'Content-Type': 'text/plain; charset=utf-8'},
      body: content,
    );
    if (response.statusCode != 200) {
      throw _errorFrom(response);
    }
  }

  Future<void> deleteFile(String path) async {
    final response = await _http.delete(_fileUri(path));
    // 404 means the file never reached the server (e.g. created and
    // deleted before its first PUT was flushed) — the end state matches.
    if (response.statusCode != 200 && response.statusCode != 404) {
      throw _errorFrom(response);
    }
  }

  DeployFilesException _errorFrom(http.Response response) {
    String message = 'HTTP ${response.statusCode}';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['error'] is String) {
        message = json['error'] as String;
      }
    } catch (_) {
      // Non-JSON error body; keep the status message.
    }
    return DeployFilesException(
        statusCode: response.statusCode, message: message);
  }
}
