// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

#pragma once

#include <frc/geometry/Translation2d.h>
#include <units/velocity.h>
#include <pathplanner/lib/config/PIDConstants.h>

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

inline constexpr frc::Translation2d flOffset = frc::Translation2d(0.273_m, 0.273_m);
inline constexpr frc::Translation2d frOffset = frc::Translation2d(0.273_m, -0.273_m);
inline constexpr frc::Translation2d blOffset = frc::Translation2d(-0.273_m, 0.273_m);
inline constexpr frc::Translation2d brOffset = frc::Translation2d(-0.273_m, -0.273_m);

inline constexpr pathplanner::PIDConstants translationConstants(5.0, 0.0, 0.0);
inline constexpr pathplanner::PIDConstants rotationConstants(5.0, 0.0, 0.0);

}  // namespace SwerveConstants
