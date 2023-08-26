package com.pathplanner.lib.path;

import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import java.util.ArrayList;
import java.util.List;

public class PathPlannerTrajectory {
  private final List<State> states;

  /**
   * Generate a PathPlannerTrajectory
   *
   * @param path {@link com.pathplanner.lib.path.PathPlannerPath} to generate the trajectory for
   * @param startingSpeeds Starting speeds of the robot when starting the trajectory
   */
  public PathPlannerTrajectory(PathPlannerPath path, ChassisSpeeds startingSpeeds) {
    this.states = generateStates(path, startingSpeeds);
  }

  private static int getNextRotationTargetIdx(PathPlannerPath path, int startingIndex) {
    int idx = path.numPoints() - 1;

    for (int i = startingIndex; i < path.numPoints() - 2; i++) {
      if (path.getPoint(i).holonomicRotation != null) {
        idx = i;
        break;
      }
    }

    return idx;
  }

  private static List<State> generateStates(PathPlannerPath path, ChassisSpeeds startingSpeeds) {
    List<State> states = new ArrayList<>();

    double startVel =
        Math.hypot(startingSpeeds.vxMetersPerSecond, startingSpeeds.vyMetersPerSecond);

    int nextRotationTargetIdx = getNextRotationTargetIdx(path, 0);

    // Initial pass. Creates all states and handles linear acceleration
    for (int i = 0; i < path.numPoints(); i++) {
      State state = new State();

      PathConstraints constraints = path.getPoint(i).constraints;
      state.constraints = constraints;

      if (i > nextRotationTargetIdx) {
        nextRotationTargetIdx = getNextRotationTargetIdx(path, i);
      }

      state.targetHolonomicRotation = path.getPoint(nextRotationTargetIdx).holonomicRotation;

      state.positionMeters = path.getPoint(i).position;
      double curveRadius = path.getPoint(i).curveRadius;
      state.curvatureRadPerMeter =
          (Double.isFinite(curveRadius) && curveRadius != 0) ? 1.0 / curveRadius : 0.0;

      if (i == path.numPoints() - 1) {
        state.heading = states.get(states.size() - 1).heading;
        state.deltaPos =
            path.getPoint(i).distanceAlongPath - path.getPoint(i - 1).distanceAlongPath;
        state.velocityMps = path.getGoalEndState().getVelocity();
      } else if (i == 0) {
        state.heading = path.getPoint(i + 1).position.minus(state.positionMeters).getAngle();
        state.deltaPos = 0;
        state.velocityMps = startVel;
      } else {
        state.heading = path.getPoint(i + 1).position.minus(state.positionMeters).getAngle();
        state.deltaPos =
            path.getPoint(i + 1).distanceAlongPath - path.getPoint(i).distanceAlongPath;

        double v0 = states.get(states.size() - 1).velocityMps;
        double vMax =
            Math.sqrt(
                Math.abs(
                    Math.pow(v0, 2)
                        + (2 * constraints.getMaxAccelerationMpsSq() * state.deltaPos)));
        state.velocityMps = Math.min(vMax, path.getPoint(i).maxV);
      }

      states.add(state);
    }

    // Second pass. Handles linear deceleration
    for (int i = states.size() - 2; i > 1; i--) {
      PathConstraints constraints = path.getPoint(i).constraints;

      double v0 = states.get(i + 1).velocityMps;

      double vMax =
          Math.sqrt(
              Math.abs(
                  Math.pow(v0, 2)
                      + (2 * constraints.getMaxAccelerationMpsSq() * states.get(i + 1).deltaPos)));
      states.get(i).velocityMps = Math.min(vMax, states.get(i).velocityMps);
    }

    // Final pass. Calculates time, linear acceleration, and angular velocity
    double time = 0;
    states.get(0).timeSeconds = 0;
    states.get(0).accelerationMpsSq = 0;
    states.get(0).headingAngularVelocityRps = startingSpeeds.omegaRadiansPerSecond;

    for (int i = 1; i < states.size(); i++) {
      double v0 = states.get(i - 1).velocityMps;
      double v = states.get(i).velocityMps;
      double dt = (2 * states.get(i).deltaPos) / (v + v0);

      time += dt;
      states.get(i).timeSeconds = time;

      double dv = v - v0;
      states.get(i).accelerationMpsSq = dv / dt;

      Rotation2d headingDelta = states.get(i).heading.minus(states.get(i - 1).heading);
      states.get(i).headingAngularVelocityRps = headingDelta.getRadians() / dt;
    }

    return states;
  }

