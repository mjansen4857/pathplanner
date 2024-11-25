from dataclasses import dataclass, field

from wpimath.geometry import Translation2d, Rotation2d, Pose2d
from wpimath.kinematics import ChassisSpeeds
from enum import Enum
import math
from typing import List

def translation2dFromJson(translationJson: dict) -> Translation2d:
    x = float(translationJson['x'])
    y = float(translationJson['y'])
    return Translation2d(x, y)


class FieldSymmetry(Enum):
    kRotational = 1
    kMirrored = 2


@dataclass(frozen=True)
class DriveFeedforwards:
    accelerationsMPS: List[float] = field(default_factory=list)
    forcesNewtons: List[float] = field(default_factory=list)
    torqueCurrentsAmps: List[float] = field(default_factory=list)
    robotRelativeForcesXNewtons: List[float] = field(default_factory=list)
    robotRelativeForcesYNewtons: List[float] = field(default_factory=list)

    @staticmethod
    def zeros(numModules: int) -> 'DriveFeedforwards':
        """
        Create drive feedforwards consisting of all zeros

        :param numModules: Number of drive modules
        :return: Zero feedforwards
        """
        return DriveFeedforwards(
            [0.0] * numModules,
            [0.0] * numModules,
            [0.0] * numModules,
            [0.0] * numModules,
            [0.0] * numModules
        )

    def interpolate(self, endVal: 'DriveFeedforwards', t: float) -> 'DriveFeedforwards':
        return DriveFeedforwards(
            DriveFeedforwards._interpolateList(self.accelerationsMPS, endVal.accelerationsMPS, t),
            DriveFeedforwards._interpolateList(self.forcesNewtons, endVal.forcesNewtons, t),
            DriveFeedforwards._interpolateList(self.torqueCurrentsAmps, endVal.torqueCurrentsAmps, t),
            DriveFeedforwards._interpolateList(self.robotRelativeForcesXNewtons, endVal.robotRelativeForcesXNewtons, t),
            DriveFeedforwards._interpolateList(self.robotRelativeForcesYNewtons, endVal.robotRelativeForcesYNewtons, t)
        )

    def reverse(self) -> 'DriveFeedforwards':
        """
        Reverse the feedforwards for driving backwards. This should only be used for differential drive robots.

        :return: Reversed feedforwards
        """
        if len(self.accelerationsMPS) != 2:
            raise RuntimeError('Feedforwards should only be reversed for differential drive trains')
        return DriveFeedforwards(
            [-self.accelerationsMPS[1], -self.accelerationsMPS[0]],
            [-self.forcesNewtons[1], -self.forcesNewtons[0]],
            [-self.torqueCurrentsAmps[1], -self.torqueCurrentsAmps[0]],
            [-self.robotRelativeForcesXNewtons[1], -self.robotRelativeForcesXNewtons[0]],
            [-self.robotRelativeForcesYNewtons[1], -self.robotRelativeForcesYNewtons[0]]
        )

    def flip(self) -> 'DriveFeedforwards':
        """
        Flip the feedforwards for the other side of the field. Only does anything if mirrored symmetry is used

        :return: Flipped feedforwards
        """
        return DriveFeedforwards(
            FlippingUtil.flipFeedforwards(self.accelerationsMPS),
            FlippingUtil.flipFeedforwards(self.forcesNewtons),
            FlippingUtil.flipFeedforwards(self.torqueCurrentsAmps),
            FlippingUtil.flipFeedforwardXs(self.robotRelativeForcesXNewtons),
            FlippingUtil.flipFeedforwardYs(self.robotRelativeForcesYNewtons)
        )

    @staticmethod
    def _interpolateList(a: List[float], b: List[float], t: float) -> List[float]:
        return [floatLerp(a[i], b[i], t) for i in range(len(a))]


