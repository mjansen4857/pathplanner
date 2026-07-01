#pragma once

#include <wpi/math/controller/PIDController.hpp>
#include <wpi/math/controller/ProfiledPIDController.hpp>
#include <wpi/units/velocity.hpp>
#include <wpi/units/length.hpp>
#include <wpi/units/time.hpp>
#include <wpi/units/angular_velocity.hpp>
#include <wpi/math/geometry/Translation2d.hpp>
#include <wpi/math/geometry/Rotation2d.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/math/kinematics/ChassisVelocities.hpp>
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
			PIDConstants rotationConstants,
			wpi::units::second_t period = 0.02_s);

	/**
	 * Enables and disables the controller for troubleshooting. When calculate() is called on a
	 * disabled controller, only feedforward values are returned.
	 *
	 * @param enabled If the controller is enabled or not
	 */
	constexpr void setEnabled(bool enabled) {
		m_enabled = enabled;
	}

	inline void reset(const wpi::math::Pose2d &currentPose,
			const wpi::math::ChassisVelocities &currentSpeeds) override {
		m_xController.Reset();
		m_yController.Reset();
		m_rotationController.Reset();
	}

	/**
	 * Get the last positional error of the controller
	 *
	 * @return Positional error, in meters
	 */
	inline wpi::units::meter_t getPositionalError() override {
		return m_translationError.Norm();
	}

	/**
	 * Calculates the next output of the holonomic drive controller
	 *
	 * @param currentPose The current pose
	 * @param referenceState The desired trajectory state
	 * @return The next output of the holonomic drive controller (robot relative)
	 */
	wpi::math::ChassisVelocities calculateRobotRelativeSpeeds(
			const wpi::math::Pose2d &currentPose,
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
			std::function<std::optional<wpi::math::Rotation2d>()> rotationTargetOverride) {
		PPHolonomicDriveController::rotationTargetOverride =
				rotationTargetOverride;
	}

	/**
	 * Begin overriding the X axis feedback.
	 *
	 * @param xFeedbackOverride Function that returns the desired FIELD-RELATIVE X feedback in meters/sec
	 */
	static inline void overrideXFeedback(
			std::function<wpi::units::meters_per_second_t()> xFeedbackOverride) {
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
			std::function<wpi::units::meters_per_second_t()> yFeedbackOverride) {
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
			std::function<wpi::units::meters_per_second_t()> xFeedbackOverride,
			std::function<wpi::units::meters_per_second_t()> yFeedbackOverride) {
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
			std::function<wpi::units::radians_per_second_t()> rotationFeedbackOverride) {
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
	wpi::math::PIDController m_xController;
	wpi::math::PIDController m_yController;
	wpi::math::PIDController m_rotationController;

	wpi::math::Translation2d m_translationError;
	bool m_enabled = true;

	static std::function<std::optional<wpi::math::Rotation2d>()> rotationTargetOverride;

	static std::function<wpi::units::meters_per_second_t()> xFeedbackOverride;
	static std::function<wpi::units::meters_per_second_t()> yFeedbackOverride;
	static std::function<wpi::units::radians_per_second_t()> rotationFeedbackOverride;
};
}
