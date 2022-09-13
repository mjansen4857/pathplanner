package com.pathplanner.lib.server;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.util.Objects;

public class PathPlannerServerThread extends Thread{
    private final Socket socket;
    private final BufferedReader reader;
    private final PrintWriter writer;
    protected volatile boolean isAlive = true;

    protected PathPlannerServerThread(Socket socket) throws IOException {
        this.socket = socket;
        this.socket.setSoTimeout(10000);
        this.reader = new BufferedReader(new InputStreamReader(socket.getInputStream()));
        this.writer = new PrintWriter(socket.getOutputStream(), true);
    }

    @Override
    public void run() {
        try{
            while(isAlive){
                String line = reader.readLine();

                if(line != null){
                    System.out.println("Server Received: " + line);
                    if(line.equals("ping")){
                        writer.println("pong");
                    }
                }else{
                    System.out.println("Client Disconnected");
                    isAlive = false;
                }
            }
        } catch (SocketTimeoutException e){
            // Connection with client timed out, don't bother printing a stack trace
            System.out.println("Connection with client timed out");
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            try {
                socket.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
            isAlive = false;
        }
    }
}
