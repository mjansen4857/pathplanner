import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';

void main() {
  const base = '/u/test-user/api/deploy-files';

  test('fetchSnapshot parses files from the snapshot response', () async {
    final mock = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '$base/snapshot');
      return http.Response(
          jsonEncode({
            'ok': true,
            'files': [
              {
                'path': 'src/main/deploy/pathplanner/paths/Test.path',
                'content': '{"version": "2025.0"}',
              },
            ],
          }),
          200);
    });

    final client = DeployFilesClient(baseUrl: base, httpClient: mock);
    final files = await client.fetchSnapshot();

    expect(files, hasLength(1));
    expect(files[0].path, 'src/main/deploy/pathplanner/paths/Test.path');
    expect(files[0].content, '{"version": "2025.0"}');
  });

  test('fetchSnapshot throws DeployFilesException on non-200', () async {
    final mock = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'nope'}), 403));
    final client = DeployFilesClient(baseUrl: base, httpClient: mock);

    await expectLater(
        client.fetchSnapshot(),
        throwsA(isA<DeployFilesException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'nope')));
  });

  test('putFile sends raw text body to the file path', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final client = DeployFilesClient(baseUrl: base, httpClient: mock);

    await client.putFile(
        'src/main/deploy/pathplanner/paths/Test.path', '{"a": 1}');

    expect(captured.method, 'PUT');
    expect(
        captured.url.path, '$base/src/main/deploy/pathplanner/paths/Test.path');
    expect(captured.body, '{"a": 1}');
    expect(captured.headers['Content-Type'],
        startsWith('text/plain; charset=utf-8'));
  });

  test('putFile percent-encodes path segments but not separators', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final client = DeployFilesClient(baseUrl: base, httpClient: mock);

    await client.putFile(
        'src/main/deploy/pathplanner/paths/Two Piece (Left).path', '{}');

    // Spaces are encoded and the '/' separators stay literal. Parens are
    // legal in a URI path, so Uri.encodeComponent leaves them alone.
    expect(captured.url.toString(),
        contains('/pathplanner/paths/Two%20Piece%20(Left).path'));
  });

  test('putFile throws on error status', () async {
    final mock = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'bad'}), 400));
    final client = DeployFilesClient(baseUrl: base, httpClient: mock);

    await expectLater(client.putFile('src/main/deploy/pathplanner/x.path', ''),
        throwsA(isA<DeployFilesException>()));
  });

  test('deleteFile treats 404 as success', () async {
    final mock = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'gone'}), 404));
    final client = DeployFilesClient(baseUrl: base, httpClient: mock);

    await client.deleteFile('src/main/deploy/pathplanner/paths/Gone.path');
  });

  test('deleteFile throws on server error', () async {
    final mock = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'boom'}), 500));
    final client = DeployFilesClient(baseUrl: base, httpClient: mock);

    await expectLater(client.deleteFile('src/main/deploy/pathplanner/x.path'),
        throwsA(isA<DeployFilesException>()));
  });
}
