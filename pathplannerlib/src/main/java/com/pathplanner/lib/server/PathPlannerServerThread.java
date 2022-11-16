package com.pathplanner.lib.server;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.util.function.Consumer;

public class PathPlannerServerThread extends Thread {
  private final Socket socket;
  private final BufferedReader reader;
  private final PrintWriter writer;
  private final Consumer<String> onMessageReceived;
  protected volatile boolean isAlive = true;

  protected PathPlannerServerThread(Socket socket, Consumer<String> onMessageReceived)
      throws IOException {
    this.socket = socket;
    this.socket.setSoTimeout(10000);
    this.reader = new BufferedReader(new InputStreamReader(socket.getInputStream()));
    this.writer = new PrintWriter(socket.getOutputStream(), true);
    this.onMessageReceived = onMessageReceived;
  }

  @Override
  public void run() {
    try {
      while (isAlive) {
        String line = reader.readLine();

        if (line != null) {
          if (line.equals("ping")) {
            writer.println("pong");
          } else {
            onMessageReceived.accept(line);
          }
        } else {
          // Client disconnected
          isAlive = false;
        }
      }
    } catch (Exception e) {
      // Connection ended
    } finally {
      try {
        socket.close();
      } catch (IOException e) {
        e.printStackTrace();
      }
      isAlive = false;
    }
  }

  protected void sendMessage(String message) {
    writer.println(message);
  }
}
