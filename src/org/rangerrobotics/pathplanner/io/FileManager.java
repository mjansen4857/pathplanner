package org.rangerrobotics.pathplanner.io;

import javafx.collections.ObservableList;
import org.rangerrobotics.pathplanner.GeneralPreferences;
import org.rangerrobotics.pathplanner.PathPlanner;
import org.rangerrobotics.pathplanner.PathPreferences;
import org.rangerrobotics.pathplanner.generation.RobotPath;
import org.rangerrobotics.pathplanner.generation.Vector2;
import org.rangerrobotics.pathplanner.gui.MainScene;
import org.rangerrobotics.pathplanner.gui.PathEditor;

import java.io.*;

public class FileManager {
    //TODO: convert to JSON
    private static File robotSettingsDir = new File(System.getProperty("user.home") + "/.PathPlanner");

    public static void saveGeneralSettings(GeneralPreferences generalPreferences){
        robotSettingsDir.mkdirs();
        File settingsFile = new File(robotSettingsDir, "general.txt");
        try (PrintWriter out = new PrintWriter(settingsFile)){
            out.print(generalPreferences.tabIndex);
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
    }

    public static GeneralPreferences loadGeneralSettings(){
        if(robotSettingsDir.exists()){
            try (BufferedReader in = new BufferedReader(new FileReader(new File(robotSettingsDir, "general.txt")))){
                GeneralPreferences p = new GeneralPreferences();
                p.tabIndex = Integer.parseInt(in.readLine());
                return p;
            }catch (IOException e){
                e.printStackTrace();
            }
        }
        return new GeneralPreferences();
    }

    public static void savePath(PathEditor editor){
        File pathFile = PathPlanner.chooseSaveFile(editor.pathPreferences);
        if(pathFile == null){
            return;
        }
        if(!pathFile.getName().endsWith(".path")){
            MainScene.showSnackbarMessage("Please save as a .path file!", "error");
            return;
        }
        editor.pathPreferences.lastPathDir = pathFile.getParent();
        editor.pathPreferences.currentPathName = pathFile.getName().substring(0, pathFile.getName().indexOf(".path"));

        try (PrintWriter out = new PrintWriter(pathFile)) {
            ObservableList<Vector2> points = editor.plannedPath.points;
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

    public static void loadPath(PathEditor editor){
        File pathFile = PathPlanner.chooseLoadFile(editor.pathPreferences);
        if(pathFile == null){
            return;
        }
        if(!pathFile.getName().endsWith(".path")){
            MainScene.showSnackbarMessage("Please open a .path file!", "error");
            return;
        }
        editor.pathPreferences.lastPathDir = pathFile.getParent();
        editor.pathPreferences.currentPathName = pathFile.getName().substring(0, pathFile.getName().indexOf(".path"));

        editor.plannedPath.points.clear();
        try (BufferedReader in = new BufferedReader(new FileReader(pathFile))){
            String point;
            while ((point = in.readLine()) != null){
                String[] values = point.split(",");
                editor.plannedPath.points.add(new Vector2(Double.parseDouble(values[0]), Double.parseDouble(values[1])));
            }
        }catch (IOException e){
            e.printStackTrace();
        }
        editor.updatePathCanvas();
    }

    public static void saveGeneratedPath(String name, boolean reversed, PathEditor editor){
        File destination = PathPlanner.chooseOutputFolder(editor.pathPreferences);
        if(destination == null){
            return;
        }
        destination.mkdirs();
        editor.pathPreferences.lastGenerateDir = destination.getAbsolutePath();
        saveRobotSettings(editor);
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
                out.print(RobotPath.generatedPath.right.formatCSV(true, editor));
            }else{
                out.print(RobotPath.generatedPath.left.formatCSV(false, editor));
            }
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }

        try (PrintWriter out = new PrintWriter(rightFile)){
            if(reversed){
                out.print(RobotPath.generatedPath.left.formatCSV(true, editor));
            }else{
                out.print(RobotPath.generatedPath.right.formatCSV(false, editor));
            }
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
        MainScene.showSnackbarMessage("Files Saved To: " + destination.getAbsolutePath(), "success");
    }

    public static void saveRobotSettings(PathEditor editor){
        robotSettingsDir.mkdirs();
        File settingsFile = new File(robotSettingsDir, "robot" + editor.pathPreferences.year + ".txt");
        try (PrintWriter out = new PrintWriter(settingsFile)){
            out.println(editor.pathPreferences.year);
            out.println(editor.pathPreferences.maxVel);
            out.println(editor.pathPreferences.maxAcc);
            out.println(editor.pathPreferences.maxDcc);
            out.println(editor.pathPreferences.wheelbaseWidth);
            out.println(editor.pathPreferences.timeStep);
            out.println(editor.pathPreferences.outputValue1);
            out.println(editor.pathPreferences.outputValue2);
            out.println(editor.pathPreferences.outputValue3);
            out.println(editor.pathPreferences.outputFormat);
            out.println(editor.pathPreferences.lastGenerateDir);
            out.print(editor.pathPreferences.lastPathDir);
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
    }

    public static PathPreferences loadRobotSettings(String year){
        if(robotSettingsDir.exists()){
            try (BufferedReader in = new BufferedReader(new FileReader(new File(robotSettingsDir, "robot" + year + ".txt")))){
                PathPreferences p = new PathPreferences();
                in.readLine();
                p.year = year;
                p.maxVel = Double.parseDouble(in.readLine());
                p.maxAcc = Double.parseDouble(in.readLine());
                p.maxDcc = Double.parseDouble(in.readLine());
                p.wheelbaseWidth = Double.parseDouble(in.readLine());
                p.timeStep = Double.parseDouble(in.readLine());
                p.outputValue1 = in.readLine();
                p.outputValue2 = in.readLine();
                p.outputValue3 = in.readLine();
                p.outputFormat = in.readLine();
                p.lastGenerateDir = in.readLine();
                p.lastPathDir = in.readLine();
                return p;
            }catch (IOException e){
                e.printStackTrace();
            }
        }
        PathPreferences p = new PathPreferences();
        p.year = year;
        return p;
    }
}
