import 'package:nt4/nt4.dart';

class PPLibTelemetry {
  static late NT4Client _client;

  static void init() {
    _client = NT4Client(
      serverBaseAddress: 'localhost',
    );
  }

  static Stream<bool> connectionStatusStream() {
    return _client.connectionStatusStream();
  }
}
