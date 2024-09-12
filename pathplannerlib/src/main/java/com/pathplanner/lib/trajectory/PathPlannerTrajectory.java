package com.pathplanner.lib.trajectory;

import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.path.EventMarker;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPoint;
import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.Pair;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.SwerveModuleState;
import edu.wpi.first.wpilibj2.command.Command;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Trajectory generated for a PathPlanner path */
public class PathPlannerTrajectory {
  private final List<PathPlannerTrajectoryState> states;
  private final List<Pair<Double, Command>> eventCommands;

  /**
   * Create a trajectory with pre-generated states and list of events
   *
   * @param states Pre-generated states
   * @param eventCommands Event commands
   */
  public PathPlannerTrajectory(
      List<PathPlannerTrajectoryState> states, List<Pair<Double, Command>> eventCommands) {
    this.states = states;
    this.eventCommands = eventCommands;
  }

  /**
   * Create a trajectory with pre-generated states
   *
   * @param states Pre-generated states
   */
  public PathPlannerTrajectory(List<PathPlannerTrajectoryState> states) {
    this(states, Collections.emptyList());
  }

  /**
   * Generate a new trajectory for a given path
   *
   * @param path The path to generate a trajectory for
   * @param startingSpeeds The starting robot-relative chassis speeds of the robot
   * @param startingRotation The starting field-relative rotation of the robot
   * @param config The {@link RobotConfig} describing the robot
   */
  public PathPlannerTrajectory(
      PathPlannerPath path,
      ChassisSpeeds startingSpeeds,
      Rotation2d startingRotation,
      RobotConfig config) {
    if (path.isChoreoPath()) {
      var traj = path.getIdealTrajectory(config).orElseThrow();
      this.states = traj.states;
      this.eventCommands = traj.eventCommands;
    } else {
      this.states = new ArrayList<>(path.numPoints());
      this.eventCommands = new ArrayList<>(path.getEventMarkers().size());

      // Create all states
      generateStates(states, path, startingRotation, config);

      // Set the initial module velocities
      ChassisSpeeds fieldStartingSpeeds =
          ChassisSpeeds.fromRobotRelativeSpeeds(startingSpeeds, states.get(0).pose.getRotation());
      var initialStates = config.kinematics.toSwerveModuleStates(fieldStartingSpeeds);
      for (int m = 0; m < config.numModules; m++) {
        states.get(0).moduleStates[m].speedMetersPerSecond = initialStates[m].speedMetersPerSecond;
      }
      states.get(0).timeSeconds = 0.0;
      states.get(0).fieldSpeeds = fieldStartingSpeeds;
      states.get(0).linearVelocity =
          Math.hypot(fieldStartingSpeeds.vxMetersPerSecond, fieldStartingSpeeds.vyMetersPerSecond);

      // Forward pass
      forwardAccelPass(states, config);

      // Set the final module velocities
      Translation2d endSpeedTrans =
          new Translation2d(
              path.getGoalEndState().getVelocity(), states.get(states.size() - 1).heading);
      ChassisSpeeds endFieldSpeeds =
          new ChassisSpeeds(endSpeedTrans.getX(), endSpeedTrans.getY(), 0.0);
      var endStates =
          config.kinematics.toSwerveModuleStates(
              ChassisSpeeds.fromFieldRelativeSpeeds(
                  endFieldSpeeds, states.get(states.size() - 1).pose.getRotation()));
      for (int m = 0; m < config.numModules; m++) {
        states.get(states.size() - 1).moduleStates[m].speedMetersPerSecond =
            endStates[m].speedMetersPerSecond;
      }
      states.get(states.size() - 1).fieldSpeeds = endFieldSpeeds;
      states.get(states.size() - 1).linearVelocity = path.getGoalEndState().getVelocity();

      // Reverse pass
      reverseAccelPass(states, config);

      List<EventMarker> unaddedMarkers = new ArrayList<>(path.getEventMarkers());

      // Loop back over and calculate time
      for (int i = 1; i < states.size(); i++) {
        double v0 = states.get(i - 1).linearVelocity;
        double v = states.get(i).linearVelocity;
        double dt = (2 * states.get(i).deltaPos) / (v + v0);
        states.get(i).timeSeconds = states.get(i - 1).timeSeconds + dt;

        if (!unaddedMarkers.isEmpty()) {
          double prevPos = states.get(i - 1).waypointRelativePos;
          double pos = states.get(i).waypointRelativePos;

          EventMarker next = unaddedMarkers.get(0);
          if (Math.abs(next.getWaypointRelativePos() - prevPos)
              <= Math.abs(next.getWaypointRelativePos() - pos)) {
            eventCommands.add(Pair.of(states.get(i - 1).timeSeconds, next.getCommand()));
            unaddedMarkers.remove(0);
          }
        }
      }
    }
  }