class FlippingUtil:
    symmetryType: FieldSymmetry = FieldSymmetry.kMirrored
    fieldSizeX: float = 16.54175
    fieldSizeY: float = 8.211

    @staticmethod
    def flipFieldPosition(pos: Translation2d) -> Translation2d:
        """
        Flip a field position to the other side of the field, maintaining a blue alliance origin

        :param pos: The position to flip
        :return: The flipped position
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return Translation2d(FlippingUtil.fieldSizeX - pos.X(), pos.Y())
        else:
            return Translation2d(FlippingUtil.fieldSizeX - pos.X(), FlippingUtil.fieldSizeY - pos.Y())

    @staticmethod
    def flipFieldRotation(rotation: Rotation2d) -> Rotation2d:
        """
        Flip a field rotation to the other side of the field, maintaining a blue alliance origin

        :param rotation: The rotation to flip
        :return: The flipped rotation
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return Rotation2d(math.pi) - rotation
        else:
            return rotation - Rotation2d(math.pi)

    @staticmethod
    def flipFieldPose(pose: Pose2d) -> Pose2d:
        """
        Flip a field pose to the other side of the field, maintaining a blue alliance origin

        :param pose: The pose to flip
        :return: The flipped pose
        """
        return Pose2d(FlippingUtil.flipFieldPosition(pose.translation()),
                      FlippingUtil.flipFieldRotation(pose.rotation()))

    @staticmethod
    def flipFieldSpeeds(fieldSpeeds: ChassisSpeeds) -> ChassisSpeeds:
        """
        Flip field relative chassis speeds for the other side of the field, maintaining a blue alliance origin

        :param fieldSpeeds: Field relative chassis speeds
        :return: Flipped speeds
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return ChassisSpeeds(-fieldSpeeds.vx, fieldSpeeds.vy, -fieldSpeeds.omega)
        else:
            return ChassisSpeeds(-fieldSpeeds.vx, -fieldSpeeds.vy, fieldSpeeds.omega)

    @staticmethod
    def flipFeedforwards(feedforwards: List[float]) -> List[float]:
        """
        Flip a list of drive feedforwards for the other side of the field.
        Only does anything if mirrored symmetry is used

        :param feedforwards: List of drive feedforwards
        :return: The flipped feedforwards
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            if len(feedforwards) == 4:
                return [feedforwards[1], feedforwards[0], feedforwards[3], feedforwards[2]]
            elif len(feedforwards) == 2:
                return [feedforwards[1], feedforwards[0]]
        return feedforwards

    @staticmethod
    def flipFeedforwardXs(feedforwardXs: List[float]) -> List[float]:
        """
        Flip a list of drive feedforward X components for the other side of
        the field. Only does anything if mirrored symmetry is used

        :param feedforwardXs: List of drive feedforward X components
        :return: The flipped feedforward X components
        """
        return FlippingUtil.flipFeedforwards(feedforwardXs)

    @staticmethod
    def flipFeedforwardYs(feedforwardYs: List[float]) -> List[float]:
        """
        Flip a list of drive feedforward Y components for the other side of
        the field. Only does anything if mirrored symmetry is used

        :param feedforwardYs: List of drive feedforward Y components
        :return: The flipped feedforward Y components
        """
        flippedFeedforwardYs = FlippingUtil.flipFeedforwards(feedforwardYs)
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return [-feedforward for feedforward in flippedFeedforwardYs]
        return flippedFeedforwardYs


def floatLerp(start_val: float, end_val: float, t: float) -> float:
    """
    Interpolate between two floats

    :param start_val: Start value
    :param end_val: End value
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    return start_val + (end_val - start_val) * t


def translationLerp(a: Translation2d, b: Translation2d, t: float) -> Translation2d:
    """
    Linear interpolation between two Translation2ds

    :param a: Start value
    :param b: End value
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    return a + ((b - a) * t)


def rotationLerp(a: Rotation2d, b: Rotation2d, t: float) -> Rotation2d:
    """
    Interpolate between two Rotation2ds

    :param a: Start value
    :param b: End value
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    return a + ((b - a) * t)


def poseLerp(a: Pose2d, b: Pose2d, t: float) -> Pose2d:
    """
    Interpolate between two Pose2ds

    :param a: Start value
    :param b: End value
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    return a + ((b - a) * t)


def quadraticLerp(a: Translation2d, b: Translation2d, c: Translation2d, t: float) -> Translation2d:
    """
    Quadratic interpolation between Translation2ds

    :param a: Position 1
    :param b: Position 2
    :param c: Position 3
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    p0 = translationLerp(a, b, t)
    p1 = translationLerp(b, c, t)
    return translationLerp(p0, p1, t)


def cubicLerp(a: Translation2d, b: Translation2d, c: Translation2d, d: Translation2d, t: float) -> Translation2d:
    """
    Cubic interpolation between Translation2ds

    :param a: Position 1
    :param b: Position 2
    :param c: Position 3
    :param d: Position 4
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    p0 = quadraticLerp(a, b, c, t)
    p1 = quadraticLerp(b, c, d, t)
    return translationLerp(p0, p1, t)


