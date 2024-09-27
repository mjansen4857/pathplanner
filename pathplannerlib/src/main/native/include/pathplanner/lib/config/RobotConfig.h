#pragma once

#include <units/mass.h>
#include <units/length.h>
#include <units/force.h>
#include <units/torque.h>
#include <units/moment_of_inertia.h>
#include <frc/geometry/Translation2d.h>
#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/kinematics/DifferentialDriveKinematics.h>
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

	// Need two different kinematics objects since the class is templated but having
	// RobotConfig also templated would be pretty bad to work with
	frc::SwerveDriveKinematics<4> swerveKinematics;
	frc::DifferentialDriveKinematics diffKinematics;
	bool isHolonomic;

	size_t numModules;
	std::vector<units::meter_t> modulePivotDistance;
	units::newton_t wheelFrictionForce;
	units::newton_meter_t maxTorqueFriction;

	RobotConfig(units::kilogram_t mass, units::kilogram_square_meter_t MOI,
			ModuleConfig moduleConfig, units::meter_t trackwidth,
			units::meter_t wheelbase);

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
	inline std::vector<frc::SwerveModuleState> toSwerveModuleStates(
			frc::ChassisSpeeds speeds) const {
		if (isHolonomic) {
			auto states = swerveKinematics.ToSwerveModuleStates(speeds);
			return std::vector < frc::SwerveModuleState
					> (states.begin(), states.end());
		} else {
			auto wheelSpeeds = diffKinematics.ToWheelSpeeds(speeds);
			return std::vector<frc::SwerveModuleState> {
					frc::SwerveModuleState { wheelSpeeds.left, frc::Rotation2d() },
					frc::SwerveModuleState { wheelSpeeds.right,
							frc::Rotation2d() } };
		}
	}

	/**
	 * Convert a vector of swerve module states to robot-relative chassis speeds. This will use
	 * differential kinematics for diff drive robots.
	 *
	 * @param states Vector of swerve module states
	 * @return Robot-relative chassis speeds
	 */
	inline frc::ChassisSpeeds toChassisSpeeds(
			std::vector<SwerveModuleTrajectoryState> states) const {
		if (isHolonomic) {
			wpi::array < frc::SwerveModuleState, 4
					> wpiStates { frc::SwerveModuleState { states[0].speed,
							states[0].angle }, frc::SwerveModuleState {
							states[1].speed, states[1].angle },
							frc::SwerveModuleState { states[2].speed,
									states[2].angle }, frc::SwerveModuleState {
									states[3].speed, states[3].angle } };
			return swerveKinematics.ToChassisSpeeds(wpiStates);
		} else {
			frc::DifferentialDriveWheelSpeeds wheelSpeeds { states[0].speed,
					states[1].speed };
			return diffKinematics.ToChassisSpeeds(wheelSpeeds);
		}
	}

private:
	static frc::DCMotor getMotorFromSettingsString(std::string motorStr,
			int numMotors);
};
}
