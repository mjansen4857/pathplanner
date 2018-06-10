package org.rangerrobotics.pathplanner.io;

import org.rangerrobotics.pathplanner.Preferences;
import java.io.*;

public class FileManager {
    private  static File robotSettingsDir = new File(System.getProperty("user.home") + "/.PathPlanner");

    public static void saveRobotSettings(){
        robotSettingsDir.getParentFile().mkdirs();
        File settingsFile = new File(robotSettingsDir, "robot.txt");
        settingsFile.getParentFile().mkdirs();
        try (PrintWriter out = new PrintWriter(settingsFile)){
            out.println(Preferences.maxVel);
            out.println(Preferences.maxAcc);
            out.println(Preferences.maxDcc);
            out.println(Preferences.wheelbaseWidth);
            out.println(Preferences.timeStep);
            out.println(Preferences.outputValue1);
            out.println(Preferences.outputValue2);
            out.println(Preferences.outputValue3);
            out.print(Preferences.outputFormat);
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
            }catch (IOException e){
                e.printStackTrace();
            }
        }
    }
}
