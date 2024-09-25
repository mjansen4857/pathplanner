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

	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw FRC_MakeError(frc::err::Error,
				"PathPlanner settings file could not be read");
	}

	wpi::json json = wpi::json::parse(fileBuffer.value()->GetCharBuffer());

	bool isHolonomic = json.at("holonomicMode").get<bool>();
	units::kilogram_t mass { json.at("robotMass").get<double>() };
	units::kilogram_square_meter_t MOI { json.at("robotMOI").get<double>() };
	units::meter_t wheelbase { json.at("robotWheelbase").get<double>() };
	units::meter_t trackwidth { json.at("robotTrackwidth").get<double>() };
	units::meter_t wheelRadius { json.at("driveWheelRadius").get<double>() };
	double gearing = json.at("driveGearing").get<double>();
	units::meters_per_second_t maxDriveSpeed { json.at("maxDriveSpeed").get<
			double>() };
	double wheelCOF = json.at("wheelCOF").get<double>();
	std::string driveMotor = json.at("driveMotorType").get<std::string>();
	units::ampere_t driveCurrentLimit {
			json.at("driveCurrentLimit").get<double>() };

	int numMotors = isHolonomic ? 1 : 2;
	frc::DCMotor gearbox = RobotConfig::getMotorFromSettingsString(driveMotor,
			numMotors).WithReduction(gearing);

	ModuleConfig moduleConfig(wheelRadius, maxDriveSpeed, wheelCOF, gearbox,
			driveCurrentLimit);

	if (isHolonomic) {
		return RobotConfig(mass, MOI, moduleConfig, trackwidth, wheelbase);
	} else {
		return RobotConfig(mass, MOI, moduleConfig, trackwidth);
	}
}

frc::DCMotor RobotConfig::getMotorFromSettingsString(std::string motorStr,
		int numMotors) {
	if (motorStr == "krakenX60") {
		return frc::DCMotor::KrakenX60(numMotors);
	} else if (motorStr == "krakenX60FOC") {
		return frc::DCMotor::KrakenX60FOC(numMotors);
	} else if (motorStr == "falcon500") {
		return frc::DCMotor::Falcon500(numMotors);
	} else if (motorStr == "falcon500FOC") {
		return frc::DCMotor::Falcon500FOC(numMotors);
	} else if (motorStr == "vortex") {
		return frc::DCMotor::NeoVortex(numMotors);
	} else if (motorStr == "NEO") {
		return frc::DCMotor::NEO(numMotors);
	} else if (motorStr == "CIM") {
		return frc::DCMotor::CIM(numMotors);
	} else if (motorStr == "miniCIM") {
		return frc::DCMotor::MiniCIM(numMotors);
	} else {
		throw std::invalid_argument("Unknown motor type string: " + motorStr);
	}
}
