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

    public static void savePath(){
        File pathFile = PathPlanner.chooseSaveFile();
        if(pathFile == null){
            return;
        }
        if(!pathFile.getName().endsWith(".path")){
            MainScene.showSnackbarMessage("Please save as a .path file!", "error");
            return;
        }
        Preferences.lastPathDir = pathFile.getParent();
        Preferences.currentPathName = pathFile.getName().substring(0, pathFile.getName().indexOf(".path"));

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
    }

    public static void loadPath(){
        File pathFile = PathPlanner.chooseLoadFile();
        if(pathFile == null){
            return;
        }
        if(!pathFile.getName().endsWith(".path")){
            MainScene.showSnackbarMessage("Please open a .path file!", "error");
            return;
        }
        Preferences.lastPathDir = pathFile.getParent();
        Preferences.currentPathName = pathFile.getName().substring(0, pathFile.getName().indexOf(".path"));

        MainScene.plannedPath.points.clear();
        try (BufferedReader in = new BufferedReader(new FileReader(pathFile))){
            String point;
            while ((point = in.readLine()) != null){
                String[] values = point.split(",");
                MainScene.plannedPath.points.add(new Vector2(Double.parseDouble(values[0]), Double.parseDouble(values[1])));
            }
        }catch (IOException e){
            e.printStackTrace();
        }
        MainScene.updateCanvas();
    }

    public static void saveGeneratedPath(String name, boolean reversed){
        File destination = PathPlanner.chooseOutputFolder();
        if(destination == null){
            return;
        }
        destination.mkdirs();
        Preferences.lastGenerateDir = destination.getAbsolutePath();
        saveRobotSettings();
        while(RobotPath.generatedPath == null){
            try {
                Thread.sleep(10);
            }catch (InterruptedException e){
                e.printStackTrace();
            }
        }

        File leftFile = new File(destination, name + "_left.csv");
        File rightFile = new File(destination, name + "_right.csv");

        try (PrintWriter out = new PrintWriter(leftFile)){
            if(reversed){
                out.print(RobotPath.generatedPath.right.formatCSV(true));
            }else{
                out.print(RobotPath.generatedPath.left.formatCSV(false));
            }
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }

        try (PrintWriter out = new PrintWriter(rightFile)){
            if(reversed){
                out.print(RobotPath.generatedPath.left.formatCSV(true));
            }else{
                out.print(RobotPath.generatedPath.right.formatCSV(false));
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
            out.println(Preferences.lastGenerateDir);
            out.print(Preferences.lastPathDir);
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
                Preferences.lastGenerateDir = in.readLine();
                Preferences.lastPathDir = in.readLine();
            }catch (IOException e){
                e.printStackTrace();
            }
        }
    }
}
