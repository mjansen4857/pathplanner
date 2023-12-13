// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

#pragma once

#include <frc/geometry/Translation2d.h>
#include <units/velocity.h>
#include <pathplanner/lib/util/HolonomicPathFollowerConfig.h>

/**
 * The Constants header provides a convenient place for teams to hold robot-wide
 * numerical or boolean constants.  This should not be used for any other
 * purpose.
 *
 * It is generally a good idea to place constants into subsystem- or
 * command-specific namespaces within this header, which can then be used where
 * they are needed.
 */

namespace SwerveConstants {

constexpr frc::Translation2d flOffset = frc::Translation2d(0.4_m, 0.4_m);
constexpr frc::Translation2d frOffset = frc::Translation2d(0.4_m, -0.4_m);
constexpr frc::Translation2d blOffset = frc::Translation2d(-0.4_m, 0.4_m);
constexpr frc::Translation2d brOffset = frc::Translation2d(-0.4_m, -0.4_m);

constexpr units::meters_per_second_t maxModuleSpeed = 4.5_mps;

constexpr pathplanner::HolonomicPathFollowerConfig pathFollowerConfig = pathplanner::HolonomicPathFollowerConfig(
    pathplanner::PIDConstants(5.0, 0.0, 0.0), // Translation constants 
    pathplanner::PIDConstants(5.0, 0.0, 0.0), // Rotation constants 
    maxModuleSpeed,
    0.57_m, // Drive base radius (distance from center to furthest module) 
    pathplanner::ReplanningConfig()
);

}  // namespace SwerveConstants
