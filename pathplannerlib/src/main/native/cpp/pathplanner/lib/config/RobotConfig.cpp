#include "pathplanner/lib/config/RobotConfig.h"
#include <wpi/system/Filesystem.hpp>
#include <wpi/util/MemoryBuffer.hpp>
#include <wpi/util/json.hpp>
#include <wpi/system/Errors.hpp>

using namespace pathplanner;

RobotConfig::RobotConfig() : swerveKinematics(
		wpi::math::Translation2d(0_m, 0_m), wpi::math::Translation2d(0_m, 0_m),
		wpi::math::Translation2d(0_m, 0_m), wpi::math::Translation2d(0_m, 0_m)), diffKinematics(
		0.7_m) {
}

RobotConfig::RobotConfig(wpi::units::kilogram_t mass,
		wpi::units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
		std::vector<wpi::math::Translation2d> moduleOffsets) : mass(mass), MOI(
		MOI), moduleConfig(moduleConfig), moduleLocations(moduleOffsets), isHolonomic(
		true), numModules(4), modulePivotDistance { moduleLocations[0].Norm(),
		moduleLocations[1].Norm(), moduleLocations[2].Norm(),
		moduleLocations[3].Norm() }, wheelFrictionForce { moduleConfig.wheelCOF
		* ((mass() / numModules) * 9.8) }, maxTorqueFriction(
		wheelFrictionForce * moduleConfig.wheelRadius), swerveKinematics {
		moduleLocations[0], moduleLocations[1], moduleLocations[2],
		moduleLocations[3] }, diffKinematics(0.7_m) {
	for (size_t i = 0; i < numModules; i++) {
		wpi::math::Translation2d modPosReciprocal = wpi::math::Translation2d(
				wpi::units::meter_t { 1.0 / moduleLocations[i].Norm()() },
				moduleLocations[i].Angle());
		swerveForceKinematics.template block<2, 3>(i * 2, 0) << 1, 0, (-modPosReciprocal.Y()).value(), 0, 1, (modPosReciprocal.X()).value();
	}
	// No need to set up diff force kinematics, it will not be used
}

RobotConfig::RobotConfig(wpi::units::kilogram_t mass,
		wpi::units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
		wpi::units::meter_t trackwidth) : mass(mass), MOI(MOI), moduleConfig(
		moduleConfig), moduleLocations { wpi::math::Translation2d(0_m,
		trackwidth / 2), wpi::math::Translation2d(0_m, -trackwidth / 2) }, isHolonomic(
		false), numModules(2), modulePivotDistance { moduleLocations[0].Norm(),
		moduleLocations[1].Norm() }, wheelFrictionForce { moduleConfig.wheelCOF
		* ((mass() / numModules) * 9.8) }, maxTorqueFriction(
		wheelFrictionForce * moduleConfig.wheelRadius), swerveKinematics(
		wpi::math::Translation2d(trackwidth / 2, trackwidth / 2),
		wpi::math::Translation2d(trackwidth / 2, -trackwidth / 2),
		wpi::math::Translation2d(-trackwidth / 2, trackwidth / 2),
		wpi::math::Translation2d(-trackwidth / 2, -trackwidth / 2)), diffKinematics(
		trackwidth) {
	for (size_t i = 0; i < numModules; i++) {
		wpi::math::Translation2d modPosReciprocal = wpi::math::Translation2d(
				wpi::units::meter_t { 1.0 / moduleLocations[i].Norm()() },
				moduleLocations[i].Angle());
		diffForceKinematics.template block<2, 3>(i * 2, 0) << 1, 0, (-modPosReciprocal.Y()).value(), 0, 1, (modPosReciprocal.X()).value();
	}
	// No need to set up swerve force kinematics, it will not be used
}