  private static void generateStates(
      List<PathPlannerTrajectoryState> states,
      PathPlannerPath path,
      Rotation2d startingRotation,
      RobotConfig config) {
    int prevRotationTargetIdx = 0;
    Rotation2d prevRotationTargetRot = startingRotation;
    int nextRotationTargetIdx = getNextRotationTargetIdx(path, 0);
    Rotation2d nextRotationTargetRot =
        path.getPoint(nextRotationTargetIdx).rotationTarget.getTarget();

    for (int i = 0; i < path.numPoints(); i++) {
      PathPoint p = path.getPoint(i);

      if (i > nextRotationTargetIdx) {
        prevRotationTargetIdx = nextRotationTargetIdx;
        prevRotationTargetRot = nextRotationTargetRot;
        nextRotationTargetIdx = getNextRotationTargetIdx(path, i);
        nextRotationTargetRot = path.getPoint(nextRotationTargetIdx).rotationTarget.getTarget();
      }

      // Holonomic rotation is interpolated. We use the distance along the path
      // to calculate how much to interpolate since the distribution of path points
      // is not the same along the whole segment
      double t =
          (path.getPoint(i).distanceAlongPath
                  - path.getPoint(prevRotationTargetIdx).distanceAlongPath)
              / (path.getPoint(nextRotationTargetIdx).distanceAlongPath
                  - path.getPoint(prevRotationTargetIdx).distanceAlongPath);
      Rotation2d holonomicRot = cosineInterpolate(prevRotationTargetRot, nextRotationTargetRot, t);

      Pose2d robotPose = new Pose2d(p.position, holonomicRot);
      var state = new PathPlannerTrajectoryState();
      state.pose = robotPose;
      state.constraints = path.getConstraintsForPoint(i);
      state.waypointRelativePos = p.waypointRelativePos;

      // Calculate robot heading
      if (i != path.numPoints() - 1) {
        state.heading = path.getPoint(i + 1).position.minus(state.pose.getTranslation()).getAngle();
      } else {
        state.heading = states.get(i - 1).heading;
      }

      if (!config.isHolonomic) {
        state.pose =
            new Pose2d(
                state.pose.getTranslation(),
                path.isReversed() ? (state.heading.plus(Rotation2d.k180deg)) : state.heading);
      }

      if (i != 0) {
        state.deltaPos =
            state.pose.getTranslation().getDistance(states.get(i - 1).pose.getTranslation());
        state.deltaRot = state.pose.getRotation().minus(states.get(i - 1).pose.getRotation());
      }

      state.moduleStates = new SwerveModuleTrajectoryState[config.numModules];
      for (int m = 0; m < config.numModules; m++) {
        state.moduleStates[m] = new SwerveModuleTrajectoryState();
        state.moduleStates[m].fieldPos =
            state
                .pose
                .getTranslation()
                .plus(config.moduleLocations[m].rotateBy(state.pose.getRotation()));

        if (i != 0) {
          state.moduleStates[m].deltaPos =
              state.moduleStates[m].fieldPos.getDistance(
                  states.get(i - 1).moduleStates[m].fieldPos);
        }
      }

      states.add(state);
    }

    // Calculate module headings
    for (int i = 0; i < states.size(); i++) {
      for (int m = 0; m < config.numModules; m++) {
        if (i != states.size() - 1) {
          states.get(i).moduleStates[m].fieldAngle =
              states
                  .get(i + 1)
                  .moduleStates[m]
                  .fieldPos
                  .minus(states.get(i).moduleStates[m].fieldPos)
                  .getAngle();
          states.get(i).moduleStates[m].angle =
              states.get(i).moduleStates[m].fieldAngle.minus(states.get(i).pose.getRotation());
        } else {
          states.get(i).moduleStates[m].fieldAngle = states.get(i - 1).moduleStates[m].fieldAngle;
          states.get(i).moduleStates[m].angle =
              states.get(i).moduleStates[m].fieldAngle.minus(states.get(i).pose.getRotation());
        }
      }
    }
  }

