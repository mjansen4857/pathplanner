package com.pathplanner.lib;

import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.wpilibj.geometry.Rotation2d;
import edu.wpi.first.wpilibj.geometry.Translation2d;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

import java.io.*;
import java.util.ArrayList;

public class PathPlanner {
    protected static double resolution = 0.004;

    public static Path loadPath(String name, double maxVel, double maxAccel, boolean reversed) {
        try(BufferedReader br = new BufferedReader(new FileReader(new File(Filesystem.getDeployDirectory(), "pathplanner/" + name + ".path")))){
            StringBuilder fileContentBuilder = new StringBuilder();
            String line;
            while((line = br.readLine()) != null){
                fileContentBuilder.append(line);
            }

            String fileContent = fileContentBuilder.toString();

            JSONObject json = (JSONObject) new JSONParser().parse(fileContent);
            JSONArray jsonWaypoints = (JSONArray) json.get("waypoints");

            ArrayList<Path.Waypoint> waypoints = new ArrayList<>();

            for (Object waypoint : jsonWaypoints) {
                JSONObject jsonWaypoint = (JSONObject) waypoint;

                JSONObject jsonAnchor = (JSONObject) jsonWaypoint.get("anchorPoint");
                Translation2d anchorPoint = new Translation2d((double) jsonAnchor.get("x"), (double) jsonAnchor.get("y"));

                JSONObject jsonPrevControl = (JSONObject) jsonWaypoint.get("prevControl");
                Translation2d prevControl = null;
                if (jsonPrevControl != null) {
                    prevControl = new Translation2d((double) jsonPrevControl.get("x"), (double) jsonPrevControl.get("y"));
                }

                JSONObject jsonNextControl = (JSONObject) jsonWaypoint.get("nextControl");
                Translation2d nextControl = null;
                if (jsonPrevControl != null) {
                    nextControl = new Translation2d((double) jsonNextControl.get("x"), (double) jsonNextControl.get("y"));
                }

                Rotation2d holonomicAngle = Rotation2d.fromDegrees((double) jsonWaypoint.get("holonomicAngle"));
                boolean isReversal = (boolean) jsonWaypoint.get("isReversal");
                double velOverride = -1;
                if (jsonWaypoint.get("velOverride") != null) {
                    velOverride = (double) jsonWaypoint.get("velOverride");
                }

                waypoints.add(new Path.Waypoint(anchorPoint, prevControl, nextControl, velOverride, holonomicAngle, isReversal));
            }

            ArrayList<ArrayList<Path.Waypoint>> splitPaths = new ArrayList<>();
            ArrayList<Path.Waypoint> currentPath = new ArrayList<>();

            for(Path.Waypoint w : waypoints){
                currentPath.add(w);

                if(w.isReversal){
                    splitPaths.add(currentPath);
                    currentPath = new ArrayList<>();
                    currentPath.add(w);
                }
            }

            ArrayList<Path> paths = new ArrayList<>();
            for(int i = 0; i < splitPaths.size(); i++){
                boolean reversePath = (i % 2 == 0) == reversed;
                paths.add(new Path(splitPaths.get(i), maxVel, maxAccel, reversePath));
            }

            return Path.joinPaths(paths);
        }catch (Exception e){
            e.printStackTrace();
            return null;
        }
    }

    public static Path loadPath(String name, double maxVel, double maxAccel){
        return loadPath(name, maxVel, maxAccel, false);
    }
}