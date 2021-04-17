package com.pathplanner.lib;

import edu.wpi.first.wpilibj.geometry.Rotation2d;
import edu.wpi.first.wpilibj.geometry.Translation2d;

import java.util.ArrayList;

public class PathPlanner {
    protected static double resolution = 0.004;

    public static Path loadPath(String name){
        ArrayList<Path.Point> pathPoints = new ArrayList<>();
        pathPoints.add(new Path.AnchorPoint(new Translation2d(0, 0), -1, new Rotation2d()));
        pathPoints.add(new Path.Point(new Translation2d(1, 0)));
        pathPoints.add(new Path.Point(new Translation2d(4, 1)));
        pathPoints.add(new Path.AnchorPoint(new Translation2d(5, 1), -1, new Rotation2d()));

        return new Path(pathPoints, 4, 5, false);
    }
}