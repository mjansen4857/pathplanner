package com.pathplanner.lib.config;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

import org.junit.jupiter.api.Test;
import org.wpilib.math.geometry.Translation2d;
import org.wpilib.math.system.DCMotor;

public class RobotConfigTest {
  @Test
  public void testLoadsWithValidationAlerts() {
    // Loading RobotConfig allocates its validation alerts, which must have unique IDs
    assertDoesNotThrow(
        () ->
            new RobotConfig(
                50.0,
                5.0,
                new ModuleConfig(0.048, 5.0, 1.2, DCMotor.getKrakenX60(1), 60.0, 1),
                new Translation2d(0.3, 0.3),
                new Translation2d(0.3, -0.3),
                new Translation2d(-0.3, 0.3),
                new Translation2d(-0.3, -0.3)));
  }
}
