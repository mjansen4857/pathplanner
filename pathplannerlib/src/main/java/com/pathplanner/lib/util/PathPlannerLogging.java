package com.pathplanner.lib.util;

import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Collectors;

public class PathPlannerLogging {
  private static Consumer<Pose2d> logCurrentPose = null;
  private static Consumer<Translation2d> logLookahead = null;
  private static Consumer<List<Pose2d>> logActivePath = null;

  public static void setLogCurrentPoseCallback(Consumer<Pose2d> logCurrentPose) {
    PathPlannerLogging.logCurrentPose = logCurrentPose;
  }

  public static void setLogLookaheadCallback(Consumer<Translation2d> logLookahead) {
    PathPlannerLogging.logLookahead = logLookahead;
  }

  public static void setLogActivePathCallback(Consumer<List<Pose2d>> logActivePath) {
    PathPlannerLogging.logActivePath = logActivePath;
  }

  public static void logCurrentPose(Pose2d pose) {
    if (logCurrentPose != null) {
      logCurrentPose.accept(pose);
    }
  }

  public static void logLookahead(Translation2d lookahead) {
    if (logLookahead != null) {
      logLookahead.accept(lookahead);
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
