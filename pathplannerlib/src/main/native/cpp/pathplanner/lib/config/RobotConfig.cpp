#include "pathplanner/lib/config/RobotConfig.h"

using namespace pathplanner;

RobotConfig::RobotConfig(units::kilogram_t mass,
		units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
		units::meter_t trackwidth, units::meter_t wheelbase) : mass(mass), MOI(
		MOI), moduleConfig(moduleConfig), moduleLocations { frc::Translation2d(
		wheelbase / 2, trackwidth / 2), frc::Translation2d(wheelbase / 2,
		-trackwidth / 2), frc::Translation2d(-wheelbase / 2, trackwidth / 2),
		frc::Translation2d(-wheelbase / 2, -trackwidth / 2) }, swerveKinematics(
		frc::Translation2d(wheelbase / 2, trackwidth / 2),
		frc::Translation2d(wheelbase / 2, -trackwidth / 2),
		frc::Translation2d(-wheelbase / 2, trackwidth / 2),
		frc::Translation2d(-wheelbase / 2, -trackwidth / 2)), diffKinematics(
		frc::Translation2d(0_m, trackwidth / 2),
		frc::Translation2d(0_m, -trackwidth / 2)), isHolonomic(true), numModules(
		4), modulePivotDistance { moduleLocations[0].Norm(),
		moduleLocations[1].Norm(), moduleLocations[2].Norm(),
		moduleLocations[3].Norm() }, wheelFrictionForce { moduleConfig.wheelCOF
		* (mass() * 9.8) } {
}

RobotConfig::RobotConfig(units::kilogram_t mass,
		units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
		units::meter_t trackwidth) : mass(mass), MOI(MOI), moduleConfig(
		moduleConfig), moduleLocations { frc::Translation2d(0_m,
		trackwidth / 2), frc::Translation2d(0_m, -trackwidth / 2) }, swerveKinematics(
		frc::Translation2d(trackwidth / 2, trackwidth / 2),
		frc::Translation2d(trackwidth / 2, -trackwidth / 2),
		frc::Translation2d(-trackwidth / 2, trackwidth / 2),
		frc::Translation2d(-trackwidth / 2, -trackwidth / 2)), diffKinematics(
		frc::Translation2d(0_m, trackwidth / 2),
		frc::Translation2d(0_m, -trackwidth / 2)), isHolonomic(false), numModules(
		2), modulePivotDistance { moduleLocations[0].Norm(),
		moduleLocations[1].Norm() }, wheelFrictionForce { moduleConfig.wheelCOF
		* (mass() * 9.8) } {
}

// RobotConfig RobotConfig::fromGUISettings() {

// }
