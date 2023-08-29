package com.pathplanner.lib.util;

import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Collectors;

public class PathPlannerLogging {
  private static Consumer<Pose2d> logCurrentPose = null;
  private static Consumer<Pose2d> logTargetPose = null;
  private static Consumer<List<Pose2d>> logActivePath = null;

  public static void setLogCurrentPoseCallback(Consumer<Pose2d> logCurrentPose) {
    PathPlannerLogging.logCurrentPose = logCurrentPose;
  }

  public static void setLogTargetPoseCallback(Consumer<Pose2d> logTargetPose) {
    PathPlannerLogging.logTargetPose = logTargetPose;
  }

  public static void setLogActivePathCallback(Consumer<List<Pose2d>> logActivePath) {
    PathPlannerLogging.logActivePath = logActivePath;
  }

  public static void logCurrentPose(Pose2d pose) {
    if (logCurrentPose != null) {
      logCurrentPose.accept(pose);
    }
  }

  public static void logTargetPose(Pose2d targetPose) {
    if (logTargetPose != null) {
      logTargetPose.accept(targetPose);
    }
  }

  public static void logActivePath(PathPlannerPath path) {
    if (logActivePath != null) {
      List<Pose2d> poses =
          path.getAllPathPoints().stream()
              .map(p -> new Pose2d(p.position, new Rotation2d()))
              .collect(Collectors.toList());
      logActivePath.accept(poses);
    }
  }
}
