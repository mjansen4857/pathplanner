#pragma once

#include <frc/controller/PIDController.h>
#include <frc/controller/ProfiledPIDController.h>
#include <units/velocity.h>
#include <units/length.h>
#include <units/time.h>
#include <units/angular_velocity.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/util/PIDConstants.h"
#include "pathplanner/lib/util/HolonomicPathFollowerConfig.h"
#include "pathplanner/lib/path/PathPlannerTrajectory.h"

namespace pathplanner {
class HolonomicDriveController {
public:
	/**
	 * Constructs a HolonomicDriveController
	 *
	 * @param translationConstants PID constants for the translation PID controllers
	 * @param rotationConstants PID constants for the rotation controller
	 * @param maxModuleSpeed The max speed of a drive module in meters/sec
	 * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
	 *     distance from the center of the robot to the furthest module. For mecanum, this is the
	 *     drive base width / 2
	 * @param period Period of the control loop in seconds
	 */
	HolonomicDriveController(PIDConstants translationConstants,
			PIDConstants rotationConstants,
			units::meters_per_second_t maxModuleSpeed,
			units::meter_t driveBaseRadius, units::second_t period = 0.02_s);

	/**
	 * Enables and disables the controller for troubleshooting. When calculate() is called on a
	 * disabled controller, only feedforward values are returned.
	 *
	 * @param enabled If the controller is enabled or not
	 */
	constexpr void setEnabled(bool enabled) {
		m_enabled = enabled;
	}

	inline void reset(const frc::Pose2d &currentPose,
			const frc::ChassisSpeeds &currentSpeeds) {
		m_rotationController.Reset(currentPose.Rotation().Radians(),
				currentSpeeds.omega);
	}

	/**
	 * Get the last positional error of the controller
	 *
	 * @return Positional error, in meters
	 */
	inline units::meter_t getPositionalError() {
		return m_translationError.Norm();
	}

	/**
	 * Calculates the next output of the holonomic drive controller
	 *
	 * @param currentPose The current pose
	 * @param referenceState The desired trajectory state
	 * @return The next output of the holonomic drive controller (robot relative)
	 */
	frc::ChassisSpeeds calculate(frc::Pose2d currentPose,
			PathPlannerTrajectory::State referenceState);

private:
	using rpsPerMps_t = units::unit_t<units::compound_unit<units::radians_per_second, units::inverse<units::meters_per_second>>>;

	frc2::PIDController m_xController;
	frc2::PIDController m_yController;
	frc::ProfiledPIDController<units::radians> m_rotationController;
	units::meters_per_second_t m_maxModuleSpeed;
	rpsPerMps_t m_mpsToRps;

	frc::Translation2d m_translationError;
	bool m_enabled;
};
}
