import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';
import 'package:pathplanner/coderunner/fs/coderunner_file_system.dart';
import 'package:pathplanner/coderunner/fs/sync_queue.dart';

class FakeClient extends DeployFilesClient {
  final List<String> ops = [];
  final List<SnapshotFile> snapshot;

  FakeClient({this.snapshot = const []}) : super(baseUrl: '/unused');

  @override
  Future<List<SnapshotFile>> fetchSnapshot() async => snapshot;

  @override
  Future<void> putFile(String path, String content) async {
    ops.add('PUT $path=$content');
  }

  @override
  Future<void> deleteFile(String path) async {
    ops.add('DELETE $path');
  }
}

const pp = 'src/main/deploy/pathplanner';

Future<(CodeRunnerFileSystem, FakeClient, SyncQueue)> boot(
    {List<SnapshotFile> snapshot = const []}) async {
  final client = FakeClient(snapshot: snapshot);
  final queue = SyncQueue(client: client);
  final fs = await CodeRunnerFileSystem.hydrate(client: client, queue: queue);
  return (fs, client, queue);
}

void main() {
  test('hydrate populates snapshot files and the gradle marker', () async {
    final (fs, _, _) = await boot(snapshot: [
      const SnapshotFile(path: '$pp/paths/Example.path', content: '{"v": 1}'),
      const SnapshotFile(
          path: 'src/main/deploy/choreo/Traj.traj', content: '{}'),
    ]);

    expect(fs.file('/project/$pp/paths/Example.path').readAsStringSync(),
        '{"v": 1}');
    expect(fs.file('/project/src/main/deploy/choreo/Traj.traj').existsSync(),
        true);
    expect(fs.file('/project/build.gradle').existsSync(), true);
    expect(fs.directory('/project/$pp').existsSync(), true);
  });

  test('writeAsString mirrors a PUT with the project-relative path', () async {
    final (fs, client, queue) = await boot();
    // ProjectPage creates paths/ and autos/ on init; mirror that here.
    fs.directory('/project/$pp/paths').createSync(recursive: true);

    await fs.file('/project/$pp/paths/New.path').writeAsString('{"a": 1}');
    await queue.idle;

    expect(client.ops, ['PUT $pp/paths/New.path={"a": 1}']);
  });

  test('sync variants mirror too', () async {
    final (fs, client, queue) = await boot();

    fs.file('/project/$pp/settings.json').writeAsStringSync('{}');
    await queue.idle;

    expect(client.ops, ['PUT $pp/settings.json={}']);
  });

  test('createSync mirrors an empty file', () async {
    final (fs, client, queue) = await boot();

    fs.file('/project/$pp/settings.json').createSync(recursive: true);
    await queue.idle;

    expect(client.ops, ['PUT $pp/settings.json=']);
  });

  test('delete mirrors a DELETE', () async {
    final (fs, client, queue) = await boot(snapshot: [
      const SnapshotFile(path: '$pp/paths/Old.path', content: '{}'),
    ]);

    await fs.file('/project/$pp/paths/Old.path').delete();
    await queue.idle;

    expect(client.ops, ['DELETE $pp/paths/Old.path']);
  });

  test('rename mirrors PUT of the new path then DELETE of the old', () async {
    final (fs, client, queue) = await boot(snapshot: [
      const SnapshotFile(path: '$pp/paths/Old.path', content: '{"v": 1}'),
    ]);

    await fs
        .file('/project/$pp/paths/Old.path')
        .rename('/project/$pp/paths/New.path');
    await queue.idle;

    expect(client.ops,
        ['PUT $pp/paths/New.path={"v": 1}', 'DELETE $pp/paths/Old.path']);
    expect(fs.file('/project/$pp/paths/New.path').existsSync(), true);
    expect(fs.file('/project/$pp/paths/Old.path').existsSync(), false);
  });

  test('files outside the synced subtree are not mirrored', () async {
    final (fs, client, queue) = await boot();
    fs.directory('/project/src/main/deploy/choreo').createSync(recursive: true);

    fs.file('/project/build.gradle').writeAsStringSync('x');
    fs.file('/project/src/main/deploy/choreo/T.traj').writeAsStringSync('{}');
    await queue.idle;

    expect(client.ops, isEmpty);
  });

  test('directory operations are not mirrored', () async {
    final (fs, client, queue) = await boot();

    fs.directory('/project/$pp/paths').createSync(recursive: true);
    await queue.idle;

    expect(client.ops, isEmpty);
  });
}
