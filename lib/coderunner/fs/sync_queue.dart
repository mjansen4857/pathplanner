import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:pathplanner/coderunner/api/deploy_files_client.dart';
import 'package:pathplanner/services/log.dart';

enum SaveState { saved, saving, error }

sealed class _SyncOp {
  final String path;

  _SyncOp(this.path);
}

class _PutOp extends _SyncOp {
  String content;

  _PutOp(super.path, this.content);
}

class _DeleteOp extends _SyncOp {
  _DeleteOp(super.path);
}

/// Ordered, single-flight mirror of file mutations to the deploy-files
/// API. Rapid saves to the same path coalesce; failures retry forever
/// with [retryDelay] while [state] reports [SaveState.error].
class SyncQueue {
  final DeployFilesClient client;
  final Duration retryDelay;
  final ValueNotifier<SaveState> state = ValueNotifier(SaveState.saved);

  final Queue<_SyncOp> _queue = Queue();
  bool _draining = false;
  Completer<void>? _idleCompleter;

  SyncQueue(
      {required this.client, this.retryDelay = const Duration(seconds: 2)});

  void enqueuePut(String path, String content) {
    // Coalesce with a pending (not yet started) put for the same path.
    for (final op in _queue) {
      if (op is _PutOp && op.path == path) {
        op.content = content;
        return;
      }
    }
    _queue.add(_PutOp(path, content));
    _drain();
  }

  void enqueueDelete(String path) {
    // A pending put for a path that is now deleted is moot.
    _queue.removeWhere((op) => op is _PutOp && op.path == path);
    _queue.add(_DeleteOp(path));
    _drain();
  }

  /// Completes when the queue is empty and no op is in flight. For tests
  /// and for flushing before teardown.
  Future<void> get idle {
    if (!_draining && _queue.isEmpty) {
      return Future.value();
    }
    _idleCompleter ??= Completer<void>();
    return _idleCompleter!.future;
  }

  Future<void> _drain() async {
    if (_draining) {
      return;
    }
    _draining = true;
    state.value = SaveState.saving;

    // Defer one event-loop turn so a synchronous burst of enqueues
    // (e.g. rename = put + delete, or rapid saves) coalesces before the
    // first request fires.
    await Future<void>.delayed(Duration.zero);

    while (_queue.isNotEmpty) {
      final op = _queue.removeFirst();
      try {
        switch (op) {
          case _PutOp():
            await client.putFile(op.path, op.content);
          case _DeleteOp():
            await client.deleteFile(op.path);
        }
        if (state.value == SaveState.error) {
          state.value = SaveState.saving;
        }
      } catch (e) {
        Log.warning('CodeRunner sync failed for ${op.path}, retrying', e);
        state.value = SaveState.error;
        _queue.addFirst(op);
        await Future<void>.delayed(retryDelay);
      }
    }

    state.value = SaveState.saved;
    _draining = false;
    _idleCompleter?.complete();
    _idleCompleter = null;
  }
}
