#include "pathplanner/lib/config/RobotConfig.h"
#include <frc/Filesystem.h>
#include <wpi/MemoryBuffer.h>
#include <wpi/json.h>
#include <frc/Errors.h>

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

RobotConfig RobotConfig::fromGUISettings() {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/settings.json";

	std::error_code error_code;
	std::unique_ptr < wpi::MemoryBuffer > fileBuffer =
			wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (error_code) {
		throw FRC_MakeError(frc::err::Error,
				"PathPlanner settings file could not be read");
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	bool isHolonomic = json.at("holonomicMode").get<bool>();
	units::kilogram_t mass { json.at("robotMass").get<double>() };
	units::kilogram_square_meter_t MOI { json.at("robotMOI").get<double>() };
	units::meter_t wheelbase { json.at("robotWheelbase").get<double>() };
	units::meter_t trackwidth { json.at("robotTrackwidth").get<double>() };
	units::meter_t wheelRadius { json.at("driveWheelRadius").get<double>() };
	double gearing = json.at("driveGearing").get<double>();
	units::revolutions_per_minute_t maxDriveRPM { json.at("maxDriveRPM").get<
			double>() };
	double wheelCOF = json.at("wheelCOF").get<double>();
	std::string driveMotor = json.at("driveMotor").get<std::string>();

	ModuleConfig moduleConfig(wheelRadius, gearing, maxDriveRPM, wheelCOF,
			MotorTorqueCurve::fromSettingsString(driveMotor));

	if (isHolonomic) {
		return RobotConfig(mass, MOI, moduleConfig, trackwidth, wheelbase);
	} else {
		return RobotConfig(mass, MOI, moduleConfig, trackwidth);
	}
}
