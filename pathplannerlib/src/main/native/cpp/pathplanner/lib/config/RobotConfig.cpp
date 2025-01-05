#include "pathplanner/lib/config/RobotConfig.h"
#include <frc/Filesystem.h>
#include <wpi/MemoryBuffer.h>
#include <wpi/json.h>
#include <frc/Errors.h>

using namespace pathplanner;

RobotConfig::RobotConfig() : swerveKinematics(frc::Translation2d(0_m, 0_m),
		frc::Translation2d(0_m, 0_m), frc::Translation2d(0_m, 0_m),
		frc::Translation2d(0_m, 0_m)), diffKinematics(0.7_m) {
}

RobotConfig::RobotConfig(units::kilogram_t mass,
		units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
		std::vector<frc::Translation2d> moduleOffsets) : mass(mass), MOI(MOI), moduleConfig(
		moduleConfig), moduleLocations(moduleOffsets), isHolonomic(true), numModules(
		4), modulePivotDistance { moduleLocations[0].Norm(),
		moduleLocations[1].Norm(), moduleLocations[2].Norm(),
		moduleLocations[3].Norm() }, wheelFrictionForce { moduleConfig.wheelCOF
		* ((mass() / numModules) * 9.8) }, maxTorqueFriction(
		wheelFrictionForce * moduleConfig.wheelRadius), swerveKinematics {
		moduleLocations[0], moduleLocations[1], moduleLocations[2],
		moduleLocations[3] }, diffKinematics(0.7_m) {
	for (size_t i = 0; i < numModules; i++) {
		frc::Translation2d modPosReciprocal = frc::Translation2d(
				units::meter_t { 1.0 / moduleLocations[i].Norm()() },
				moduleLocations[i].Angle());
		swerveForceKinematics.template block<2, 3>(i * 2, 0) << 1, 0, (-modPosReciprocal.Y()).value(), 0, 1, (modPosReciprocal.X()).value();
	}
	// No need to set up diff force kinematics, it will not be used
}

