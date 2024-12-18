#pragma once

#include <units/mass.h>
#include <units/length.h>
#include <units/force.h>
#include <units/torque.h>
#include <units/moment_of_inertia.h>
#include <frc/geometry/Translation2d.h>
#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/kinematics/DifferentialDriveKinematics.h>
#include <frc/EigenCore.h>
#include <vector>
#include "pathplanner/lib/config/ModuleConfig.h"
#include "pathplanner/lib/trajectory/SwerveModuleTrajectoryState.h"

namespace pathplanner {
class RobotConfig {
public:
	units::kilogram_t mass;
	units::kilogram_square_meter_t MOI;
	ModuleConfig moduleConfig;

	std::vector<frc::Translation2d> moduleLocations;
	bool isHolonomic;

	size_t numModules;
	std::vector<units::meter_t> modulePivotDistance;
	units::newton_t wheelFrictionForce;
	units::newton_meter_t maxTorqueFriction;

	RobotConfig();

	RobotConfig(units::kilogram_t mass, units::kilogram_square_meter_t MOI,
			ModuleConfig moduleConfig,
			std::vector<frc::Translation2d> moduleOffsets);

	RobotConfig(units::kilogram_t mass, units::kilogram_square_meter_t MOI,
			ModuleConfig moduleConfig, units::meter_t trackwidth);

	static RobotConfig fromGUISettings();

	/**
	 * Convert robot-relative chassis speeds to a vector of swerve module states. This will use
	 * differential kinematics for diff drive robots, then convert the wheel speeds to module states.
	 *
	 * @param speeds Robot-relative chassis speeds
	 * @return Vector of swerve module states
	 */
	std::vector<frc::SwerveModuleState> toSwerveModuleStates(
			frc::ChassisSpeeds speeds) const;

	/**
	 * Convert a vector of swerve module states to robot-relative chassis speeds. This will use
	 * differential kinematics for diff drive robots.
	 *
	 * @param states Vector of swerve module states
	 * @return Robot-relative chassis speeds
	 */
	frc::ChassisSpeeds toChassisSpeeds(
			std::vector<SwerveModuleTrajectoryState> states) const;

	/**
	 * Convert a vector of swerve module states to robot-relative chassis speeds. This will use
	 * differential kinematics for diff drive robots.
	 * 
	 * @param states Vector of swerve module states
	 * @return Robot-relative chassis speeds
	 */
	frc::ChassisSpeeds toChassisSpeeds(
			std::vector<frc::SwerveModuleState> states) const;

	/**
	 * Desaturate wheel speeds to respect velocity limits.
	 * 
	 * @param moduleStates The module states to desaturate
	 * @param maxSpeed The maximum speed that the robot can reach while actually driving the robot at full output
	 * @return The desaturated module states
	 */
	std::vector<frc::SwerveModuleState> desaturateWheelSpeeds(
			std::vector<frc::SwerveModuleState> moduleStates,
			units::meters_per_second_t maxSpeed) const;

	std::vector<frc::Translation2d> chassisForcesToWheelForceVectors(
			frc::ChassisSpeeds chassisForces) const;

private:
	frc::SwerveDriveKinematics<4> swerveKinematics;
	frc::DifferentialDriveKinematics diffKinematics;
	frc::Matrixd<4 * 2, 3> swerveForceKinematics;
	frc::Matrixd<2 * 2, 3> diffForceKinematics;

	static frc::DCMotor getMotorFromSettingsString(std::string motorStr,
			int numMotors);
};
}