def calculateRadius(a: Translation2d, b: Translation2d, c: Translation2d) -> float:
    """
    Calculate the curve radius given 3 points on the curve

    :param a: Point A
    :param b: Point B
    :param c: Point C
    :return: Curve radius
    """
    vba = a - b
    vbc = c - b
    cross_z = (vba.X() * vbc.X()) - (vba.X() * vbc.X())
    sign = 1 if cross_z < 0 else -1

    ab = a.distance(b)
    bc = b.distance(c)
    ac = a.distance(c)

    p = (ab + bc + ac) / 2
    area = math.sqrt(math.fabs(p * (p - ab) * (p - bc) * (p - ac)))
    if area == 0:
        return float('inf')
    return sign * (ab * bc * ac) / (4 * area)


def decimal_range(start: float, stop: float, increment: float):
    while start < stop and not math.isclose(start, stop):
        yield start
        start += increment

"""
  public SwerveSetpoint generateSetpoint(
      final SwerveSetpoint prevSetpoint, ChassisSpeeds desiredStateRobotRelative, double dt) {
    SwerveModuleState[] desiredModuleStates =
        config.toSwerveModuleStates(desiredStateRobotRelative);
    // Make sure desiredState respects velocity limits.
    SwerveDriveKinematics.desaturateWheelSpeeds(
        desiredModuleStates, config.moduleConfig.maxDriveVelocityMPS);
    desiredStateRobotRelative = config.toChassisSpeeds(desiredModuleStates);

    // Special case: desiredState is a complete stop. In this case, module angle is arbitrary, so
    // just use the previous angle.
    boolean need_to_steer = true;
    if (epsilonEquals(desiredStateRobotRelative, new ChassisSpeeds())) {
      need_to_steer = false;
      for (int m = 0; m < config.numModules; m++) {
        desiredModuleStates[m].angle = prevSetpoint.moduleStates()[m].angle;
        desiredModuleStates[m].speedMetersPerSecond = 0.0;
      }
    }

    // For each module, compute local Vx and Vy vectors.
    double[] prev_vx = new double[config.numModules];
    double[] prev_vy = new double[config.numModules];
    Rotation2d[] prev_heading = new Rotation2d[config.numModules];
    double[] desired_vx = new double[config.numModules];
    double[] desired_vy = new double[config.numModules];
    Rotation2d[] desired_heading = new Rotation2d[config.numModules];
    boolean all_modules_should_flip = true;
    for (int m = 0; m < config.numModules; m++) {
      prev_vx[m] =
          prevSetpoint.moduleStates()[m].angle.getCos()
              * prevSetpoint.moduleStates()[m].speedMetersPerSecond;
      prev_vy[m] =
          prevSetpoint.moduleStates()[m].angle.getSin()
              * prevSetpoint.moduleStates()[m].speedMetersPerSecond;
      prev_heading[m] = prevSetpoint.moduleStates()[m].angle;
      if (prevSetpoint.moduleStates()[m].speedMetersPerSecond < 0.0) {
        prev_heading[m] = prev_heading[m].rotateBy(Rotation2d.k180deg);
      }
      desired_vx[m] =
          desiredModuleStates[m].angle.getCos() * desiredModuleStates[m].speedMetersPerSecond;
      desired_vy[m] =
          desiredModuleStates[m].angle.getSin() * desiredModuleStates[m].speedMetersPerSecond;
      desired_heading[m] = desiredModuleStates[m].angle;
      if (desiredModuleStates[m].speedMetersPerSecond < 0.0) {
        desired_heading[m] = desired_heading[m].rotateBy(Rotation2d.k180deg);
      }
      if (all_modules_should_flip) {
        double required_rotation_rad =
            Math.abs(prev_heading[m].unaryMinus().rotateBy(desired_heading[m]).getRadians());
        if (required_rotation_rad < Math.PI / 2.0) {
          all_modules_should_flip = false;
        }
      }
    }
    if (all_modules_should_flip
        && !epsilonEquals(prevSetpoint.robotRelativeSpeeds(), new ChassisSpeeds())
        && !epsilonEquals(desiredStateRobotRelative, new ChassisSpeeds())) {
      // It will (likely) be faster to stop the robot, rotate the modules in place to the complement
      // of the desired angle, and accelerate again.
      return generateSetpoint(prevSetpoint, new ChassisSpeeds(), dt);
    }

    // Compute the deltas between start and goal. We can then interpolate from the start state to
    // the goal state; then find the amount we can move from start towards goal in this cycle such
    // that no kinematic limit is exceeded.
    double dx =
        desiredStateRobotRelative.vxMetersPerSecond
            - prevSetpoint.robotRelativeSpeeds().vxMetersPerSecond;
    double dy =
        desiredStateRobotRelative.vyMetersPerSecond
            - prevSetpoint.robotRelativeSpeeds().vyMetersPerSecond;
    double dtheta =
        desiredStateRobotRelative.omegaRadiansPerSecond
            - prevSetpoint.robotRelativeSpeeds().omegaRadiansPerSecond;

    // 's' interpolates between start and goal. At 0, we are at prevState and at 1, we are at
    // desiredState.
    double min_s = 1.0;

    // In cases where an individual module is stopped, we want to remember the right steering angle
    // to command (since inverse kinematics doesn't care about angle, we can be opportunistically
    // lazy).
    List<Optional<Rotation2d>> overrideSteering = new ArrayList<>(config.numModules);
    // Enforce steering velocity limits. We do this by taking the derivative of steering angle at
    // the current angle, and then backing out the maximum interpolant between start and goal
    // states. We remember the minimum across all modules, since that is the active constraint.
    for (int m = 0; m < config.numModules; m++) {
      if (!need_to_steer) {
        overrideSteering.add(Optional.of(prevSetpoint.moduleStates()[m].angle));
        continue;
      }
      overrideSteering.add(Optional.empty());

      double max_theta_step = dt * maxSteerVelocityRadsPerSec;

      if (epsilonEquals(prevSetpoint.moduleStates()[m].speedMetersPerSecond, 0.0)) {
        // If module is stopped, we know that we will need to move straight to the final steering
        // angle, so limit based purely on rotation in place.
        if (epsilonEquals(desiredModuleStates[m].speedMetersPerSecond, 0.0)) {
          // Goal angle doesn't matter. Just leave module at its current angle.
          overrideSteering.set(m, Optional.of(prevSetpoint.moduleStates()[m].angle));
          continue;
        }

        var necessaryRotation =
            prevSetpoint
                .moduleStates()[m]
                .angle
                .unaryMinus()
                .rotateBy(desiredModuleStates[m].angle);
        if (flipHeading(necessaryRotation)) {
          necessaryRotation = necessaryRotation.rotateBy(Rotation2d.kPi);
        }

        // getRadians() bounds to +/- Pi.
        final double numStepsNeeded = Math.abs(necessaryRotation.getRadians()) / max_theta_step;

        if (numStepsNeeded <= 1.0) {
          // Steer directly to goal angle.
          overrideSteering.set(m, Optional.of(desiredModuleStates[m].angle));
        } else {
          // Adjust steering by max_theta_step.
          overrideSteering.set(
              m,
              Optional.of(
                  prevSetpoint.moduleStates()[m].angle.rotateBy(
                      Rotation2d.fromRadians(
                          Math.signum(necessaryRotation.getRadians()) * max_theta_step))));
          min_s = 0.0;
        }
        continue;
      }
      if (min_s == 0.0) {
        // s can't get any lower. Save some CPU.
        continue;
      }

      // Enforce centripetal force limits to prevent sliding.
      // We do this by changing max_theta_step to the maximum change in heading over dt
      // that would create a large enough radius to keep the centripetal force under the
      // friction force.
      double maxHeadingChange =
          (dt * config.wheelFrictionForce)
              / ((config.massKG / config.numModules)
                  * Math.abs(prevSetpoint.moduleStates()[m].speedMetersPerSecond));
      max_theta_step = Math.min(max_theta_step, maxHeadingChange);

      double s =
          findSteeringMaxS(
              prev_vx[m],
              prev_vy[m],
              prev_heading[m].getRadians(),
              desired_vx[m],
              desired_vy[m],
              desired_heading[m].getRadians(),
              max_theta_step);
      min_s = Math.min(min_s, s);
    }

    // Enforce drive wheel torque limits
    Translation2d chassisForceVec = new Translation2d();
    double chassisTorque = 0.0;
    for (int m = 0; m < config.numModules; m++) {
      double lastVelRadPerSec =
          prevSetpoint.moduleStates()[m].speedMetersPerSecond
              / config.moduleConfig.wheelRadiusMeters;
      // Use the current battery voltage since we won't be able to supply 12v if the
      // battery is sagging down to 11v, which will affect the max torque output
      double currentDraw =
          config.moduleConfig.driveMotor.getCurrent(
              Math.abs(lastVelRadPerSec), RobotController.getInputVoltage());
      currentDraw = Math.min(currentDraw, config.moduleConfig.driveCurrentLimit);
      double moduleTorque = config.moduleConfig.driveMotor.getTorque(currentDraw);

      double prevSpeed = prevSetpoint.moduleStates()[m].speedMetersPerSecond;
      desiredModuleStates[m].optimize(prevSetpoint.moduleStates()[m].angle);
      double desiredSpeed = desiredModuleStates[m].speedMetersPerSecond;

      int forceSign;
      Rotation2d forceAngle = prevSetpoint.moduleStates()[m].angle;
      if (epsilonEquals(prevSpeed, 0.0)
          || (prevSpeed > 0 && desiredSpeed >= prevSpeed)
          || (prevSpeed < 0 && desiredSpeed <= prevSpeed)) {
        // Torque loss will be fighting motor
        moduleTorque -= config.moduleConfig.torqueLoss;
        forceSign = 1; // Force will be applied in direction of module
        if (prevSpeed < 0) {
          forceAngle = forceAngle.plus(Rotation2d.k180deg);
        }
      } else {
        // Torque loss will be helping the motor
        moduleTorque += config.moduleConfig.torqueLoss;
        forceSign = -1; // Force will be applied in opposite direction of module
        if (prevSpeed > 0) {
          forceAngle = forceAngle.plus(Rotation2d.k180deg);
        }
      }

      // Limit torque to prevent wheel slip
      moduleTorque = Math.min(moduleTorque, config.maxTorqueFriction);

      double forceAtCarpet = moduleTorque / config.moduleConfig.wheelRadiusMeters;
      Translation2d moduleForceVec = new Translation2d(forceAtCarpet * forceSign, forceAngle);

      // Add the module force vector to the chassis force vector
      chassisForceVec = chassisForceVec.plus(moduleForceVec);

      // Calculate the torque this module will apply to the chassis
      Rotation2d angleToModule = config.moduleLocations[m].getAngle();
      Rotation2d theta = moduleForceVec.getAngle().minus(angleToModule);
      chassisTorque += forceAtCarpet * config.modulePivotDistance[m] * theta.getSin();
    }

    Translation2d chassisAccelVec = chassisForceVec.div(config.massKG);
    double chassisAngularAccel = chassisTorque / config.MOI;

    // Use kinematics to convert chassis accelerations to module accelerations
    ChassisSpeeds chassisAccel =
        new ChassisSpeeds(chassisAccelVec.getX(), chassisAccelVec.getY(), chassisAngularAccel);
    var accelStates = config.toSwerveModuleStates(chassisAccel);

    for (int m = 0; m < config.numModules; m++) {
      if (min_s == 0.0) {
        // No need to carry on.
        break;
      }

      double maxVelStep = Math.abs(accelStates[m].speedMetersPerSecond * dt);

      double vx_min_s =
          min_s == 1.0 ? desired_vx[m] : (desired_vx[m] - prev_vx[m]) * min_s + prev_vx[m];
      double vy_min_s =
          min_s == 1.0 ? desired_vy[m] : (desired_vy[m] - prev_vy[m]) * min_s + prev_vy[m];
      // Find the max s for this drive wheel. Search on the interval between 0 and min_s, because we
      // already know we can't go faster than that.
      double s =
          findDriveMaxS(
              prev_vx[m],
              prev_vy[m],
              Math.hypot(prev_vx[m], prev_vy[m]),
              vx_min_s,
              vy_min_s,
              Math.hypot(vx_min_s, vy_min_s),
              maxVelStep);
      min_s = Math.min(min_s, s);
    }

    ChassisSpeeds retSpeeds =
        new ChassisSpeeds(
            prevSetpoint.robotRelativeSpeeds().vxMetersPerSecond + min_s * dx,
            prevSetpoint.robotRelativeSpeeds().vyMetersPerSecond + min_s * dy,
            prevSetpoint.robotRelativeSpeeds().omegaRadiansPerSecond + min_s * dtheta);
    retSpeeds = ChassisSpeeds.discretize(retSpeeds, dt);

    double prevVelX = prevSetpoint.robotRelativeSpeeds().vxMetersPerSecond;
    double prevVelY = prevSetpoint.robotRelativeSpeeds().vyMetersPerSecond;
    double chassisAccelX = (retSpeeds.vxMetersPerSecond - prevVelX) / dt;
    double chassisAccelY = (retSpeeds.vyMetersPerSecond - prevVelY) / dt;
    double chassisForceX = chassisAccelX * config.massKG;
    double chassisForceY = chassisAccelY * config.massKG;

    double angularAccel =
        (retSpeeds.omegaRadiansPerSecond - prevSetpoint.robotRelativeSpeeds().omegaRadiansPerSecond)
            / dt;
    double angTorque = angularAccel * config.MOI;
    ChassisSpeeds chassisForces = new ChassisSpeeds(chassisForceX, chassisForceY, angTorque);

    Translation2d[] wheelForces = config.chassisForcesToWheelForceVectors(chassisForces);

    var retStates = config.toSwerveModuleStates(retSpeeds);
    double[] accelFF = new double[config.numModules];
    double[] linearForceFF = new double[config.numModules];
    double[] torqueCurrentFF = new double[config.numModules];
    double[] forceXFF = new double[config.numModules];
    double[] forceYFF = new double[config.numModules];
    for (int m = 0; m < config.numModules; m++) {
      double wheelForceDist = wheelForces[m].getNorm();
      double appliedForce =
          wheelForceDist > 1e-6
              ? wheelForceDist * wheelForces[m].getAngle().minus(retStates[m].angle).getCos()
              : 0.0;
      double wheelTorque = appliedForce * config.moduleConfig.wheelRadiusMeters;
      double torqueCurrent = config.moduleConfig.driveMotor.getCurrent(wheelTorque);

      final var maybeOverride = overrideSteering.get(m);
      if (maybeOverride.isPresent()) {
        var override = maybeOverride.get();
        if (flipHeading(retStates[m].angle.unaryMinus().rotateBy(override))) {
          retStates[m].speedMetersPerSecond *= -1.0;
          appliedForce *= -1.0;
          torqueCurrent *= -1.0;
        }
        retStates[m].angle = override;
      }
      final var deltaRotation =
          prevSetpoint.moduleStates()[m].angle.unaryMinus().rotateBy(retStates[m].angle);
      if (flipHeading(deltaRotation)) {
        retStates[m].angle = retStates[m].angle.rotateBy(Rotation2d.k180deg);
        retStates[m].speedMetersPerSecond *= -1.0;
        appliedForce *= -1.0;
        torqueCurrent *= -1.0;
      }

      accelFF[m] =
          (retStates[m].speedMetersPerSecond - prevSetpoint.moduleStates()[m].speedMetersPerSecond)
              / dt;
      linearForceFF[m] = appliedForce;
      torqueCurrentFF[m] = torqueCurrent;
      forceXFF[m] = wheelForces[m].getX();
      forceYFF[m] = wheelForces[m].getY();
    }

    return new SwerveSetpoint(
        retSpeeds,
        retStates,
        new DriveFeedforwards(accelFF, linearForceFF, torqueCurrentFF, forceXFF, forceYFF));
  }

  /**
   * Check if it would be faster to go to the opposite of the goal heading (and reverse drive
   * direction).
   *
   * @param prevToGoal The rotation from the previous state to the goal state (i.e.
   *     prev.inverse().rotateBy(goal)).
   * @return True if the shortest path to achieve this rotation involves flipping the drive
   *     direction.
   */
  private static boolean flipHeading(Rotation2d prevToGoal) {
    return Math.abs(prevToGoal.getRadians()) > Math.PI / 2.0;
  }

  private static double unwrapAngle(double ref, double angle) {
    double diff = angle - ref;
    if (diff > Math.PI) {
      return angle - 2.0 * Math.PI;
    } else if (diff < -Math.PI) {
      return angle + 2.0 * Math.PI;
    } else {
      return angle;
    }
  }

  @FunctionalInterface
  private interface Function2d {
    double f(double x, double y);
  }

  /**
   * Find the root of the generic 2D parametric function 'func' using the regula falsi technique.
   * This is a pretty naive way to do root finding, but it's usually faster than simple bisection
   * while being robust in ways that e.g. the Newton-Raphson method isn't.
   *
   * @param func The Function2d to take the root of.
   * @param x_0 x value of the lower bracket.
   * @param y_0 y value of the lower bracket.
   * @param f_0 value of 'func' at x_0, y_0 (passed in by caller to save a call to 'func' during
   *     recursion)
   * @param x_1 x value of the upper bracket.
   * @param y_1 y value of the upper bracket.
   * @param f_1 value of 'func' at x_1, y_1 (passed in by caller to save a call to 'func' during
   *     recursion)
   * @param iterations_left Number of iterations of root finding left.
   * @return The parameter value 's' that interpolating between 0 and 1 that corresponds to the
   *     (approximate) root.
   */
  private static double findRoot(
      Function2d func,
      double x_0,
      double y_0,
      double f_0,
      double x_1,
      double y_1,
      double f_1,
      int iterations_left) {
    var s_guess = Math.max(0.0, Math.min(1.0, -f_0 / (f_1 - f_0)));

    if (iterations_left < 0 || epsilonEquals(f_0, f_1)) {
      return s_guess;
    }

    var x_guess = (x_1 - x_0) * s_guess + x_0;
    var y_guess = (y_1 - y_0) * s_guess + y_0;
    var f_guess = func.f(x_guess, y_guess);
    if (Math.signum(f_0) == Math.signum(f_guess)) {
      // 0 and guess on same side of root, so use upper bracket.
      return s_guess
          + (1.0 - s_guess)
              * findRoot(func, x_guess, y_guess, f_guess, x_1, y_1, f_1, iterations_left - 1);
    } else {
      // Use lower bracket.
      return s_guess
          * findRoot(func, x_0, y_0, f_0, x_guess, y_guess, f_guess, iterations_left - 1);
    }
  }

  private static double findSteeringMaxS(
      double x_0,
      double y_0,
      double f_0,
      double x_1,
      double y_1,
      double f_1,
      double max_deviation) {
    f_1 = unwrapAngle(f_0, f_1);
    double diff = f_1 - f_0;
    if (Math.abs(diff) <= max_deviation) {
      // Can go all the way to s=1.
      return 1.0;
    }
    double offset = f_0 + Math.signum(diff) * max_deviation;
    Function2d func = (x, y) -> unwrapAngle(f_0, Math.atan2(y, x)) - offset;
    return findRoot(func, x_0, y_0, f_0 - offset, x_1, y_1, f_1 - offset, MAX_STEER_ITERATIONS);
  }

  private static double findDriveMaxS(
      double x_0, double y_0, double f_0, double x_1, double y_1, double f_1, double max_vel_step) {
    double diff = f_1 - f_0;
    if (Math.abs(diff) <= max_vel_step) {
      // Can go all the way to s=1.
      return 1.0;
    }
    double offset = f_0 + Math.signum(diff) * max_vel_step;
    Function2d func = (x, y) -> Math.hypot(x, y) - offset;
    return findRoot(func, x_0, y_0, f_0 - offset, x_1, y_1, f_1 - offset, MAX_DRIVE_ITERATIONS);
  }

  private static boolean epsilonEquals(double a, double b, double epsilon) {
    return (a - epsilon <= b) && (a + epsilon >= b);
  }

  private static boolean epsilonEquals(double a, double b) {
    return epsilonEquals(a, b, kEpsilon);
  }

  private static boolean epsilonEquals(ChassisSpeeds s1, ChassisSpeeds s2) {
    return epsilonEquals(s1.vxMetersPerSecond, s2.vxMetersPerSecond)
        && epsilonEquals(s1.vyMetersPerSecond, s2.vyMetersPerSecond)
        && epsilonEquals(s1.omegaRadiansPerSecond, s2.omegaRadiansPerSecond);
  }
}
"""
