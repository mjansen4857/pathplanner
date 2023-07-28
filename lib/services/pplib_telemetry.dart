import 'package:nt4/nt4.dart';

class PPLibTelemetry {
  late NT4Client _client;
  late NT4Subscription _velSub;
  late NT4Subscription _inaccuracySub;
  bool _isConnected = false;

  PPLibTelemetry({required String serverBaseAddress}) {
    _client = NT4Client(
      serverBaseAddress: serverBaseAddress,
      onConnect: () => _isConnected = true,
      onDisconnect: () => _isConnected = false,
    );

    _velSub = _client.subscribe('/PathPlanner/vel', 0.033);
    _inaccuracySub = _client.subscribe('/PathPlanner/inaccuracy', 0.033);
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

  Stream<bool> connectionStatusStream() {
    return _client.connectionStatusStream();
  }

  bool get isConnected => _isConnected;
}
