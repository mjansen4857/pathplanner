package com.pathplanner.lib.controllers;

import com.pathplanner.lib.path.PathPlannerTrajectory;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

public interface PathFollowingController {
  /**
   * Calculates the next output of the path following controller
   *
   * @param currentPose The current robot pose
   * @param targetState The desired trajectory state
   * @return The next robot relative output of the path following controller
   */
  ChassisSpeeds calculateRobotRelativeSpeeds(
      Pose2d currentPose, PathPlannerTrajectory.State targetState);

  /**
   * Resets the controller based on the current state of the robot
   *
   * @param currentPose Current robot pose
   * @param currentSpeeds Current robot relative chassis speeds
   */
  void reset(Pose2d currentPose, ChassisSpeeds currentSpeeds);

  double getPositionalError();
}
