package com.pathplanner.lib.util;

public class ReplanningConfig {
  public final boolean enableInitialReplanning;
  public final boolean enableDynamicReplanning;
  public final double dynamicReplanningTotalErrorThreshold;
  public final double dynamicReplanningErrorSpikeThreshold;

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

  public ReplanningConfig(boolean enableInitialReplanning, boolean enableDynamicReplanning) {
    this(enableInitialReplanning, enableDynamicReplanning, 1.0, 0.25);
  }

  public ReplanningConfig() {
    this(true, false);
  }
}
