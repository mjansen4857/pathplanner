package com.pathplanner.lib.util;

import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPoint;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.networktables.DoubleArrayPublisher;
import edu.wpi.first.networktables.DoublePublisher;
import edu.wpi.first.networktables.NetworkTableInstance;

public class PPLibTelemetry {
  private static final DoubleArrayPublisher velPub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/vel").publish();
  private static final DoublePublisher inaccuracyPub =
      NetworkTableInstance.getDefault().getDoubleTopic("/PathPlanner/inaccuracy").publish();
  private static final DoubleArrayPublisher posePub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/currentPose").publish();
  private static final DoubleArrayPublisher pathPub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/currentPath").publish();
  private static final DoubleArrayPublisher lookaheadPub =
      NetworkTableInstance.getDefault().getDoubleArrayTopic("/PathPlanner/lookahead").publish();

  public static void setVelocities(
      double actualVel, double commandedVel, double actualAngVel, double commandedAngVel) {
    velPub.set(new double[] {actualVel, commandedVel, actualAngVel, commandedAngVel});
  }

  public static void setPathInaccuracy(double inaccuracy) {
    inaccuracyPub.set(inaccuracy);
  }

  public static void setCurrentPose(Pose2d pose) {
    posePub.set(new double[] {pose.getX(), pose.getY(), pose.getRotation().getDegrees()});
  }

  public static void setCurrentPath(PathPlannerPath path) {
    double[] arr = new double[path.numPoints() * 2];

    int ndx = 0;
    for (PathPoint p : path.getAllPathPoints()) {
      Translation2d pos = p.position;
      arr[ndx] = pos.getX();
      arr[ndx + 1] = pos.getY();
      ndx += 2;
    }

    pathPub.set(arr);
  }

  public static void setLookahead(Translation2d lookahead) {
    lookaheadPub.set(new double[] {lookahead.getX(), lookahead.getY()});
  }
}
