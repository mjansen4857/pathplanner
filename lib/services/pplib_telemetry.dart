import 'package:nt4/nt4.dart';

class PPLibTelemetry {
  static late NT4Client _client;
  static bool _isConnected = false;

  static void init() {
    _client = NT4Client(
      serverBaseAddress: 'localhost',
      onConnect: () => _isConnected = true,
      onDisconnect: () => _isConnected = false,
    );
  }

  static Stream<bool> connectionStatusStream() {
    return _client.connectionStatusStream();
  }

  static bool get isConnected => _isConnected;
}
