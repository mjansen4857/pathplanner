package com.pathplanner.lib.server;

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;

public class PathPlannerServer {
    private static volatile boolean isRunning = false;
    private static volatile ArrayList<PathPlannerServerThread> clients = new ArrayList<>();

    public static void startServer(int serverPort){
        if(!isRunning){
            new Thread(() -> {
                try (ServerSocket serverSocket = new ServerSocket(serverPort)){
                    isRunning = true;

                    while(true){
                        Socket socket = serverSocket.accept();
                        clients.add(new PathPlannerServerThread(socket, PathPlannerServer::handleMessage));
                        clients.get(clients.size() - 1).start();
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }).start();
        }
    }

    private static void sendToClients(String message){
        for(PathPlannerServerThread client : clients) {
            if(!client.isAlive){
                clients.remove(client);
            }else{
                client.sendMessage(message);
            }
        }
    }

    private static void handleMessage(String message){
        // Non ping-pong messages are sent in json format
        try {
            JSONObject json = (JSONObject) new JSONParser().parse(message);
        } catch (ParseException e) {
            // Invalid json. Ignore this message
        }
    }
}