  private static void forwardAccelPass(
      List<PathPlannerTrajectoryState> states, RobotConfig config) {
    for (int i = 1; i < states.size() - 1; i++) {
      var prevState = states.get(i - 1);
      var state = states.get(i);
      var nextState = states.get(i + 1);

      // Calculate the linear force vector and torque acting on the whole robot
      Translation2d linearForceVec = new Translation2d();
      double totalTorque = 0.0;
      for (int m = 0; m < config.numModules; m++) {
        double lastVel = prevState.moduleStates[m].speedMetersPerSecond;
        // This pass will only be handling acceleration of the robot, meaning that the "torque"
        // acting on the module due to friction and other losses will be fighting the motor
        double availableTorque =
            config.moduleConfig.driveMotorTorqueCurve.get(lastVel / config.moduleConfig.rpmToMps)
                - config.moduleConfig.torqueLoss;
        double wheelTorque = availableTorque * config.moduleConfig.driveGearing;
        double forceAtCarpet = wheelTorque / config.moduleConfig.wheelRadiusMeters;
        if (!config.isHolonomic) {
          // Two motors per module if differential
          forceAtCarpet *= 2;
        }
        Translation2d forceVec = new Translation2d(forceAtCarpet, state.moduleStates[m].fieldAngle);

        // Add the module force vector to the robot force vector
        linearForceVec = linearForceVec.plus(forceVec);

        // Calculate the torque this module will apply to the robot
        Rotation2d angleToModule =
            state.moduleStates[m].fieldPos.minus(state.pose.getTranslation()).getAngle();
        Rotation2d theta = forceVec.getAngle().minus(angleToModule);
        totalTorque += forceAtCarpet * config.modulePivotDistance[m] * theta.getSin();
      }

      // Use the robot accelerations to calculate how each module should accelerate
      // Even though kinematics is usually used for velocities, it can still
      // convert chassis accelerations to module accelerations
      double maxAngAccel = state.constraints.getMaxAngularAccelerationRpsSq();
      double angularAccel = MathUtil.clamp(totalTorque / config.MOI, -maxAngAccel, maxAngAccel);

      Translation2d accelVec = linearForceVec.div(config.massKG);
      double maxAccel = state.constraints.getMaxAccelerationMpsSq();
      double accel = accelVec.getNorm();
      if (accel > maxAccel) {
        accelVec = accelVec.times(maxAccel / accel);
      }

      ChassisSpeeds chassisAccel =
          ChassisSpeeds.fromFieldRelativeSpeeds(
              accelVec.getX(), accelVec.getY(), angularAccel, state.pose.getRotation());
      var accelStates = config.kinematics.toSwerveModuleStates(chassisAccel);
      for (int m = 0; m < config.numModules; m++) {
        double moduleAcceleration = accelStates[m].speedMetersPerSecond;

        // Calculate the module velocity at the current state
        // vf^2 = v0^2 + 2ad
        state.moduleStates[m].speedMetersPerSecond =
            Math.sqrt(
                Math.abs(
                    Math.pow(prevState.moduleStates[m].speedMetersPerSecond, 2)
                        + (2 * moduleAcceleration * state.moduleStates[m].deltaPos)));

        double curveRadius =
            GeometryUtil.calculateRadius(
                prevState.moduleStates[m].fieldPos,
                state.moduleStates[m].fieldPos,
                nextState.moduleStates[m].fieldPos);
        // Find the max velocity that would keep the centripetal force under the friction force
        // Fc = M * v^2 / R
        if (Double.isFinite(curveRadius)) {
          double maxSafeVel =
              Math.sqrt((config.wheelFrictionForce * Math.abs(curveRadius)) / config.massKG);
          state.moduleStates[m].speedMetersPerSecond =
              Math.min(state.moduleStates[m].speedMetersPerSecond, maxSafeVel);
        }
      }

      // Go over the modules again to make sure they take the same amount of time to reach the next
      // state
      double maxDT = 0.0;
      for (int m = 0; m < config.numModules; m++) {
        Rotation2d prevRotDelta =
            state.moduleStates[m].angle.minus(prevState.moduleStates[m].angle);
        if (Math.abs(prevRotDelta.getDegrees()) >= 45) {
          continue;
        }

        double modVel = state.moduleStates[m].speedMetersPerSecond;
        double dt = nextState.moduleStates[m].deltaPos / modVel;

        if (Double.isFinite(dt)) {
          maxDT = Math.max(dt, maxDT);
        }
      }

      // Recalculate all module velocities with the allowed DT
      for (int m = 0; m < config.numModules; m++) {
        Rotation2d prevRotDelta =
            state.moduleStates[m].angle.minus(prevState.moduleStates[m].angle);
        if (Math.abs(prevRotDelta.getDegrees()) >= 45) {
          continue;
        }

        state.moduleStates[m].speedMetersPerSecond = nextState.moduleStates[m].deltaPos / maxDT;
      }

      // Use the calculated module velocities to calculate the robot speeds
      ChassisSpeeds desiredSpeeds = config.kinematics.toChassisSpeeds(state.moduleStates);

      double maxChassisVel = state.constraints.getMaxVelocityMps();
      double maxChassisAngVel = state.constraints.getMaxAngularVelocityRps();

      desaturateWheelSpeeds(
          state.moduleStates,
          desiredSpeeds,
          config.moduleConfig.maxDriveVelocityMPS,
          maxChassisVel,
          maxChassisAngVel);

      state.fieldSpeeds =
          ChassisSpeeds.fromRobotRelativeSpeeds(
              config.kinematics.toChassisSpeeds(state.moduleStates), state.pose.getRotation());
      state.linearVelocity =
          Math.hypot(state.fieldSpeeds.vxMetersPerSecond, state.fieldSpeeds.vyMetersPerSecond);
    }
  }

