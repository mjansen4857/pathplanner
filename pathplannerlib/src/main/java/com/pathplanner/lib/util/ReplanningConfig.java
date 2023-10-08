package com.pathplanner.lib.util;

/** Configuration for path replanning */
public class ReplanningConfig {
  /**
   * Should the path be replanned at the start of path following if the robot is not already at the
   * starting point?
   */
  public final boolean enableInitialReplanning;
  /**
   * Should the path be replanned if the error grows too large or if a large error spike happens
   * while following the path?
   */
  public final boolean enableDynamicReplanning;
  /** The total error threshold, in meters, that will cause the path to be replanned */
  public final double dynamicReplanningTotalErrorThreshold;
  /** The error spike threshold, in meters, that will cause the path to be replanned */
  public final double dynamicReplanningErrorSpikeThreshold;

  /**
   * Create a path replanning configuration
   *
   * @param enableInitialReplanning Should the path be replanned at the start of path following if
   *     the robot is not already at the starting point?
   * @param enableDynamicReplanning Should the path be replanned if the error grows too large or if
   *     a large error spike happens while following the path?
   * @param dynamicReplanningTotalErrorThreshold The total error threshold, in meters, that will
   *     cause the path to be replanned
   * @param dynamicReplanningErrorSpikeThreshold The error spike threshold, in meters, that will
   *     cause the path to be replanned
   */
  public ReplanningConfig(
      boolean enableInitialReplanning,
      boolean enableDynamicReplanning,
      double dynamicReplanningTotalErrorThreshold,
      double dynamicReplanningErrorSpikeThreshold) {
    this.enableInitialReplanning = enableInitialReplanning;
    this.enableDynamicReplanning = enableDynamicReplanning;
    this.dynamicReplanningTotalErrorThreshold = dynamicReplanningTotalErrorThreshold;
    this.dynamicReplanningErrorSpikeThreshold = dynamicReplanningErrorSpikeThreshold;
  }

  /**
   * Create a path replanning configuration with default dynamic replanning error thresholds
   *
   * @param enableInitialReplanning Should the path be replanned at the start of path following if
   *     the robot is not already at the starting point?
   * @param enableDynamicReplanning Should the path be replanned if the error grows too large or if
   *     a large error spike happens while following the path?
   */
  public ReplanningConfig(boolean enableInitialReplanning, boolean enableDynamicReplanning) {
    this(enableInitialReplanning, enableDynamicReplanning, 1.0, 0.25);
  }

  /**
   * Create a path replanning configuration with the default config. This will only have initial
   * replanning enabled.
   */
  public ReplanningConfig() {
    this(true, false);
  }
}