RobotConfig::RobotConfig(units::kilogram_t mass,
		units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
		units::meter_t trackwidth) : mass(mass), MOI(MOI), moduleConfig(
		moduleConfig), moduleLocations { frc::Translation2d(0_m,
		trackwidth / 2), frc::Translation2d(0_m, -trackwidth / 2) }, isHolonomic(
		false), numModules(2), modulePivotDistance { moduleLocations[0].Norm(),
		moduleLocations[1].Norm() }, wheelFrictionForce { moduleConfig.wheelCOF
		* ((mass() / numModules) * 9.8) }, maxTorqueFriction(
		wheelFrictionForce * moduleConfig.wheelRadius), swerveKinematics(
		frc::Translation2d(trackwidth / 2, trackwidth / 2),
		frc::Translation2d(trackwidth / 2, -trackwidth / 2),
		frc::Translation2d(-trackwidth / 2, trackwidth / 2),
		frc::Translation2d(-trackwidth / 2, -trackwidth / 2)), diffKinematics(
		trackwidth) {
	for (size_t i = 0; i < numModules; i++) {
		frc::Translation2d modPosReciprocal = frc::Translation2d(
				units::meter_t { 1.0 / moduleLocations[i].Norm()() },
				moduleLocations[i].Angle());
		diffForceKinematics.template block<2, 3>(i * 2, 0) << 1, 0, (-modPosReciprocal.Y()).value(), 0, 1, (modPosReciprocal.X()).value();
	}
	// No need to set up swerve force kinematics, it will not be used
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
			driveCurrentLimit, numMotors);

	if (isHolonomic) {
		units::meter_t flModuleX { json.at("flModuleX").get<double>() };
		units::meter_t flModuleY { json.at("flModuleY").get<double>() };
		units::meter_t frModuleX { json.at("frModuleX").get<double>() };
		units::meter_t frModuleY { json.at("frModuleY").get<double>() };
		units::meter_t blModuleX { json.at("blModuleX").get<double>() };
		units::meter_t blModuleY { json.at("blModuleY").get<double>() };
		units::meter_t brModuleX { json.at("brModuleX").get<double>() };
		units::meter_t brModuleY { json.at("brModuleY").get<double>() };

		return RobotConfig(mass, MOI, moduleConfig,
				{ frc::Translation2d(flModuleX, flModuleY), frc::Translation2d(
						frModuleX, frModuleY), frc::Translation2d(blModuleX,
						blModuleY), frc::Translation2d(brModuleX, brModuleY) });
	} else {
		units::meter_t trackwidth { json.at("robotTrackwidth").get<double>() };

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

std::vector<frc::SwerveModuleState> RobotConfig::toSwerveModuleStates(
		frc::ChassisSpeeds speeds) const {
	if (isHolonomic) {
		auto states = swerveKinematics.ToSwerveModuleStates(speeds);
		return std::vector < frc::SwerveModuleState
				> (states.begin(), states.end());
	} else {
		auto wheelSpeeds = diffKinematics.ToWheelSpeeds(speeds);
		return std::vector<frc::SwerveModuleState> { frc::SwerveModuleState {
				wheelSpeeds.left, frc::Rotation2d() }, frc::SwerveModuleState {
				wheelSpeeds.right, frc::Rotation2d() } };
	}
}

frc::ChassisSpeeds RobotConfig::toChassisSpeeds(
		std::vector<SwerveModuleTrajectoryState> states) const {
	if (isHolonomic) {
		wpi::array < frc::SwerveModuleState, 4 > wpiStates {
				frc::SwerveModuleState { states[0].speed, states[0].angle },
				frc::SwerveModuleState { states[1].speed, states[1].angle },
				frc::SwerveModuleState { states[2].speed, states[2].angle },
				frc::SwerveModuleState { states[3].speed, states[3].angle } };
		return swerveKinematics.ToChassisSpeeds(wpiStates);
	} else {
		frc::DifferentialDriveWheelSpeeds wheelSpeeds { states[0].speed,
				states[1].speed };
		return diffKinematics.ToChassisSpeeds(wheelSpeeds);
	}
}

frc::ChassisSpeeds RobotConfig::toChassisSpeeds(
		std::vector<frc::SwerveModuleState> states) const {
	if (isHolonomic) {
		wpi::array < frc::SwerveModuleState, 4 > wpiStates { states.at(0),
				states.at(1), states.at(2), states.at(3) };
		return swerveKinematics.ToChassisSpeeds(wpiStates);
	} else {
		frc::DifferentialDriveWheelSpeeds wheelSpeeds { states.at(0).speed,
				states.at(1).speed };
		return diffKinematics.ToChassisSpeeds(wheelSpeeds);
	}
}

std::vector<frc::SwerveModuleState> RobotConfig::desaturateWheelSpeeds(
		std::vector<frc::SwerveModuleState> moduleStates,
		units::meters_per_second_t maxSpeed) const {
	wpi::array < frc::SwerveModuleState, 4 > wpiStates { moduleStates.at(0),
			moduleStates.at(1), moduleStates.at(2), moduleStates.at(3) };
	swerveKinematics.DesaturateWheelSpeeds(&wpiStates, maxSpeed);

	return std::vector < frc::SwerveModuleState
			> (wpiStates.begin(), wpiStates.end());
}

std::vector<frc::Translation2d> RobotConfig::chassisForcesToWheelForceVectors(
		frc::ChassisSpeeds chassisForces) const {
	Eigen::Vector3d chassisForceVector { chassisForces.vx.value(),
			chassisForces.vy.value(), chassisForces.omega.value() };
	std::vector < frc::Translation2d > forceVectors;

	if (isHolonomic) {
		frc::Matrixd < 4 * 2, 1 > moduleForceMatrix = swerveForceKinematics
				* (chassisForceVector / numModules);
		for (size_t i = 0; i < numModules; i++) {
			units::meter_t x { moduleForceMatrix(i * 2, 0) };
			units::meter_t y { moduleForceMatrix(i * 2 + 1, 0) };

			forceVectors.emplace_back(x, y);
		}
	} else {
		frc::Matrixd < 2 * 2, 1 > moduleForceMatrix = diffForceKinematics
				* (chassisForceVector / numModules);
		for (size_t i = 0; i < numModules; i++) {
			units::meter_t x { moduleForceMatrix(i * 2, 0) };
			units::meter_t y { moduleForceMatrix(i * 2 + 1, 0) };

			forceVectors.emplace_back(x, y);
		}
	}

	return forceVectors;
}
