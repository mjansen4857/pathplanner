import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';
import 'package:pathplanner/coderunner/fs/sync_queue.dart';

/// Records operations; can be primed to fail the next N calls.
class RecordingClient extends DeployFilesClient {
  final List<String> ops = [];
  int failuresRemaining = 0;

  RecordingClient() : super(baseUrl: '/unused');

  Future<void> _run(String op) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const DeployFilesException(statusCode: 500, message: 'boom');
    }
    ops.add(op);
  }

  @override
  Future<void> putFile(String path, String content) =>
      _run('PUT $path=$content');

  @override
  Future<void> deleteFile(String path) => _run('DELETE $path');
}

void main() {
  test('executes puts and deletes in order', () async {
    final client = RecordingClient();
    final queue = SyncQueue(client: client);

    queue.enqueuePut('a.path', '1');
    queue.enqueuePut('b.path', '2');
    queue.enqueueDelete('c.path');
    await queue.idle;

    expect(client.ops, ['PUT a.path=1', 'PUT b.path=2', 'DELETE c.path']);
    expect(queue.state.value, SaveState.saved);
  });

  test('a delete drops a pending put for the same path', () async {
    final client = RecordingClient();
    final queue = SyncQueue(client: client);

    // Creating then deleting a file before the first flush leaves nothing
    // to upload; the DELETE alone reaches the server (404 counts as success).
    queue.enqueuePut('a.path', '1');
    queue.enqueueDelete('a.path');
    await queue.idle;

    expect(client.ops, ['DELETE a.path']);
  });

  test('coalesces same-tick puts to the same path', () async {
    final client = RecordingClient();
    final queue = SyncQueue(client: client);

    // Drain starts one event-loop turn after the first enqueue, so
    // synchronous bursts coalesce before any request fires.
    queue.enqueuePut('a.path', '1');
    queue.enqueuePut('a.path', '2');
    queue.enqueuePut('a.path', '3');
    await queue.idle;

    expect(client.ops, ['PUT a.path=3']);
  });

  test('retries a failed op and reports error state meanwhile', () async {
    final client = RecordingClient();
    client.failuresRemaining = 2;
    final queue =
        SyncQueue(client: client, retryDelay: const Duration(milliseconds: 1));
    final states = <SaveState>[];
    queue.state.addListener(() => states.add(queue.state.value));

    queue.enqueuePut('a.path', '1');
    await queue.idle;

    expect(client.ops, ['PUT a.path=1']);
    expect(states, contains(SaveState.error));
    expect(queue.state.value, SaveState.saved);
  });

  test('idle completes immediately when nothing is queued', () async {
    final queue = SyncQueue(client: RecordingClient());
    await queue.idle;
  });
}
