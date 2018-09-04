package org.rangerrobotics.pathplanner.io;

import javafx.collections.ObservableList;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.rangerrobotics.pathplanner.GeneralPreferences;
import org.rangerrobotics.pathplanner.PathPlanner;
import org.rangerrobotics.pathplanner.PathPreferences;
import org.rangerrobotics.pathplanner.generation.RobotPath;
import org.rangerrobotics.pathplanner.generation.Vector2;
import org.rangerrobotics.pathplanner.gui.MainScene;
import org.rangerrobotics.pathplanner.gui.PathEditor;

import java.io.*;

public class FileManager {
    private static File robotSettingsDir = new File(System.getProperty("user.home") + "/.PathPlanner");

    public static void saveGeneralSettings(GeneralPreferences generalPreferences){
        robotSettingsDir.mkdirs();
        File settingsFile = new File(robotSettingsDir, "general.txt");
        JSONObject jo = new JSONObject();
        jo.put("tabIndex", generalPreferences.tabIndex);
        try (PrintWriter out = new PrintWriter(settingsFile)){
            out.print(jo.toJSONString());
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
    }

    public static GeneralPreferences loadGeneralSettings(){
        if(robotSettingsDir.exists()){
            try (BufferedReader in = new BufferedReader(new FileReader(new File(robotSettingsDir, "general.txt")))){
                GeneralPreferences p = new GeneralPreferences();
                JSONObject jo = (JSONObject) new JSONParser().parse(in.readLine());
                //Java thinks that this number is a long, even though it is 1 digit. So, it must be cast to a long and then you can get the int value
                p.tabIndex = ((Long) jo.get("tabIndex")).intValue();
                return p;
            }catch (Exception e){
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
        File settingsFile = new File(robotSettingsDir, "robot" + editor.year + ".txt");
        PathPreferences p = editor.pathPreferences;
        JSONObject jo = new JSONObject();
        jo.put("maxVel", p.maxVel);
        jo.put("maxAcc", p.maxAcc);
        jo.put("maxDcc", p.maxDcc);
        jo.put("wheelbaseWidth", p.wheelbaseWidth);
        jo.put("robotLength", p.robotLength);
        jo.put("timeStep", p.timeStep);
        jo.put("outputValue1", p.outputValue1);
        jo.put("outputValue2", p.outputValue2);
        jo.put("outputValue3", p.outputValue3);
        jo.put("outputFormat", p.outputFormat);
        jo.put("lastGenerateDir", p.lastGenerateDir);
        jo.put("lastPathDir", p.lastPathDir);

        try (PrintWriter out = new PrintWriter(settingsFile)){
            out.print(jo.toJSONString());
        }catch (FileNotFoundException e){
            e.printStackTrace();
        }
    }

    public static PathPreferences loadRobotSettings(int year){
        if(robotSettingsDir.exists()){
            try (BufferedReader in = new BufferedReader(new FileReader(new File(robotSettingsDir, "robot" + year + ".txt")))){
                PathPreferences p = new PathPreferences();
                JSONObject jo = (JSONObject) new JSONParser().parse(in.readLine()) ;
                p.maxVel = (double) jo.get("maxVel");
                p.maxAcc = (double) jo.get("maxAcc");
                p.maxDcc = (double) jo.get("maxDcc");
                p.wheelbaseWidth = (double) jo.get("wheelbaseWidth");
                p.robotLength =  (double) jo.get("robotLength");
                p.timeStep = (double) jo.get("timeStep");
                p.outputValue1 = (String) jo.get("outputValue1");
                p.outputValue2 = (String) jo.get("outputValue2");
                p.outputValue3 = (String) jo.get("outputValue3");
                p.outputFormat = (String) jo.get("outputFormat");
                p.lastGenerateDir = (String) jo.get("lastGenerateDir");
                p.lastPathDir = (String) jo.get("lastPathDir");
                return p;
            }catch (Exception e){
                e.printStackTrace();
            }
        }
        PathPreferences p = new PathPreferences();
        return p;
    }
}