RobotConfig RobotConfig::fromGUISettings() {
	const std::string filePath = wpi::filesystem::GetDeployDirectory()
			+ "/pathplanner/settings.json";

	auto fileBuffer = wpi::util::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw WPILIB_MakeError(wpi::err::Error,
				"PathPlanner settings file could not be read");
	}

	auto charBuffer = fileBuffer.value()->GetCharBuffer();
	wpi::util::json json = wpi::util::json::parse_or_throw(std::string_view {
			charBuffer.data(), charBuffer.size() });

	bool isHolonomic = json.at("holonomicMode").get_bool();
	wpi::units::kilogram_t mass { json.at("robotMass").get_number() };
	wpi::units::kilogram_square_meter_t MOI { json.at("robotMOI").get_number() };
	wpi::units::meter_t wheelRadius { json.at("driveWheelRadius").get_number() };
	double gearing = json.at("driveGearing").get_number();
	wpi::units::meters_per_second_t maxDriveSpeed {
			json.at("maxDriveSpeed").get_number() };
	double wheelCOF = json.at("wheelCOF").get_number();
	std::string driveMotor = json.at("driveMotorType").get_string();
	wpi::units::ampere_t driveCurrentLimit {
			json.at("driveCurrentLimit").get_number() };

	int numMotors = isHolonomic ? 1 : 2;
	wpi::math::DCMotor gearbox = RobotConfig::getMotorFromSettingsString(
			driveMotor, numMotors).WithReduction(gearing);

	ModuleConfig moduleConfig(wheelRadius, maxDriveSpeed, wheelCOF, gearbox,
			driveCurrentLimit, numMotors);

	if (isHolonomic) {
		wpi::units::meter_t flModuleX { json.at("flModuleX").get_number() };
		wpi::units::meter_t flModuleY { json.at("flModuleY").get_number() };
		wpi::units::meter_t frModuleX { json.at("frModuleX").get_number() };
		wpi::units::meter_t frModuleY { json.at("frModuleY").get_number() };
		wpi::units::meter_t blModuleX { json.at("blModuleX").get_number() };
		wpi::units::meter_t blModuleY { json.at("blModuleY").get_number() };
		wpi::units::meter_t brModuleX { json.at("brModuleX").get_number() };
		wpi::units::meter_t brModuleY { json.at("brModuleY").get_number() };

		return RobotConfig(mass, MOI, moduleConfig,
				{ wpi::math::Translation2d(flModuleX, flModuleY),
						wpi::math::Translation2d(frModuleX, frModuleY),
						wpi::math::Translation2d(blModuleX, blModuleY),
						wpi::math::Translation2d(brModuleX, brModuleY) });
	} else {
		wpi::units::meter_t trackwidth { json.at("robotTrackwidth").get_number() };

		return RobotConfig(mass, MOI, moduleConfig, trackwidth);
	}
}

wpi::math::DCMotor RobotConfig::getMotorFromSettingsString(std::string motorStr,
		int numMotors) {
	if (motorStr == "krakenX60") {
		return wpi::math::DCMotor::KrakenX60(numMotors);
	} else if (motorStr == "krakenX60FOC") {
		return wpi::math::DCMotor::KrakenX60FOC(numMotors);
	} else if (motorStr == "falcon500") {
		return wpi::math::DCMotor::Falcon500(numMotors);
	} else if (motorStr == "falcon500FOC") {
		return wpi::math::DCMotor::Falcon500FOC(numMotors);
	} else if (motorStr == "vortex") {
		return wpi::math::DCMotor::NeoVortex(numMotors);
	} else if (motorStr == "NEO") {
		return wpi::math::DCMotor::NEO(numMotors);
	} else if (motorStr == "CIM") {
		return wpi::math::DCMotor::CIM(numMotors);
	} else if (motorStr == "miniCIM") {
		return wpi::math::DCMotor::MiniCIM(numMotors);
	} else {
		throw std::invalid_argument("Unknown motor type string: " + motorStr);
	}
}