  private static void reverseAccelPass(
      List<PathPlannerTrajectoryState> states, RobotConfig config) {
    for (int i = states.size() - 2; i > 0; i--) {
      var state = states.get(i);
      var nextState = states.get(i + 1);

      // Calculate the linear force vector and torque acting on the whole robot
      Translation2d linearForceVec = new Translation2d();
      double totalTorque = 0.0;
      for (int m = 0; m < config.numModules; m++) {
        double lastVel = nextState.moduleStates[m].speedMetersPerSecond;
        // This pass will only be handling deceleration of the robot, meaning that the "torque"
        // acting on the module due to friction and other losses will not be fighting the motor
        double availableTorque =
            config.moduleConfig.driveMotorTorqueCurve.get(lastVel / config.moduleConfig.rpmToMps);
        double wheelTorque = availableTorque * config.moduleConfig.driveGearing;
        double forceAtCarpet = wheelTorque / config.moduleConfig.wheelRadiusMeters;
        if (!config.isHolonomic) {
          // Two motors per module if differential
          forceAtCarpet *= 2;
        }
        Translation2d forceVec =
            new Translation2d(
                forceAtCarpet, state.moduleStates[m].fieldAngle.plus(Rotation2d.k180deg));

        // Add the module force vector to the robot force vector
        linearForceVec = linearForceVec.plus(forceVec);

        // Calculate the torque this module will apply to the robot
        Rotation2d angleToModule =
            state.moduleStates[m].fieldPos.minus(state.pose.getTranslation()).getAngle();
        Rotation2d theta = forceVec.getAngle().minus(angleToModule);
        totalTorque += forceAtCarpet * config.modulePivotDistance[m] * theta.getSin();
      }

      // Use the robot accelerations to calculate how each module should accelerate
      // Even though kinematics is usually used for velocities, it can still
      // convert chassis accelerations to module accelerations
      double maxAngAccel = state.constraints.getMaxAngularAccelerationRpsSq();
      double angularAccel = MathUtil.clamp(totalTorque / config.MOI, -maxAngAccel, maxAngAccel);

      Translation2d accelVec = linearForceVec.div(config.massKG);
      double maxAccel = state.constraints.getMaxAccelerationMpsSq();
      double accel = accelVec.getNorm();
      if (accel > maxAccel) {
        accelVec = accelVec.times(maxAccel / accel);
      }

      ChassisSpeeds chassisAccel =
          ChassisSpeeds.fromFieldRelativeSpeeds(
              new ChassisSpeeds(accelVec.getX(), accelVec.getY(), angularAccel),
              state.pose.getRotation());
      var accelStates = config.kinematics.toSwerveModuleStates(chassisAccel);
      for (int m = 0; m < config.numModules; m++) {
        double moduleAcceleration = accelStates[m].speedMetersPerSecond;

        // Calculate the module velocity at the current state
        // vf^2 = v0^2 + 2ad
        double maxVel =
            Math.sqrt(
                Math.abs(
                    Math.pow(nextState.moduleStates[m].speedMetersPerSecond, 2)
                        + (2 * moduleAcceleration * nextState.moduleStates[m].deltaPos)));
        state.moduleStates[m].speedMetersPerSecond =
            Math.min(maxVel, state.moduleStates[m].speedMetersPerSecond);
      }

      // Go over the modules again to make sure they take the same amount of time to reach the next
      // state
      double maxDT = 0.0;
      for (int m = 0; m < config.numModules; m++) {
        Rotation2d prevRotDelta =
            state.moduleStates[m].angle.minus(states.get(i - 1).moduleStates[m].angle);
        if (Math.abs(prevRotDelta.getDegrees()) >= 45) {
          continue;
        }

        double modVel = state.moduleStates[m].speedMetersPerSecond;
        double dt = nextState.moduleStates[m].deltaPos / modVel;

        if (Double.isFinite(dt)) {
          maxDT = Math.max(dt, maxDT);
        }
      }

      // Recalculate all module velocities with the allowed DT
      for (int m = 0; m < config.numModules; m++) {
        Rotation2d prevRotDelta =
            state.moduleStates[m].angle.minus(states.get(i - 1).moduleStates[m].angle);
        if (Math.abs(prevRotDelta.getDegrees()) >= 45) {
          continue;
        }

        state.moduleStates[m].speedMetersPerSecond = nextState.moduleStates[m].deltaPos / maxDT;
      }

      // Use the calculated module velocities to calculate the robot speeds
      ChassisSpeeds desiredSpeeds = config.kinematics.toChassisSpeeds(state.moduleStates);

      double maxChassisVel = state.constraints.getMaxVelocityMps();
      double maxChassisAngVel = state.constraints.getMaxAngularVelocityRps();

      maxChassisVel = Math.min(maxChassisVel, state.linearVelocity);
      maxChassisAngVel =
          Math.min(maxChassisAngVel, Math.abs(state.fieldSpeeds.omegaRadiansPerSecond));

      desaturateWheelSpeeds(
          state.moduleStates,
          desiredSpeeds,
          config.moduleConfig.maxDriveVelocityMPS,
          maxChassisVel,
          maxChassisAngVel);

      state.fieldSpeeds =
          ChassisSpeeds.fromRobotRelativeSpeeds(
              config.kinematics.toChassisSpeeds(state.moduleStates), state.pose.getRotation());
      state.linearVelocity =
          Math.hypot(state.fieldSpeeds.vxMetersPerSecond, state.fieldSpeeds.vyMetersPerSecond);
    }
  }

