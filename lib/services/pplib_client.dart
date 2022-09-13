import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PPLibClient {
  static Socket? socket;
  static bool enabled = false;
  static DateTime lastPong = DateTime.now();

  static Stream<bool> connectionStatusStream() async* {
    bool connected = socket != null;
    yield connected;

    while (true) {
      bool isConnected = socket != null;
      if (connected != isConnected) {
        connected = isConnected;
        yield connected;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  static Future<void> initialize(SharedPreferences prefs) async {
    String host = prefs.getString('pplibClientHost') ?? '10.30.15.2';
    int port = prefs.getInt('pplibClientPort') ?? 5810;
    enabled = true;

    try {
      socket = await Socket.connect(host, port);
    } catch (e) {
      // Connection refused. Wait a few seconds and try again
      await Future.delayed(const Duration(seconds: 10));
      if (enabled) initialize(prefs);
      return;
    }
    lastPong = DateTime.now();

    socket!.listen(
      (Uint8List data) {
        String str = String.fromCharCodes(data).trim();
        List<String> messages = str.split('\n');

        // Dart sockets can group multiple messages together
        for (String message in messages) {
          String msg = message.trim();

          if (msg == 'pong') {
            lastPong = DateTime.now();
          } else {
            // Commands are sent in JSON format
            Map<String, dynamic> json = jsonDecode(msg);

            String command = json['command'];
            switch (command) {
              case 'activePath':
                {
                  print('Active path: ${json['states']}');
                }
                break;
              case 'pathFollowingData':
                {
                  // print('Path following data:');
                  // print('Target: ${json['targetPose']}');
                  // print('Actual: ${json['actualtPose']}');
                }
                break;
              default:
                {
                  // Unknown command
                }
                break;
            }
          }
        }
      },
      onError: (error) {
        print('Server connection error');
      },
      onDone: () {
        if (socket != null) {
          socket!.destroy();
          socket = null;
        }

        // Attempt to reconnect.
        if (enabled) initialize(prefs);
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
        socket!.destroy();
        timer.cancel();
        return;
      }

      socket!.writeln('ping');
    });
  }

  static void stopServer() {
    if (enabled) {
      enabled = false;
      if (socket != null) {
        socket!.destroy();
      }
    }
  }
}
