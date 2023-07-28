import 'package:nt4/nt4.dart';

class PPLibTelemetry {
  late NT4Client _client;
  late NT4Subscription _velSub;
  late NT4Subscription _inaccuracySub;
  late NT4Subscription _currentPoseSub;
  late NT4Subscription _currentPathSub;
  late NT4Subscription _lookaheadSub;
  bool _isConnected = false;

  PPLibTelemetry({required String serverBaseAddress}) {
    _client = NT4Client(
      serverBaseAddress: serverBaseAddress,
      onConnect: () => _isConnected = true,
      onDisconnect: () => _isConnected = false,
    );

    _velSub = _client.subscribe('/PathPlanner/vel', 0.033);
    _inaccuracySub = _client.subscribe('/PathPlanner/inaccuracy', 0.033);
    _currentPoseSub = _client.subscribe('/PathPlanner/currentPose', 0.033);
    _currentPathSub = _client.subscribe('/PathPlanner/currentPath', 0.1);
    _lookaheadSub = _client.subscribe('/PathPlanner/lookahead', 0.033);
  }

  Stream<List<num>> velocitiesStream() {
    return _velSub.stream().map((vels) =>
        (vels as List?)?.map((e) => e as num).toList() ?? [0, 0, 0, 0]);
  }

  Stream<num> inaccuracyStream() {
    return _inaccuracySub
        .stream()
        .map((inaccuracy) => (inaccuracy as num?) ?? 0);
  }

  Stream<List<num>?> currentPoseStream() {
    return _currentPoseSub
        .stream()
        .map((pose) => (pose as List?)?.map((e) => e as num).toList());
  }

  Stream<List<num>?> currentPathStream() {
    return _currentPathSub
        .stream()
        .map((path) => (path as List?)?.map((e) => e as num).toList());
  }

  Stream<bool> connectionStatusStream() {
    return _client.connectionStatusStream();
  }

  Stream<List<num>?> lookaheadStream() {
    return _lookaheadSub.stream().map(
        (lookahead) => (lookahead as List?)?.map((e) => e as num).toList());
  }

  bool get isConnected => _isConnected;
}
