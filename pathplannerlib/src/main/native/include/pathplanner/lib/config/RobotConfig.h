#pragma once

#include <wpi/units/mass.hpp>
#include <wpi/units/length.hpp>
#include <wpi/units/force.hpp>
#include <wpi/units/torque.hpp>
#include <wpi/units/moment_of_inertia.hpp>
#include <wpi/math/geometry/Translation2d.hpp>
#include <wpi/math/kinematics/SwerveDriveKinematics.hpp>
#include <wpi/math/kinematics/DifferentialDriveKinematics.hpp>
#include <wpi/math/linalg/EigenCore.hpp>
#include <vector>
#include "pathplanner/lib/config/ModuleConfig.h"
#include "pathplanner/lib/trajectory/SwerveModuleTrajectoryState.h"

namespace pathplanner {
class RobotConfig {
public:
	wpi::units::kilogram_t mass;
	wpi::units::kilogram_square_meter_t MOI;
	ModuleConfig moduleConfig;

	std::vector<wpi::math::Translation2d> moduleLocations;
	bool isHolonomic;

	size_t numModules;
	std::vector<wpi::units::meter_t> modulePivotDistance;
	wpi::units::newton_t wheelFrictionForce;
	wpi::units::newton_meter_t maxTorqueFriction;

	RobotConfig();

	RobotConfig(wpi::units::kilogram_t mass,
			wpi::units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
			std::vector<wpi::math::Translation2d> moduleOffsets);

	RobotConfig(wpi::units::kilogram_t mass,
			wpi::units::kilogram_square_meter_t MOI, ModuleConfig moduleConfig,
			wpi::units::meter_t trackwidth);

	static RobotConfig fromGUISettings();

	/**
	 * Convert robot-relative chassis speeds to a vector of swerve module states. This will use
	 * differential kinematics for diff drive robots, then convert the wheel speeds to module states.
	 *
	 * @param speeds Robot-relative chassis speeds
	 * @return Vector of swerve module states
	 */
	std::vector<wpi::math::SwerveModuleVelocity> toSwerveModuleVelocitys(
			wpi::math::ChassisVelocities speeds) const;

	/**
	 * Convert a vector of swerve module states to robot-relative chassis speeds. This will use
	 * differential kinematics for diff drive robots.
	 *
	 * @param states Vector of swerve module states
	 * @return Robot-relative chassis speeds
	 */
	wpi::math::ChassisVelocities toChassisVelocities(
			std::vector<SwerveModuleTrajectoryState> states) const;

	/**
	 * Convert a vector of swerve module states to robot-relative chassis speeds. This will use
	 * differential kinematics for diff drive robots.
	 * 
	 * @param states Vector of swerve module states
	 * @return Robot-relative chassis speeds
	 */
	wpi::math::ChassisVelocities toChassisVelocities(
			std::vector<wpi::math::SwerveModuleVelocity> states) const;

	/**
	 * Desaturate wheel speeds to respect velocity limits.
	 * 
	 * @param moduleStates The module states to desaturate
	 * @param maxSpeed The maximum speed that the robot can reach while actually driving the robot at full output
	 * @return The desaturated module states
	 */
	std::vector<wpi::math::SwerveModuleVelocity> desaturateWheelSpeeds(
			std::vector<wpi::math::SwerveModuleVelocity> moduleStates,
			wpi::units::meters_per_second_t maxSpeed) const;

	std::vector<wpi::math::Translation2d> chassisForcesToWheelForceVectors(
			wpi::math::ChassisVelocities chassisForces) const;

private:
	wpi::math::SwerveDriveKinematics<4> swerveKinematics;
	wpi::math::DifferentialDriveKinematics diffKinematics;
	wpi::math::Matrixd<4 * 2, 3> swerveForceKinematics;
	wpi::math::Matrixd<2 * 2, 3> diffForceKinematics;

	static wpi::math::DCMotor getMotorFromSettingsString(std::string motorStr,
			int numMotors);
};
}
