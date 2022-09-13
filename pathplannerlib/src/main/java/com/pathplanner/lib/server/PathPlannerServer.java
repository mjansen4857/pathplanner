package com.pathplanner.lib.server;

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
                        clients.add(new PathPlannerServerThread(socket));
                        clients.get(clients.size() - 1).start();
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }).start();
        }
    }
}
