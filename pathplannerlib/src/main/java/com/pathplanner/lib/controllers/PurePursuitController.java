package com.pathplanner.lib.controllers;

import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPoint;
import com.pathplanner.lib.util.ChassisSpeedsRateLimiter;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import java.util.List;

/** A controller that uses the Pure Pursuit algorithm to follow a path. */
public class PurePursuitController {
  private static final double MIN_LOOKAHEAD_DISTANCE = 0.5;

  private PathPlannerPath path;

  private final ChassisSpeedsRateLimiter speedsLimiter;
  private final PIDController rotationController;
  private final boolean holonomic;

  private Translation2d lastLookahead = new Translation2d();
  private double lastDistToEnd = Double.POSITIVE_INFINITY;
  private Rotation2d targetHeading = new Rotation2d();
  private ChassisSpeeds lastCommanded;
  private PathPoint nextRotationTarget;
  private double lastInaccuracy = 0;
  private boolean lockDecel;

  /**
   * Constructs a new PurePursuitController.
   *
   * @param path the path to follow
   * @param holonomic whether the robot is holonomic or not
   */
  public PurePursuitController(PathPlannerPath path, boolean holonomic) {
    this.path = path;
    this.speedsLimiter =
        new ChassisSpeedsRateLimiter(
            path.getGlobalConstraints().getMaxAccelerationMpsSq(),
            path.getGlobalConstraints().getMaxAngularAccelerationRpsSq());
    this.rotationController = new PIDController(4.0, 0.0, 0.0);
    this.rotationController.enableContinuousInput(-Math.PI, Math.PI);
    this.lastCommanded = new ChassisSpeeds();
    this.lockDecel = false;
    this.holonomic = holonomic;
    if (this.holonomic) {
      this.nextRotationTarget = findNextRotationTarget(0);
    }
  }

  /**
   * Resets the controller with the given current speeds.
   *
   * @param currentSpeeds the current speeds of the robot
   */
  public void reset(ChassisSpeeds currentSpeeds) {
    this.speedsLimiter.reset(currentSpeeds);
    this.rotationController.reset();
    this.lastLookahead = null;
    this.lastDistToEnd = Double.POSITIVE_INFINITY;
    this.lastCommanded = currentSpeeds;
    if (holonomic) {
      this.nextRotationTarget = findNextRotationTarget(0);
    }
    this.lockDecel = false;
  }

  private PathPoint findNextRotationTarget(int startIndex) {
    for (int i = startIndex; i < path.numPoints() - 1; i++) {
      if (path.getPoint(i).holonomicRotation != null) {
        return path.getPoint(i);
      }
    }
    return path.getPoint(path.numPoints() - 1);
  }

  /**
   * Get the last lookahead point used by the controller
   *
   * @return The last lookahead point
   */
  public Translation2d getLastLookahead() {
    return lastLookahead;
  }

  /** DO NOT USE. FOR PATHFINDING COMMAND ONLY */
  public void setPath(PathPlannerPath path) {
    this.path = path;
    nextRotationTarget = findNextRotationTarget(0);
  }

  /**
   * Get the last path following inaccuracy of the controller
   *
   * @return Last path following inaccuracy in meters
   */
  public double getLastInaccuracy() {
    return lastInaccuracy;
  }

  /**
   * Calculates the output speeds for the controller given the current pose and speeds of the robot.
   *
   * @param currentPose the current pose of the robot
   * @param currentSpeeds the current speeds of the robot
   * @return the output speeds
   */
  public ChassisSpeeds calculate(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    if (path.numPoints() < 2) {
      return currentSpeeds;
    }

    int closestPointIdx =
        getClosestPointIndex(currentPose.getTranslation(), path.getAllPathPoints());
    lastInaccuracy =
        currentPose.getTranslation().getDistance(path.getPoint(closestPointIdx).position);
    PathConstraints constraints = path.getConstraintsForPoint(closestPointIdx);
    speedsLimiter.setRateLimits(
        constraints.getMaxAccelerationMpsSq(), constraints.getMaxAngularAccelerationRpsSq());

    double currentRobotVel =
        Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);

    double lookaheadDistance = getLookaheadDistance(currentRobotVel, constraints);

    lastLookahead = getLookaheadPoint(currentPose.getTranslation(), lookaheadDistance);

