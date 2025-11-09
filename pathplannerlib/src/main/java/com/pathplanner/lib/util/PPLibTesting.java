package com.pathplanner.lib.util;

import com.pathplanner.lib.auto.AutoBuilder;
import com.pathplanner.lib.auto.NamedCommands;
import com.pathplanner.lib.commands.PathPlannerAuto;
import com.pathplanner.lib.controllers.PPHolonomicDriveController;

/** Utility class for testing code that uses Pathplanner lib */
public class PPLibTesting {

  /**
   * Resets all static state to the values set at class initialization time.
   *
   * <p>This method should not be called during a competition. It makes a best-effort attempt to
   * reset the state, and may not update all static state.
   */
  public static void resetForTesting() {
    AutoBuilder.resetForTesting();
    PathPlannerAuto.setCurrentTrajectory(null);
    NamedCommands.clearAll();
    PathPlannerLogging.clearLoggingCallbacks();
    PPHolonomicDriveController.clearFeedbackOverrides();
  }

  private PPLibTesting() {}
}
