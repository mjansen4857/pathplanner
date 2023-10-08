package com.pathplanner.lib.controllers;

import com.pathplanner.lib.path.PathPlannerTrajectory;
import edu.wpi.first.math.controller.RamseteController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

/** Ramsete path following controller */
public class PPRamseteController extends RamseteController implements PathFollowingController {
  private double lastError = 0;

  /**
   * Construct a Ramsete unicycle controller.
   *
   * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
   *     aggressive like a proportional term.
   * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
   *     more damping in response.
   */
  public PPRamseteController(double b, double zeta) {
    super(b, zeta);
  }

  /**
   * Construct a Ramsete unicycle controller. The default arguments for b and zeta of 2.0 rad^2/m^2
   * and 0.7 rad^-1 have been well-tested to produce desirable results.
   */
  public PPRamseteController() {
    super();
  }

  /**
   * Calculates the next output of the path following controller
   *
   * @param currentPose The current robot pose
   * @param targetState The desired trajectory state
   * @return The next robot relative output of the path following controller
   */
  @Override
  public ChassisSpeeds calculateRobotRelativeSpeeds(
      Pose2d currentPose, PathPlannerTrajectory.State targetState) {
    lastError = currentPose.getTranslation().getDistance(targetState.positionMeters);

    return calculate(
        currentPose,
        targetState.getDifferentialPose(),
        targetState.velocityMps,
        targetState.headingAngularVelocityRps);
  }

  /**
   * Resets the controller based on the current state of the robot
   *
   * @param currentPose Current robot pose
   * @param currentSpeeds Current robot relative chassis speeds
   */
  @Override
  public void reset(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    lastError = 0;
  }

  /**
   * Get the current positional error between the robot's actual and target positions
   *
   * @return Positional error, in meters
   */
  @Override
  public double getPositionalError() {
    return lastError;
  }

  /**
   * Is this controller for holonomic drivetrains? Used to handle some differences in functionality
   * in the path following command.
   *
   * @return True if this controller is for a holonomic drive train
   */
  @Override
  public boolean isHolonomic() {
    return false;
  }
}
