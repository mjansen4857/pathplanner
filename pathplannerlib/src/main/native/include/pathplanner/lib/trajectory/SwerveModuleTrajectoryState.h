#pragma once

#include <wpi/units/velocity.hpp>
#include <wpi/units/length.hpp>
#include <wpi/math/geometry/Rotation2d.hpp>
#include <wpi/math/geometry/Translation2d.hpp>

namespace pathplanner {
class SwerveModuleTrajectoryState {
public:
	wpi::units::meters_per_second_t speed = 0_mps;
	wpi::math::Rotation2d angle;
	wpi::math::Rotation2d fieldAngle;
	wpi::math::Translation2d fieldPos;

	wpi::units::meter_t deltaPos = 0_m;
};
}
