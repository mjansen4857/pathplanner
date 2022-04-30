package com.pathplanner.lib;

import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.trajectory.Trajectory;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

import java.io.*;
import java.util.ArrayList;

public class PathPlanner {
    protected static double resolution = 0.004;

    /**
     * Load a path file from storage
     * @param name The name of the path to load
     * @param maxVel Max velocity of the path
     * @param maxAccel Max velocity of the path
     * @param reversed Should the robot follow the path reversed
     * @return The generated path
     */
    public static PathPlannerTrajectory loadPath(String name, double maxVel, double maxAccel, boolean reversed) {
        try(BufferedReader br = new BufferedReader(new FileReader(new File(Filesystem.getDeployDirectory(), "pathplanner/" + name + ".path")))){
            StringBuilder fileContentBuilder = new StringBuilder();
            String line;
            while((line = br.readLine()) != null){
                fileContentBuilder.append(line);
            }

            String fileContent = fileContentBuilder.toString();

            JSONObject json = (JSONObject) new JSONParser().parse(fileContent);
            JSONArray jsonWaypoints = (JSONArray) json.get("waypoints");

            ArrayList<PathPlannerTrajectory.Waypoint> waypoints = new ArrayList<>();

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
                if (jsonNextControl != null) {
                    nextControl = new Translation2d((double) jsonNextControl.get("x"), (double) jsonNextControl.get("y"));
                }

                Rotation2d holonomicAngle = Rotation2d.fromDegrees((double) jsonWaypoint.get("holonomicAngle"));
                boolean isReversal = (boolean) jsonWaypoint.get("isReversal");
                double velOverride = -1;
                if (jsonWaypoint.get("velOverride") != null) {
                    velOverride = (double) jsonWaypoint.get("velOverride");
                }

                waypoints.add(new PathPlannerTrajectory.Waypoint(anchorPoint, prevControl, nextControl, velOverride, holonomicAngle, isReversal));
            }

            ArrayList<ArrayList<PathPlannerTrajectory.Waypoint>> splitPaths = new ArrayList<>();
            ArrayList<PathPlannerTrajectory.Waypoint> currentPath = new ArrayList<>();

            for(int i = 0; i < waypoints.size(); i++){
                PathPlannerTrajectory.Waypoint w = waypoints.get(i);

                currentPath.add(w);

                if(w.isReversal || i == waypoints.size() - 1){
                    splitPaths.add(currentPath);
                    currentPath = new ArrayList<>();
                    currentPath.add(w);
                }
            }

            ArrayList<PathPlannerTrajectory> paths = new ArrayList<>();
            boolean shouldReverse = reversed;
            for(int i = 0; i < splitPaths.size(); i++){
                paths.add(new PathPlannerTrajectory(splitPaths.get(i), maxVel, maxAccel, shouldReverse));
                shouldReverse = !shouldReverse;
            }

            return joinPaths(paths);
        }catch (Exception e){
            e.printStackTrace();
            return null;
        }
    }

    /**
     * Load a path from storage
     * @param name The name of the path to load
     * @param maxVel Max velocity of the path
     * @param maxAccel Max velocity of the path
     * @return The generated path
     */
    public static PathPlannerTrajectory loadPath(String name, double maxVel, double maxAccel){
        return loadPath(name, maxVel, maxAccel, false);
    }

    private static PathPlannerTrajectory joinPaths(ArrayList<PathPlannerTrajectory> paths){
        ArrayList<Trajectory.State> joinedStates = new ArrayList<>();

        for(int i = 0; i < paths.size(); i++){
            if (i != 0){
                double lastEndTime = joinedStates.get(joinedStates.size() - 1).timeSeconds;

                for(Trajectory.State s : paths.get(i).getStates()){
                    s.timeSeconds += lastEndTime;
                }
            }

            joinedStates.addAll(paths.get(i).getStates());
        }

        return new PathPlannerTrajectory(joinedStates);
    }
}