#pragma once

#include <units/mass.h>
#include <units/length.h>
#include <units/force.h>
#include <units/moment_of_inertia.h>
#include <frc/geometry/Translation2d.h>
#include <frc/kinematics/SwerveDriveKinematics.h>
#include <vector>
#include "pathplanner/lib/config/ModuleConfig.h"

namespace pathplanner {
class RobotConfig {
public:
	units::kilogram_t mass;
	units::kilogram_square_meter_t MOI;
	ModuleConfig moduleConfig;

	std::vector<frc::Translation2d> moduleLocations;

	// Need two different kinematics objects since the class is templated but having
	// RobotConfig also templated would be pretty bad to work with
	frc::SwerveDriveKinematics<4> swerveKinematics;
	frc::SwerveDriveKinematics<2> diffKinematics;
	bool isHolonomic;

	size_t numModules;
	std::vector<units::meter_t> modulePivotDistance;
	units::newton_t wheelFrictionForce;

	RobotConfig(units::kilogram_t mass, units::kilogram_square_meter_t MOI,
			ModuleConfig moduleConfig, units::meter_t trackwidth,
			units::meter_t wheelbase);

	RobotConfig(units::kilogram_t mass, units::kilogram_square_meter_t MOI,
			ModuleConfig moduleConfig, units::meter_t trackwidth);

	static RobotConfig fromGUISettings();
};
}
