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
#include <functional>
#include <optional>
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/config/PIDConstants.h"
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include "pathplanner/lib/controllers/PathFollowingController.h"

namespace pathplanner {
class PPHolonomicDriveController: public PathFollowingController {
public:
	/**
	 * Constructs a PPHolonomicDriveController
	 *
	 * @param translationConstants PID constants for the translation PID controllers
	 * @param rotationConstants PID constants for the rotation controller
	 * @param period Period of the control loop in seconds
	 */
	PPHolonomicDriveController(PIDConstants translationConstants,
			PIDConstants rotationConstants, units::second_t period = 0.02_s);

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
			const frc::ChassisSpeeds &currentSpeeds) override {
		m_xController.Reset();
		m_yController.Reset();
		m_rotationController.Reset();
	}

	/**
	 * Get the last positional error of the controller
	 *
	 * @return Positional error, in meters
	 */
	inline units::meter_t getPositionalError() override {
		return m_translationError.Norm();
	}

	/**
	 * Calculates the next output of the holonomic drive controller
	 *
	 * @param currentPose The current pose
	 * @param referenceState The desired trajectory state
	 * @return The next output of the holonomic drive controller (robot relative)
	 */
	frc::ChassisSpeeds calculateRobotRelativeSpeeds(
			const frc::Pose2d &currentPose,
			const PathPlannerTrajectoryState &referenceState) override;

	/**
	 * Is this controller for holonomic drivetrains? Used to handle some differences in functionality
	 * in the path following command.
	 *
	 * @return True if this controller is for a holonomic drive train
	 */
	inline bool isHolonomic() override {
		return true;
	}

	/**
	 * Set a supplier that will be used to override the rotation target when path following.
	 * <p>
	 * This function should return an empty optional to use the rotation targets in the path
	 * @param rotationTargetOverride Supplier to override rotation targets
	 */
	[[deprecated("Use overrideRotationFeedback instead, with the output of your own PID controller")]]
	static inline void setRotationTargetOverride(
			std::function<std::optional<frc::Rotation2d>()> rotationTargetOverride) {
		PPHolonomicDriveController::rotationTargetOverride =
				rotationTargetOverride;
	}

	/**
	 * Begin overriding the X axis feedback.
	 *
	 * @param xFeedbackOverride Function that returns the desired FIELD-RELATIVE X feedback in meters/sec
	 */
	static inline void overrideXFeedback(
			std::function<units::meters_per_second_t()> xFeedbackOverride) {
		PPHolonomicDriveController::xFeedbackOverride = xFeedbackOverride;
	}

	/**
	 * Stop overriding the X axis feedback, and return to calculating it based on path following
	 * error.
	 */
	static inline void clearXFeedbackOverride() {
		PPHolonomicDriveController::xFeedbackOverride = { };
	}

	/**
	 * Begin overriding the Y axis feedback.
	 *
	 * @param yFeedbackOverride Function that returns the desired FIELD-RELATIVE Y feedback in meters/sec
	 */
	static inline void overrideYFeedback(
			std::function<units::meters_per_second_t()> yFeedbackOverride) {
		PPHolonomicDriveController::yFeedbackOverride = yFeedbackOverride;
	}

	/**
	 * Stop overriding the Y axis feedback, and return to calculating it based on path following
	 * error.
	 */
	static inline void clearYFeedbackOverride() {
		PPHolonomicDriveController::yFeedbackOverride = { };
	}

	/**
	 * Begin overriding the X and Y axis feedback.
	 *
	 * @param xFeedbackOverride Function that returns the desired FIELD-RELATIVE X feedback in meters/sec
	 * @param yFeedbackOverride Function that returns the desired FIELD-RELATIVE Y feedback in meters/sec
	 */
	static inline void overrideXYFeedback(
			std::function<units::meters_per_second_t()> xFeedbackOverride,
			std::function<units::meters_per_second_t()> yFeedbackOverride) {
		overrideXFeedback(xFeedbackOverride);
		overrideYFeedback(yFeedbackOverride);
	}

	/**
	 * Stop overriding the X and Y axis feedback, and return to calculating them based on path
	 * following error.
	 */
	static inline void clearXYFeedbackOverride() {
		clearXFeedbackOverride();
		clearYFeedbackOverride();
	}

	/**
	 * Begin overriding the rotation feedback.
	 *
	 * @param rotationFeedbackOverride Function that returns the desired rotation feedback in radians/sec
	 */
	static inline void overrideRotationFeedback(
			std::function<units::radians_per_second_t()> rotationFeedbackOverride) {
		PPHolonomicDriveController::rotationFeedbackOverride =
				rotationFeedbackOverride;
	}

	/**
	 * Stop overriding the rotation feedback, and return to calculating it based on path following
	 * error.
	 */
	static inline void clearRotationFeedbackOverride() {
		PPHolonomicDriveController::rotationFeedbackOverride = { };
	}

	/** Clear all feedback overrides and return to purely using path following error for feedback */
	static inline void clearFeedbackOverrides() {
		clearXYFeedbackOverride();
		clearRotationFeedbackOverride();
	}

private:
	frc::PIDController m_xController;
	frc::PIDController m_yController;
	frc::PIDController m_rotationController;

	frc::Translation2d m_translationError;
	bool m_enabled = true;

	static std::function<std::optional<frc::Rotation2d>()> rotationTargetOverride;

	static std::function<units::meters_per_second_t()> xFeedbackOverride;
	static std::function<units::meters_per_second_t()> yFeedbackOverride;
	static std::function<units::radians_per_second_t()> rotationFeedbackOverride;
};
}
