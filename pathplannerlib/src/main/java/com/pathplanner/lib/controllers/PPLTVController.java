package com.pathplanner.lib.controllers;

import com.pathplanner.lib.path.PathPlannerTrajectory;
import edu.wpi.first.math.Vector;
import edu.wpi.first.math.controller.LTVUnicycleController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.numbers.N2;
import edu.wpi.first.math.numbers.N3;

/** LTV following controller */
public class PPLTVController extends LTVUnicycleController implements PathFollowingController {
  private double lastError = 0;

  /**
   * Constructs a linear time-varying unicycle controller with default maximum desired error
   * tolerances of (0.0625 m, 0.125 m, 2 rad) and default maximum desired control effort of (1 m/s,
   * 2 rad/s).
   *
   * @param dt Discretization timestep in seconds.
   */
  public PPLTVController(double dt) {
    super(dt);
  }

  /**
   * Constructs a linear time-varying unicycle controller with default maximum desired error
   * tolerances of (0.0625 m, 0.125 m, 2 rad) and default maximum desired control effort of (1 m/s,
   * 2 rad/s).
   *
   * @param dt Discretization timestep in seconds.
   * @param maxVelocity The maximum velocity in meters per second for the controller gain lookup
   *     table. The default is 9 m/s.
   * @throws IllegalArgumentException if maxVelocity &lt;= 0.
   */
  public PPLTVController(double dt, double maxVelocity) {
    super(dt, maxVelocity);
  }

  /**
   * Constructs a linear time-varying unicycle controller.
   *
   * <p>See
   * https://docs.wpilib.org/en/stable/docs/software/advanced-controls/state-space/state-space-intro.html#lqr-tuning
   * for how to select the tolerances.
   *
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Discretization timestep in seconds.
   */
  public PPLTVController(Vector<N3> qelems, Vector<N2> relems, double dt) {
    super(qelems, relems, dt);
  }

  /**
   * Constructs a linear time-varying unicycle controller.
   *
   * <p>See
   * https://docs.wpilib.org/en/stable/docs/software/advanced-controls/state-space/state-space-intro.html#lqr-tuning
   * for how to select the tolerances.
   *
   * @param qelems The maximum desired error tolerance for each state.
   * @param relems The maximum desired control effort for each input.
   * @param dt Discretization timestep in seconds.
   * @param maxVelocity The maximum velocity in meters per second for the controller gain lookup
   *     table. The default is 9 m/s.
   * @throws IllegalArgumentException if maxVelocity &lt;= 0 m/s or &gt;= 15 m/s.
   */
  public PPLTVController(Vector<N3> qelems, Vector<N2> relems, double dt, double maxVelocity) {
    super(qelems, relems, dt, maxVelocity);
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
