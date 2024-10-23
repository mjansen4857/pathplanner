package com.pathplanner.lib.util;

import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;

/** Utility class for flipping positions/rotations to the other side of the field */
public class FlippingUtil {
  /** The type of symmetry for the current field */
  public static FieldSymmetry symmetryType = FieldSymmetry.kMirrored;
  /** The X size or length of the current field in meters */
  public static double fieldSizeX = 16.54175;
  /** The Y size or width of the current field in meters */
  public static double fieldSizeY = 8.211;

  /** Enum representing the different types of field symmetry */
  public enum FieldSymmetry {
    /**
     * Field is rotationally symmetric. i.e. the red alliance side is the blue alliance side rotated
     * by 180 degrees
     */
    kRotational,
    /** Field is mirrored vertically over the center of the field */
    kMirrored
  }

  /**
   * Flip a field position to the other side of the field, maintaining a blue alliance origin
   *
   * @param pos The position to flip
   * @return The flipped position
   */
  public static Translation2d flipFieldPosition(Translation2d pos) {
    return switch (symmetryType) {
      case kMirrored -> new Translation2d(fieldSizeX - pos.getX(), pos.getY());
      case kRotational -> new Translation2d(fieldSizeX - pos.getX(), fieldSizeY - pos.getY());
    };
  }

  /**
   * Flip a field rotation to the other side of the field, maintaining a blue alliance origin
   *
   * @param rotation The rotation to flip
   * @return The flipped rotation
   */
  public static Rotation2d flipFieldRotation(Rotation2d rotation) {
    return switch (symmetryType) {
      case kMirrored -> new Rotation2d(Math.PI).minus(rotation);
      case kRotational -> rotation.minus(new Rotation2d(Math.PI));
    };
  }

  /**
   * Flip a field pose to the other side of the field, maintaining a blue alliance origin
   *
   * @param pose The pose to flip
   * @return The flipped pose
   */
  public static Pose2d flipFieldPose(Pose2d pose) {
    return new Pose2d(
        flipFieldPosition(pose.getTranslation()), flipFieldRotation(pose.getRotation()));
  }

  /**
   * Flip field relative chassis speeds for the other side of the field, maintaining a blue alliance
   * origin
   *
   * @param fieldSpeeds Field relative chassis speeds
   * @return Flipped speeds
   */
  public static ChassisSpeeds flipFieldSpeeds(ChassisSpeeds fieldSpeeds) {
    return switch (symmetryType) {
      case kMirrored -> new ChassisSpeeds(
          -fieldSpeeds.vxMetersPerSecond,
          fieldSpeeds.vyMetersPerSecond,
          -fieldSpeeds.omegaRadiansPerSecond);
      case kRotational -> new ChassisSpeeds(
          -fieldSpeeds.vxMetersPerSecond,
          -fieldSpeeds.vxMetersPerSecond,
          fieldSpeeds.omegaRadiansPerSecond);
    };
  }

  /**
   * Flip an array of drive feedforwards for the other side of the field. Only does anything if
   * mirrored symmetry is used
   *
   * @param feedforwards Array of drive feedforwards
   * @return The flipped feedforwards
   */
  public static double[] flipFeedforwards(double[] feedforwards) {
    return switch (symmetryType) {
      case kMirrored -> {
        if (feedforwards.length == 4) {
          yield new double[] {feedforwards[1], feedforwards[0], feedforwards[3], feedforwards[2]};
        } else if (feedforwards.length == 2) {
          yield new double[] {feedforwards[1], feedforwards[0]};
        }
        yield feedforwards; // idk
      }
      case kRotational -> feedforwards;
    };
  }

  /**
   * Flip an array of drive feedforward X components for the other side of the field. Only does
   * anything if mirrored symmetry is used
   *
   * @param feedforwardXs Array of drive feedforward X components
   * @return The flipped feedforward X components
   */
  public static double[] flipFeedforwardXs(double[] feedforwardXs) {
    return flipFeedforwards(feedforwardXs);
  }

  /**
   * Flip an array of drive feedforward Y components for the other side of the field. Only does
   * anything if mirrored symmetry is used
   *
   * @param feedforwardYs Array of drive feedforward Y components
   * @return The flipped feedforward Y components
   */
  public static double[] flipFeedforwardYs(double[] feedforwardYs) {
    var flippedFeedforwardYs = flipFeedforwards(feedforwardYs);
    return switch (symmetryType) {
      case kMirrored -> {
        // Y directions also need to be inverted
        for (int i = 0; i < flippedFeedforwardYs.length; ++i) {
          flippedFeedforwardYs[i] *= -1;
        }
        yield flippedFeedforwardYs;
      }
      case kRotational -> flippedFeedforwardYs;
    };
  }
}