    if (lastLookahead == null) {
      // Path was generated, but we are not close enough to it to find a lookahead point.
      // Gradually increase the lookahead distance until we find a point.
      double extraLookahead = 0.2;
      while (lastLookahead == null) {
        if (extraLookahead > 1.0) {
          // Lookahead not found within reasonable distance, just aim for the start and hope for
          // the best
          lastLookahead = path.getPoint(0).position;
          break;
        }
        lastLookahead =
            getLookaheadPoint(currentPose.getTranslation(), lookaheadDistance + extraLookahead);
        extraLookahead += 0.2;
      }
    }

    double distanceToEnd =
        currentPose.getTranslation().getDistance(path.getPoint(path.numPoints() - 1).position);

    if (holonomic || distanceToEnd > 0.1) {
      targetHeading = lastLookahead.minus(currentPose.getTranslation()).getAngle();
      if (!holonomic && path.isReversed()) {
        targetHeading = targetHeading.plus(Rotation2d.fromDegrees(180));
      }
    }

    double maxAngVel = constraints.getMaxAngularVelocityRps();

    if (holonomic
        && path.getPoint(closestPointIdx).distanceAlongPath
            > nextRotationTarget.distanceAlongPath) {
      nextRotationTarget = findNextRotationTarget(closestPointIdx);
    }

    double rotationVel =
        MathUtil.clamp(
            rotationController.calculate(
                currentPose.getRotation().getRadians(),
                holonomic
                    ? nextRotationTarget.holonomicRotation.getRadians()
                    : targetHeading.getRadians()),
            -maxAngVel,
            maxAngVel);

    if (path.getGoalEndState().getVelocity() == 0 && !lockDecel) {
      double neededDeceleration =
          Math.pow(currentRobotVel - path.getGoalEndState().getVelocity(), 2) / (2 * distanceToEnd);

      if (neededDeceleration >= constraints.getMaxAccelerationMpsSq()) {
        lockDecel = true;
      }
    }