  /**
   * Get the target state at the given point in time along the trajectory
   *
   * @param time The time to sample the trajectory at in seconds
   * @return The target state
   */
  public State sample(double time) {
    if (time <= getInitialState().timeSeconds) return getInitialState();
    if (time >= getTotalTimeSeconds()) return getEndState();

    int low = 1;
    int high = getStates().size() - 1;

    while (low != high) {
      int mid = (low + high) / 2;
      if (getState(mid).timeSeconds < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    State sample = getState(low);
    State prevSample = getState(low - 1);

    if (Math.abs(sample.timeSeconds - prevSample.timeSeconds) < 1E-3) return sample;

    return prevSample.interpolate(
        sample, (time - prevSample.timeSeconds) / (sample.timeSeconds - prevSample.timeSeconds));
  }

  /**
   * Get all of the pre-generated states in the trajectory
   *
   * @return List of all states
   */
  public List<State> getStates() {
    return states;
  }

  /**
   * Get the total run time of the trajectory
   *
   * @return Total run time in seconds
   */
  public double getTotalTimeSeconds() {
    return getEndState().timeSeconds;
  }

  /**
   * Get the goal state at the given index
   *
   * @param index Index of the state to get
   * @return The state at the given index
   */
  public State getState(int index) {
    return getStates().get(index);
  }

  /**
   * Get the initial state of the trajectory
   *
   * @return The initial state
   */
  public State getInitialState() {
    return getState(0);
  }

  /**
   * Get the initial target pose for a holonomic drivetrain NOTE: This is a "target" pose, meaning
   * the rotation will be the value of the next rotation target along the path, not what the
   * rotation should be at the start of the path
   *
   * @return The initial target pose
   */
  public Pose2d getInitialTargetHolonomicPose() {
    return getInitialState().getTargetHolonomicPose();
  }

  /**
   * Get this initial pose for a differential drivetrain
   *
   * @return The initial pose
   */
  public Pose2d getInitialDifferentialPose() {
    return getInitialState().getDifferentialPose();
  }

  /**
   * Get the end state of the trajectory
   *
   * @return The end state
   */
  public State getEndState() {
    return getState(getStates().size() - 1);
  }

  public static class State {
    public double timeSeconds = 0;

    public double velocityMps = 0;
    public double accelerationMpsSq = 0;

    public double headingAngularVelocityRps = 0;

    public Translation2d positionMeters = new Translation2d();
    public Rotation2d heading = new Rotation2d();
    public Rotation2d targetHolonomicRotation = new Rotation2d();

    public double curvatureRadPerMeter = 0;

    public PathConstraints constraints;

    // Values only used during generation
    private double deltaPos = 0;

    private State interpolate(State endVal, double t) {
      State lerpedState = new State();

      lerpedState.timeSeconds = GeometryUtil.doubleLerp(timeSeconds, endVal.timeSeconds, t);
      double deltaT = lerpedState.timeSeconds - timeSeconds;

      if (deltaT < 0) {
        return endVal.interpolate(this, 1 - t);
      }

      lerpedState.velocityMps = GeometryUtil.doubleLerp(velocityMps, endVal.velocityMps, t);
      lerpedState.accelerationMpsSq =
          GeometryUtil.doubleLerp(accelerationMpsSq, endVal.accelerationMpsSq, t);
      lerpedState.positionMeters = positionMeters.interpolate(endVal.positionMeters, t);
      lerpedState.heading = heading.interpolate(endVal.heading, t);
      lerpedState.headingAngularVelocityRps =
          GeometryUtil.doubleLerp(headingAngularVelocityRps, endVal.headingAngularVelocityRps, t);
      lerpedState.curvatureRadPerMeter =
          GeometryUtil.doubleLerp(curvatureRadPerMeter, endVal.curvatureRadPerMeter, t);
      lerpedState.deltaPos = GeometryUtil.doubleLerp(deltaPos, endVal.deltaPos, t);

      if (t < 0.5) {
        lerpedState.constraints = constraints;
        lerpedState.targetHolonomicRotation = targetHolonomicRotation;
      } else {
        lerpedState.constraints = endVal.constraints;
        lerpedState.targetHolonomicRotation = endVal.targetHolonomicRotation;
      }

      return lerpedState;
    }

    /**
     * Get the target pose for a holonomic drivetrain NOTE: This is a "target" pose, meaning the
     * rotation will be the value of the next rotation target along the path, not what the rotation
     * should be at the start of the path
     *
     * @return The target pose
     */
    public Pose2d getTargetHolonomicPose() {
      return new Pose2d(positionMeters, targetHolonomicRotation);
    }

    /**
     * Get this pose for a differential drivetrain
     *
     * @return The pose
     */
    public Pose2d getDifferentialPose() {
      return new Pose2d(positionMeters, heading);
    }

    /**
     * Get the state reversed, used for following a trajectory reversed with a differential
     * drivetrain
     *
     * @return The reversed state
     */
    public State reverse() {
      State reversed = new State();

      reversed.timeSeconds = timeSeconds;
      reversed.velocityMps = -velocityMps;
      reversed.accelerationMpsSq = -accelerationMpsSq;
      reversed.headingAngularVelocityRps = headingAngularVelocityRps;
      reversed.heading = heading.unaryMinus();
      reversed.targetHolonomicRotation = targetHolonomicRotation;
      reversed.curvatureRadPerMeter = -curvatureRadPerMeter;
      reversed.deltaPos = deltaPos;
      reversed.constraints = constraints;

      return reversed;
    }
  }
}
