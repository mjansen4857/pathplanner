import 'package:nt4/nt4.dart';

class PPLibTelemetry {
  late NT4Client _client;
  bool _isConnected = false;

  PPLibTelemetry({required String serverBaseAddress}) {
    _client = NT4Client(
      serverBaseAddress: serverBaseAddress,
      onConnect: () => _isConnected = true,
      onDisconnect: () => _isConnected = false,
    );
  }

  Stream<bool> connectionStatusStream() {
    return _client.connectionStatusStream();
  }

  bool get isConnected => _isConnected;
}
