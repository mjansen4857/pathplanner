// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

#pragma once

#include <frc2/command/CommandPtr.h>

#include "subsystems/SwerveSubsystem.h"

/**
 * This class is where the bulk of the robot should be declared.  Since
 * Command-based is a "declarative" paradigm, very little robot logic should
 * actually be handled in the {@link Robot} periodic methods (other than the
 * scheduler calls).  Instead, the structure of the robot (including subsystems,
 * commands, and trigger mappings) should be declared here.
 */
class RobotContainer {
 public:
  RobotContainer();

  frc2::CommandPtr GetAutonomousCommand();

 private:
  SwerveSubsystem swerve;

  std::unique_ptr<frc2::Command> exampleAuto;
  std::unique_ptr<frc2::Command> pathfindToPickup;
  std::unique_ptr<frc2::Command> pathfindToScore;
  std::unique_ptr<frc2::Command> onTheFly;
  std::unique_ptr<frc2::Command> followOnTheFly;

  void ConfigureBindings();
};