    if (lockDecel) {
      // Deccel without limiter in case it needs to deccel faster than constraints
      double neededDeceleration = Math.pow(currentRobotVel, 2) / (2 * distanceToEnd);

      double nextVel =
          Math.max(
              path.getGoalEndState().getVelocity(), currentRobotVel - (neededDeceleration * 0.02));
      if (neededDeceleration < constraints.getMaxAccelerationMpsSq() * 0.9) {
        nextVel = Math.hypot(lastCommanded.vxMetersPerSecond, lastCommanded.vyMetersPerSecond);
      }

      if (holonomic) {
        double velX = nextVel * targetHeading.getCos();
        double velY = nextVel * targetHeading.getSin();

        lastCommanded = new ChassisSpeeds(velX, velY, rotationVel);
      } else {
        lastCommanded = new ChassisSpeeds(path.isReversed() ? -nextVel : nextVel, 0, rotationVel);
      }

      speedsLimiter.reset(lastCommanded);

      return lastCommanded;
    } else {
      double maxV = Math.min(constraints.getMaxVelocityMps(), path.getPoint(closestPointIdx).maxV);
      double lastVel = Math.hypot(lastCommanded.vxMetersPerSecond, lastCommanded.vyMetersPerSecond);

      double stoppingDistance = Math.pow(lastVel, 2) / (2 * constraints.getMaxAccelerationMpsSq());

      for (int i = closestPointIdx; i < path.numPoints(); i++) {
        if (currentPose.getTranslation().getDistance(path.getPoint(i).position)
            > stoppingDistance) {
          break;
        }

        PathPoint p = path.getPoint(i);
        if (p.maxV < lastVel) {
          double dist = currentPose.getTranslation().getDistance(p.position);
          double neededDeccel = ((lastVel * lastVel) - (p.maxV * p.maxV)) / (2 * dist);
          if (neededDeccel >= constraints.getMaxAccelerationMpsSq()) {
            maxV = p.maxV;
            break;
          }
        }
      }

      if (holonomic) {
        double velX = maxV * targetHeading.getCos();
        double velY = maxV * targetHeading.getSin();

        lastCommanded = speedsLimiter.calculate(new ChassisSpeeds(velX, velY, rotationVel));
      } else {
        lastCommanded =
            speedsLimiter.calculate(
                new ChassisSpeeds(path.isReversed() ? -maxV : maxV, 0, rotationVel));
      }

      return lastCommanded;
    }
  }

  /**
   * Determines whether the robot has reached the end of the path.
   *
   * @param currentPose the current pose of the robot
   * @param currentSpeeds the current speeds of the robot
   * @return true if the robot has reached the end of the path, false otherwise
   */
  public boolean isAtGoal(Pose2d currentPose, ChassisSpeeds currentSpeeds) {
    if (path.numPoints() == 0 || lastLookahead == null) {
      return false;
    }

    Translation2d endPos = path.getPoint(path.numPoints() - 1).position;
    if (lastLookahead.equals(endPos)) {
      double distanceToEnd = currentPose.getTranslation().getDistance(endPos);
      if (path.getGoalEndState().getVelocity() != 0 && distanceToEnd <= 0.1) {
        return true;
      }

      if (distanceToEnd >= lastDistToEnd) {
        if (holonomic && path.getGoalEndState().getVelocity() == 0) {
          double currentVel =
              Math.hypot(currentSpeeds.vxMetersPerSecond, currentSpeeds.vyMetersPerSecond);
          if (currentVel <= 0.1) {
            return true;
          }
        } else {
          return true;
        }
      }

      lastDistToEnd = distanceToEnd;
    }

    return false;
  }

  /**
   * Calculates the lookahead distance for the Pure Pursuit algorithm given the current velocity and
   * path constraints.
   *
   * @param currentVel the current velocity of the robot
   * @param constraints the path constraints for the robot
   * @return the lookahead distance for the Pure Pursuit algorithm
   */
  public static double getLookaheadDistance(double currentVel, PathConstraints constraints) {
    double lookaheadFactor = 1.0 - (0.12 * constraints.getMaxAccelerationMpsSq());
    return Math.max(lookaheadFactor * currentVel, MIN_LOOKAHEAD_DISTANCE);
  }

  private Translation2d getLookaheadPoint(Translation2d robotPos, double r) {
    Translation2d lookahead = null;

    for (int i = 0; i < path.numPoints() - 1; i++) {
      Translation2d segmentStart = path.getPoint(i).position;
      Translation2d segmentEnd = path.getPoint(i + 1).position;

      Translation2d p1 = segmentStart.minus(robotPos);
      Translation2d p2 = segmentEnd.minus(robotPos);

      double dx = p2.getX() - p1.getX();
      double dy = p2.getY() - p1.getY();

      double d = Math.hypot(dx, dy);
      double D = p1.getX() * p2.getY() - p2.getX() * p1.getY();

      double discriminant = Math.pow(r, 2) * Math.pow(d, 2) - Math.pow(D, 2);
      if (discriminant < 0 || p1.equals(p2)) {
        continue;
      }

      int signDy = dy < 0 ? -1 : 1;

      double x1 = (D * dy + signDy * dx * Math.sqrt(discriminant)) / Math.pow(d, 2);
      double x2 = (D * dy - signDy * dx * Math.sqrt(discriminant)) / Math.pow(d, 2);

      double v = Math.abs(dy) * Math.sqrt(discriminant);
      double y1 = (-D * dx + v) / Math.pow(d, 2);
      double y2 = (-D * dx - v) / Math.pow(d, 2);

      boolean validIntersection1 =
          (Math.min(p1.getX(), p2.getX()) < x1 && x1 < Math.max(p1.getX(), p2.getX()))
              || (Math.min(p1.getY(), p2.getY()) < y1 && y1 < Math.max(p1.getY(), p2.getY()));
      boolean validIntersection2 =
          (Math.min(p1.getX(), p2.getX()) < x2 && x2 < Math.max(p1.getX(), p2.getX()))
              || (Math.min(p1.getY(), p2.getY()) < y2 && y2 < Math.max(p1.getY(), p2.getY()));

      if (validIntersection1 && !(validIntersection2 && signDy < 0)) {
        lookahead = new Translation2d(x1, y1).plus(robotPos);
      } else if (validIntersection2) {
        lookahead = new Translation2d(x2, y2).plus(robotPos);
      }
    }

    if (path.numPoints() > 0) {
      Translation2d lastPoint = path.getPoint(path.numPoints() - 1).position;

      if (lastPoint.minus(robotPos).getNorm() <= r) {
        return lastPoint;
      }
    }

    return lookahead;
  }

  private static int getClosestPointIndex(Translation2d p, List<PathPoint> points) {
    // Since we don't care about the actual distance, only use dx + dy to avoid unnecessary
    // multiplication and sqrt calls
    int closestIndex = 0;
    double closestDist = positionDelta(p, points.get(closestIndex).position);

    for (int i = 1; i < points.size(); i++) {
      double d = positionDelta(p, points.get(i).position);

      if (d < closestDist) {
        closestIndex = i;
        closestDist = d;
      }
    }

    return closestIndex;
  }

  private static double positionDelta(Translation2d a, Translation2d b) {
    Translation2d delta = a.minus(b);

    return Math.abs(delta.getX()) + Math.abs(delta.getY());
  }
}
