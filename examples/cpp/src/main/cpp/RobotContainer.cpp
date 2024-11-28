// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

#include "RobotContainer.h"
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <pathplanner/lib/path/PathPlannerPath.h>
#include <pathplanner/lib/commands/PathPlannerAuto.h>
#include <pathplanner/lib/auto/NamedCommands.h>
#include <pathplanner/lib/events/EventTrigger.h>
#include <frc/smartdashboard/SmartDashboard.h>
#include <frc2/command/Commands.h>

using namespace pathplanner;

RobotContainer::RobotContainer() {
  // Register named commands
  NamedCommands::registerCommand("marker1", frc2::cmd::Print("Passed marker 1"));
  NamedCommands::registerCommand("marker2", frc2::cmd::Print("Passed marker 2"));
  NamedCommands::registerCommand("print hello", frc2::cmd::Print("hello"));

  // Use an event marker as a trigger
  EventTrigger("Example Marker").OnTrue(frc2::cmd::Print("passed an event marker"));

  // Configure the button bindings
  ConfigureBindings();
}

void RobotContainer::ConfigureBindings() {
  // Add a button to run the example auto to SmartDashboard, this will also be in the GetAutonomousCommand method below
  exampleAuto = PathPlannerAuto("Example Auto").ToPtr().Unwrap();
  frc::SmartDashboard::PutData("Example Auto", exampleAuto.get());

  // Add a button to run pathfinding commands to SmartDashboard
  pathfindToPickup = AutoBuilder::pathfindToPose(
    frc::Pose2d(14.0_m, 6.5_m, frc::Rotation2d(0_deg)),
    PathConstraints(4.0_mps, 4.0_mps_sq, 360_deg_per_s, 540_deg_per_s_sq),
    0_mps
  ).Unwrap();
  frc::SmartDashboard::PutData("Pathfind to Pickup Pos", pathfindToPickup.get());
  pathfindToScore = AutoBuilder::pathfindToPose(
    frc::Pose2d(2.15_m, 3.0_m, frc::Rotation2d(180_deg)),
    PathConstraints(4.0_mps, 4.0_mps_sq, 360_deg_per_s, 540_deg_per_s_sq),
    0_mps
  ).Unwrap();
  frc::SmartDashboard::PutData("Pathfind to Scoring Pos", pathfindToScore.get());

  // Add a button to SmartDashboard that will create and follow an on-the-fly path
  // This example will simply move the robot 2m in the +X field direction
  onTheFly = frc2::cmd::RunOnce([this]() {
    frc::Pose2d currentPose = this->swerve.getPose();

    // The rotation component in these poses represents the direction of travel
    frc::Pose2d startPos = frc::Pose2d(currentPose.Translation(), frc::Rotation2d());
    frc::Pose2d endPos = frc::Pose2d(currentPose.Translation() + frc::Translation2d(2.0_m, 0_m), frc::Rotation2d());

    std::vector<Waypoint> waypoints = PathPlannerPath::waypointsFromPoses({startPos, endPos});
    // Paths must be used as shared pointers
    auto path = std::make_shared<PathPlannerPath>(
      waypoints, 
      PathConstraints(4.0_mps, 4.0_mps_sq, 360_deg_per_s, 540_deg_per_s_sq),
      std::nullopt, // Ideal starting state can be nullopt for on-the-fly paths
      GoalEndState(0_mps, currentPose.Rotation())
    );

    // Prevent this path from being flipped on the red alliance, since the given positions are already correct
    path->preventFlipping = true;

    this->followOnTheFly = AutoBuilder::followPath(path).Unwrap();
    this->followOnTheFly->Schedule();
  }).Unwrap();
  frc::SmartDashboard::PutData("On-the-fly path", onTheFly.get());
}

frc2::CommandPtr RobotContainer::GetAutonomousCommand() {
  return PathPlannerAuto("Example Auto").ToPtr();
}
