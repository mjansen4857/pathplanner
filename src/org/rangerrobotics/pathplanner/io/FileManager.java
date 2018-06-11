package org.rangerrobotics.pathplanner.io;

import javafx.collections.ObservableList;
import org.rangerrobotics.pathplanner.PathPlanner;
import org.rangerrobotics.pathplanner.Preferences;
import org.rangerrobotics.pathplanner.generation.RobotPath;
import org.rangerrobotics.pathplanner.generation.Vector2;
import org.rangerrobotics.pathplanner.gui.MainScene;

import java.io.*;

public class FileManager {
    private static File robotSettingsDir = new File(System.getProperty("user.home") + "/.PathPlanner");

    public static void savePathFiles(String name, boolean reversed){
        File destination = PathPlanner.getDestination();
        if(destination == null){
            return;
        }
        Preferences.destinationPath = destination.getAbsolutePath();
        saveRobotSettings();
        File pathDir = new File(destination.getAbsolutePath() + "/paths");
        pathDir.mkdirs();
        while(RobotPath.generatedPath == null){
            try {
                Thread.sleep(10);
            }catch (InterruptedException e){
                e.printStackTrace();
            }
        }
        System.out.println("Saving files to: " + destination.getAbsolutePath());

        File pathFile = new File(pathDir, name + ".path");
        File leftFile = new File(destination, name + "_left.csv");
        File rightFile = new File(destination, name + "_right.csv");

        try (PrintWriter out = new PrintWriter(pathFile)) {
            ObservableList<Vector2> points = MainScene.plannedPath.points;
            for (int i = 0; i < points.size(); i++) {
                Vector2 point = points.get(i);
                if(i < points.size() - 1) {
                    out.println(point.getX() + "," + point.getY());
                }else{
                    out.print(point.getX() + "," + point.getY());
                }
            }
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }

        try (PrintWriter out = new PrintWriter(leftFile)){
            if(reversed){
                out.print(RobotPath.generatedPath.right.format(true));
            }else{
                out.print(RobotPath.generatedPath.left.format(false));
            }
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }

        try (PrintWriter out = new PrintWriter(rightFile)){
            if(reversed){
                out.print(RobotPath.generatedPath.left.format(true));
            }else{
                out.print(RobotPath.generatedPath.right.format(false));
            }
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
        MainScene.showSnackbarMessage("Files Saved To: " + destination.getAbsolutePath(), "success");
    }

    public static void saveRobotSettings(){
        robotSettingsDir.mkdirs();
        File settingsFile = new File(robotSettingsDir, "robot.txt");
        try (PrintWriter out = new PrintWriter(settingsFile)){
            out.println(Preferences.maxVel);
            out.println(Preferences.maxAcc);
            out.println(Preferences.maxDcc);
            out.println(Preferences.wheelbaseWidth);
            out.println(Preferences.timeStep);
            out.println(Preferences.outputValue1);
            out.println(Preferences.outputValue2);
            out.println(Preferences.outputValue3);
            out.println(Preferences.outputFormat);
            out.print(Preferences.destinationPath);
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
    }

    public static void loadRobotSettings(){
        if(robotSettingsDir.exists()){
            try (BufferedReader in = new BufferedReader(new FileReader(new File(robotSettingsDir, "robot.txt")))){
                Preferences.maxVel = Double.parseDouble(in.readLine());
                Preferences.maxAcc = Double.parseDouble(in.readLine());
                Preferences.maxDcc = Double.parseDouble(in.readLine());
                Preferences.wheelbaseWidth = Double.parseDouble(in.readLine());
                Preferences.timeStep = Double.parseDouble(in.readLine());
                Preferences.outputValue1 = in.readLine();
                Preferences.outputValue2 = in.readLine();
                Preferences.outputValue3 = in.readLine();
                Preferences.outputFormat = in.readLine();
                Preferences.destinationPath = in.readLine();
            }catch (IOException e){
                e.printStackTrace();
            }
        }
    }
}