std::vector<wpi::math::SwerveModuleVelocity> RobotConfig::toSwerveModuleVelocitys(
		wpi::math::ChassisVelocities speeds) const {
	if (isHolonomic) {
		auto states = swerveKinematics.ToWheelVelocities(speeds);
		return std::vector < wpi::math::SwerveModuleVelocity
				> (states.begin(), states.end());
	} else {
		auto wheelSpeeds = diffKinematics.ToWheelVelocities(speeds);
		return std::vector<wpi::math::SwerveModuleVelocity> {
				wpi::math::SwerveModuleVelocity { wheelSpeeds.left,
						wpi::math::Rotation2d() },
				wpi::math::SwerveModuleVelocity { wheelSpeeds.right,
						wpi::math::Rotation2d() } };
	}
}

wpi::math::ChassisVelocities RobotConfig::toChassisVelocities(
		std::vector<SwerveModuleTrajectoryState> states) const {
	if (isHolonomic) {
		wpi::util::array < wpi::math::SwerveModuleVelocity, 4
				> wpiStates { wpi::math::SwerveModuleVelocity { states[0].speed,
						states[0].angle }, wpi::math::SwerveModuleVelocity {
						states[1].speed, states[1].angle },
						wpi::math::SwerveModuleVelocity { states[2].speed,
								states[2].angle },
						wpi::math::SwerveModuleVelocity { states[3].speed,
								states[3].angle } };
		return swerveKinematics.ToChassisVelocities(wpiStates);
	} else {
		wpi::math::DifferentialDriveWheelVelocities wheelSpeeds {
				states[0].speed, states[1].speed };
		return diffKinematics.ToChassisVelocities(wheelSpeeds);
	}
}

wpi::math::ChassisVelocities RobotConfig::toChassisVelocities(
		std::vector<wpi::math::SwerveModuleVelocity> states) const {
	if (isHolonomic) {
		wpi::util::array < wpi::math::SwerveModuleVelocity, 4 > wpiStates {
				states.at(0), states.at(1), states.at(2), states.at(3) };
		return swerveKinematics.ToChassisVelocities(wpiStates);
	} else {
		wpi::math::DifferentialDriveWheelVelocities wheelSpeeds {
				states.at(0).velocity, states.at(1).velocity };
		return diffKinematics.ToChassisVelocities(wheelSpeeds);
	}
}

std::vector<wpi::math::SwerveModuleVelocity> RobotConfig::desaturateWheelSpeeds(
		std::vector<wpi::math::SwerveModuleVelocity> moduleStates,
		wpi::units::meters_per_second_t maxSpeed) const {
	wpi::util::array < wpi::math::SwerveModuleVelocity, 4 > wpiStates {
			moduleStates.at(0), moduleStates.at(1), moduleStates.at(2),
			moduleStates.at(3) };
	wpiStates = wpi::math::SwerveDriveKinematics < 4
			> ::DesaturateWheelVelocities(wpiStates, maxSpeed);

	return std::vector < wpi::math::SwerveModuleVelocity
			> (wpiStates.begin(), wpiStates.end());
}

std::vector<wpi::math::Translation2d> RobotConfig::chassisForcesToWheelForceVectors(
		wpi::math::ChassisVelocities chassisForces) const {
	Eigen::Vector3d chassisForceVector { chassisForces.vx.value(),
			chassisForces.vy.value(), chassisForces.omega.value() };
	std::vector < wpi::math::Translation2d > forceVectors;

	if (isHolonomic) {
		wpi::math::Matrixd < 4 * 2, 1 > moduleForceMatrix =
				swerveForceKinematics * (chassisForceVector / numModules);
		for (size_t i = 0; i < numModules; i++) {
			wpi::units::meter_t x { moduleForceMatrix(i * 2, 0) };
			wpi::units::meter_t y { moduleForceMatrix(i * 2 + 1, 0) };

			forceVectors.emplace_back(x, y);
		}
	} else {
		wpi::math::Matrixd < 2 * 2, 1 > moduleForceMatrix = diffForceKinematics
				* (chassisForceVector / numModules);
		for (size_t i = 0; i < numModules; i++) {
			wpi::units::meter_t x { moduleForceMatrix(i * 2, 0) };
			wpi::units::meter_t y { moduleForceMatrix(i * 2 + 1, 0) };

			forceVectors.emplace_back(x, y);
		}
	}

	return forceVectors;
}
