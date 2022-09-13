import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class PPLibClient {
  static Socket? socket;
  static DateTime lastPong = DateTime.now();

  static Future<void> initialize(String host, int port) async {
    try {
      print('Attempting to connect to $host:$port');
      socket = await Socket.connect(host, port);
    } catch (e) {
      // Connection refused. Wait a few seconds and try again
      await Future.delayed(const Duration(seconds: 10));
      initialize(host, port);
      return;
    }
    lastPong = DateTime.now();

    print('Connected to server');

    socket!.listen(
      (Uint8List data) {
        String str = String.fromCharCodes(data);
        str = str.replaceAll('\r', '');
        str = str.replaceAll('\n', '');
        print('Received from server: $str');

        if (str == 'pong') {
          lastPong = DateTime.now();
        }
      },
      onError: (error) {
        print('Server connection error');
      },
      onDone: () {
        print('Connection ended');

        if (socket != null) {
          socket!.destroy();
          socket = null;
        }

        // Attempt to reconnect.
        initialize(host, port);
      },
    );

    // Send a 'ping' message to the server every 2 seconds so both ends
    // know the connection is still alive
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (socket == null) {
        timer.cancel();
        return;
      }

      if (DateTime.now().difference(lastPong).inSeconds > 10) {
        // Connection with server timed out
        print('Connection with server timed out');
        socket!.destroy();
        timer.cancel();
        return;
      }

      socket!.writeln('ping');
    });
  }
}
