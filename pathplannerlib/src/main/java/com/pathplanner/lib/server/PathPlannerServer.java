package com.pathplanner.lib.server;

import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.trajectory.Trajectory;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

public class PathPlannerServer {
  private static volatile boolean isRunning = false;
  private static List<PathPlannerServerThread> clients =
      Collections.synchronizedList(new ArrayList<>());

  public static void startServer(int serverPort) {
    if (!isRunning) {
      new Thread(
              () -> {
                try (ServerSocket serverSocket = new ServerSocket(serverPort)) {
                  isRunning = true;

                  while (true) {
                    Socket socket = serverSocket.accept();
                    synchronized (clients) {
                      clients.add(
                          new PathPlannerServerThread(socket, PathPlannerServer::handleMessage));
                      clients.get(clients.size() - 1).start();
                    }
                  }
                } catch (IOException e) {
                  e.printStackTrace();
                }
              })
          .start();
    }
  }

  private static void sendToClients(String message) {
    synchronized (clients) {
      // This try/catch block is here just in case I missed any multithreading shenanigans
      // So, instead of crashing it will just not send the message
      try {
        clients.removeIf(client -> !client.isAlive);

        for (PathPlannerServerThread client : clients) {
          client.sendMessage(message);
        }
      } catch (Exception e) {
        // do nothing
      }
    }
  }

  private static synchronized void handleMessage(String message) {
    // Non ping-pong messages are sent in json format
    try {
      JSONObject json = (JSONObject) new JSONParser().parse(message);

      String command = (String) json.get("command");

      switch (command) {
        case "updatePath":
          String pathName = (String) json.get("pathName");
          String fileContent = (String) json.get("fileContent");

          File pathFile =
              new File(Filesystem.getDeployDirectory(), "pathplanner/" + pathName + ".path");

          try (BufferedWriter writer = new BufferedWriter(new FileWriter(pathFile))) {
            writer.write(fileContent);
            writer.flush();
          } catch (IOException e) {
            e.printStackTrace();
          }
          break;
        default:
          // Unknown command
          break;
      }
    } catch (ParseException e) {
      // Invalid json. Ignore this message
    }
  }

  public static void sendActivePath(List<Trajectory.State> states) {
    JSONObject json = new JSONObject();

    json.put("command", "activePath");

    JSONArray statesJson = new JSONArray();
    // Send only 1 in 10 states to prevent buffer overflow on longer paths
    for (int i = 0; i < states.size() - 1; i += 10) {
      JSONArray stateArr = new JSONArray();
      stateArr.add(Math.round(states.get(i).poseMeters.getTranslation().getX() * 100.0) / 100.0);
      stateArr.add(Math.round(states.get(i).poseMeters.getTranslation().getY() * 100.0) / 100.0);
      statesJson.add(stateArr);
    }

    JSONArray lastStateArr = new JSONArray();
    lastStateArr.add(
        Math.round(states.get(states.size() - 1).poseMeters.getTranslation().getX() * 100.0)
            / 100.0);
    lastStateArr.add(
        Math.round(states.get(states.size() - 1).poseMeters.getTranslation().getY() * 100.0)
            / 100.0);
    statesJson.add(lastStateArr);

    json.put("states", statesJson);

    sendToClients(json.toJSONString());
  }

  public static void sendPathFollowingData(Pose2d targetPose, Pose2d actualPose) {
    JSONObject json = new JSONObject();

    json.put("command", "pathFollowingData");

    JSONObject targetPoseJson = new JSONObject();
    targetPoseJson.put("x", targetPose.getX());
    targetPoseJson.put("y", targetPose.getY());
    targetPoseJson.put("theta", targetPose.getRotation().getRadians());
    json.put("targetPose", targetPoseJson);

    JSONObject actualPoseJson = new JSONObject();
    actualPoseJson.put("x", actualPose.getX());
    actualPoseJson.put("y", actualPose.getY());
    actualPoseJson.put("theta", actualPose.getRotation().getRadians());
    json.put("actualPose", actualPoseJson);

    sendToClients(json.toJSONString());
  }
}
