// ignore_for_file: implementation_imports
// package:file/src/io.dart is the package's own web-safe re-export of
// dart:io's FileMode/File interfaces, which ForwardingFile's signatures
// are declared against.
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:file/src/io.dart' as io;
import 'package:path/path.dart' as p;
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';
import 'package:pathplanner/coderunner/fs/sync_queue.dart';
import 'package:pathplanner/services/log.dart';

/// In-memory working copy of the CodeRunner workspace's deploy tree.
/// Mutations to files under [syncedSubdir] are mirrored to the
/// deploy-files API through [queue]; everything else (the build.gradle
/// marker, read-only Choreo files) is memory-only.
class CodeRunnerFileSystem extends ForwardingFileSystem {
  static const String projectRoot = '/project';
  static const String syncedSubdir = 'src/main/deploy/pathplanner';

  final SyncQueue queue;

  CodeRunnerFileSystem(
      {required MemoryFileSystem memoryFs, required this.queue})
      : super(memoryFs);

  /// Fetches the snapshot and builds the hydrated file system.
  static Future<CodeRunnerFileSystem> hydrate(
      {required DeployFilesClient client, required SyncQueue queue}) async {
    final memoryFs = MemoryFileSystem();
    // The snapshot can be empty, so the root has to exist before anything
    // (including the build.gradle marker below) is written into it.
    memoryFs.directory(projectRoot).createSync(recursive: true);
    final files = await client.fetchSnapshot();
    for (final f in files) {
      final file = memoryFs.file(p.posix.join(projectRoot, f.path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(f.content);
    }
    // Marker so HomePage resolves the WPILib (Gradle) directory layout —
    // see the build.gradle check in lib/pages/home_page.dart.
    memoryFs
        .file(p.posix.join(projectRoot, 'build.gradle'))
        .writeAsStringSync('// CodeRunner workspace marker\n');
    memoryFs
        .directory(p.posix.join(projectRoot, syncedSubdir))
        .createSync(recursive: true);
    return CodeRunnerFileSystem(memoryFs: memoryFs, queue: queue);
  }

  @override
  File file(dynamic path) => _SyncedFile(super.file(path), this);

  /// API path (relative to the project root) for [absolutePath], or null
  /// when the file is outside the synced subtree.
  String? syncPathFor(String absolutePath) {
    final normalized = p.posix.normalize(absolutePath);
    if (!p.posix.isWithin(projectRoot, normalized)) {
      return null;
    }
    final rel = p.posix.relative(normalized, from: projectRoot);
    if (!p.posix.isWithin(syncedSubdir, rel)) {
      return null;
    }
    return rel;
  }

  void onFileWritten(String absolutePath, String content) {
    final rel = syncPathFor(absolutePath);
    if (rel != null) {
      queue.enqueuePut(rel, content);
    }
  }

  void onFileDeleted(String absolutePath) {
    final rel = syncPathFor(absolutePath);
    if (rel != null) {
      queue.enqueueDelete(rel);
    }
  }
}

/// File wrapper that reports mutations to the owning
/// [CodeRunnerFileSystem]. Read operations forward untouched. The
/// extends + with shape matches how package:file builds its own file
/// wrappers: ForwardingFileSystemEntity carries the concrete forwarding
/// of shared entity members, ForwardingFile the file-specific ones.
class _SyncedFile extends ForwardingFileSystemEntity<File, io.File>
    with ForwardingFile {
  @override
  final File delegate;

  final CodeRunnerFileSystem _syncedFs;

  _SyncedFile(this.delegate, this._syncedFs);

  @override
  FileSystem get fileSystem => _syncedFs;

  @override
  String get path => delegate.path;

  @override
  File wrapFile(io.File delegate) => _SyncedFile(delegate as File, _syncedFs);

  @override
  Directory wrapDirectory(io.Directory delegate) =>
      _syncedFs.directory((delegate as Directory).path);

  @override
  Link wrapLink(io.Link delegate) => delegate as Link;

  /// Mirrors the file's full current content. Reading back after the
  /// mutation makes append/byte writes and creates all take the same path.
  void _notifyWritten() {
    try {
      _syncedFs.onFileWritten(path, delegate.readAsStringSync());
    } catch (e) {
      Log.warning('CodeRunner sync skipped unreadable file $path', e);
    }
  }

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    final result = await delegate.create(recursive: recursive);
    _notifyWritten();
    return wrapFile(result);
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    delegate.createSync(recursive: recursive);
    _notifyWritten();
  }

  @override
  Future<File> writeAsString(String contents,
      {io.FileMode mode = io.FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) async {
    final result = await delegate.writeAsString(contents,
        mode: mode, encoding: encoding, flush: flush);
    _notifyWritten();
    return wrapFile(result);
  }

  @override
  void writeAsStringSync(String contents,
      {io.FileMode mode = io.FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {
    delegate.writeAsStringSync(contents,
        mode: mode, encoding: encoding, flush: flush);
    _notifyWritten();
  }

  @override
  Future<File> writeAsBytes(List<int> bytes,
      {io.FileMode mode = io.FileMode.write, bool flush = false}) async {
    final result = await delegate.writeAsBytes(bytes, mode: mode, flush: flush);
    _notifyWritten();
    return wrapFile(result);
  }

  @override
  void writeAsBytesSync(List<int> bytes,
      {io.FileMode mode = io.FileMode.write, bool flush = false}) {
    delegate.writeAsBytesSync(bytes, mode: mode, flush: flush);
    _notifyWritten();
  }

  @override
  Future<File> rename(String newPath) async {
    final oldPath = path;
    final renamed = await delegate.rename(newPath);
    _syncedFs.onFileWritten(renamed.path, renamed.readAsStringSync());
    _syncedFs.onFileDeleted(oldPath);
    return _SyncedFile(renamed, _syncedFs);
  }

  @override
  File renameSync(String newPath) {
    final oldPath = path;
    final renamed = delegate.renameSync(newPath);
    _syncedFs.onFileWritten(renamed.path, renamed.readAsStringSync());
    _syncedFs.onFileDeleted(oldPath);
    return _SyncedFile(renamed, _syncedFs);
  }

  @override
  Future<File> delete({bool recursive = false}) async {
    final oldPath = path;
    await delegate.delete(recursive: recursive);
    _syncedFs.onFileDeleted(oldPath);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) {
    delegate.deleteSync(recursive: recursive);
    _syncedFs.onFileDeleted(path);
  }
}