  /**
   * Get all of the pairs of timestamps + commands to run at those timestamps
   *
   * @return Pairs of timestamps and event commands
   */
  public List<Pair<Double, Command>> getEventCommands() {
    return eventCommands;
  }

  /**
   * Get all of the pre-generated states in the trajectory
   *
   * @return List of all states
   */
  public List<PathPlannerTrajectoryState> getStates() {
    return states;
  }

  /**
   * Get the goal state at the given index
   *
   * @param index Index of the state to get
   * @return The state at the given index
   */
  public PathPlannerTrajectoryState getState(int index) {
    return states.get(index);
  }

  /**
   * Get the initial state of the trajectory
   *
   * @return The initial state
   */
  public PathPlannerTrajectoryState getInitialState() {
    return states.get(0);
  }

  /**
   * Get the end state of the trajectory
   *
   * @return The end state
   */
  public PathPlannerTrajectoryState getEndState() {
    return states.get(states.size() - 1);
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
   * Get the initial robot pose at the start of the trajectory
   *
   * @return Pose of the robot at the initial state
   */
  public Pose2d getInitialPose() {
    return getInitialState().pose;
  }

  /**
   * Get the target state at the given point in time along the trajectory
   *
   * @param time The time to sample the trajectory at in seconds
   * @return The target state
   */
  public PathPlannerTrajectoryState sample(double time) {
    if (time <= getInitialState().timeSeconds) return getInitialState();
    if (time >= getTotalTimeSeconds()) return getEndState();

    int low = 1;
    int high = states.size() - 1;

    while (low != high) {
      int mid = (low + high) / 2;
      if (getState(mid).timeSeconds < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    var sample = getState(low);
    var prevSample = getState(low - 1);

    if (Math.abs(sample.timeSeconds - prevSample.timeSeconds) < 1E-3) {
      return sample;
    }

    return prevSample.interpolate(
        sample, (time - prevSample.timeSeconds) / (sample.timeSeconds - prevSample.timeSeconds));
  }

  private static void desaturateWheelSpeeds(
      SwerveModuleState[] moduleStates,
      ChassisSpeeds desiredSpeeds,
      double maxModuleSpeedMPS,
      double maxTranslationSpeed,
      double maxRotationSpeed) {
    double realMaxSpeed = 0.0;
    for (SwerveModuleState s : moduleStates) {
      realMaxSpeed = Math.max(realMaxSpeed, Math.abs(s.speedMetersPerSecond));
    }

    if (realMaxSpeed == 0) {
      return;
    }

    double translationPct = 0.0;
    if (Math.abs(maxTranslationSpeed) > 1e-8) {
      translationPct =
          Math.sqrt(
                  Math.pow(desiredSpeeds.vxMetersPerSecond, 2)
                      + Math.pow(desiredSpeeds.vyMetersPerSecond, 2))
              / maxTranslationSpeed;
    }

    double rotationPct = 0.0;
    if (Math.abs(maxRotationSpeed) > 1e-8) {
      rotationPct = Math.abs(desiredSpeeds.omegaRadiansPerSecond) / Math.abs(maxRotationSpeed);
    }

    double maxPct = Math.max(translationPct, rotationPct);

    double scale = Math.min(1.0, maxModuleSpeedMPS / realMaxSpeed);
    if (maxPct > 0) {
      scale = Math.min(scale, 1.0 / maxPct);
    }

    for (SwerveModuleState s : moduleStates) {
      s.speedMetersPerSecond *= scale;
    }
  }

  private static int getNextRotationTargetIdx(PathPlannerPath path, int startingIndex) {
    for (int i = startingIndex; i < path.numPoints() - 1; i++) {
      if (path.getPoint(i).rotationTarget != null) {
        return i;
      }
    }

    return path.numPoints() - 1;
  }

  private static Rotation2d cosineInterpolate(Rotation2d start, Rotation2d end, double t) {
    double t2 = (1.0 - Math.cos(t * Math.PI)) / 2.0;
    return start.interpolate(end, t2);
  }
}
