#pragma once

#include <units/velocity.h>
#include <units/length.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Translation2d.h>

namespace pathplanner {
class SwerveModuleTrajectoryState {
public:
	units::meters_per_second_t speed = 0_mps;
	frc::Rotation2d angle;
	frc::Rotation2d fieldAngle;
	frc::Translation2d fieldPos;

	units::meter_t deltaPos = 0_m;
};
}
