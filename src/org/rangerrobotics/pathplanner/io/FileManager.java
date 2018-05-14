package org.rangerrobotics.pathplanner.io;

import org.rangerrobotics.pathplanner.generation.RobotPath;

import java.io.*;

public class FileManager {
    private  static File robotSettingsDir = new File(System.getProperty("user.home") + "/.PathPlanner");

    public static void saveRobotSettings(){
        robotSettingsDir.getParentFile().mkdirs();
        try (PrintWriter out = new PrintWriter(new File(robotSettingsDir, "robot.txt"))){
            out.println(RobotPath.maxVel);
            out.println(RobotPath.maxAcc);
            out.println(RobotPath.maxDcc);
            out.println(RobotPath.wheelbaseWidth);
            out.print(RobotPath.timeStep);
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
    }

    public static void loadRobotSettings(){
        if(robotSettingsDir.exists()){
            try (BufferedReader in = new BufferedReader(new FileReader(new File(robotSettingsDir, "robot.txt")))){
                RobotPath.maxVel = Double.parseDouble(in.readLine());
                RobotPath.maxAcc = Double.parseDouble(in.readLine());
                RobotPath.maxDcc = Double.parseDouble(in.readLine());
                RobotPath.wheelbaseWidth = Double.parseDouble(in.readLine());
                RobotPath.timeStep = Double.parseDouble(in.readLine());
            }catch (IOException e){
                e.printStackTrace();
            }
        }
    }
}
