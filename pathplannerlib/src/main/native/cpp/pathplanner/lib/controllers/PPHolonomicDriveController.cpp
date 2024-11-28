#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"

using namespace pathplanner;

std::function<std::optional<frc::Rotation2d>()> PPHolonomicDriveController::rotationTargetOverride;
std::function<units::meters_per_second_t()> PPHolonomicDriveController::xFeedbackOverride;
std::function<units::meters_per_second_t()> PPHolonomicDriveController::yFeedbackOverride;
std::function<units::radians_per_second_t()> PPHolonomicDriveController::rotationFeedbackOverride;

PPHolonomicDriveController::PPHolonomicDriveController(
		PIDConstants translationConstants, PIDConstants rotationConstants,
		units::second_t period) : m_xController(translationConstants.kP,
		translationConstants.kI, translationConstants.kD, period), m_yController(
		translationConstants.kP, translationConstants.kI,
		translationConstants.kD, period), m_rotationController(
		rotationConstants.kP, rotationConstants.kI, rotationConstants.kD,
		period) {
	m_xController.SetIntegratorRange(-translationConstants.iZone,
			translationConstants.iZone);
	m_yController.SetIntegratorRange(-translationConstants.iZone,
			translationConstants.iZone);

	m_rotationController.SetIntegratorRange(-rotationConstants.iZone,
			rotationConstants.iZone);
	m_rotationController.EnableContinuousInput(-PI, PI);
}

frc::ChassisSpeeds PPHolonomicDriveController::calculateRobotRelativeSpeeds(
		const frc::Pose2d &currentPose,
		const PathPlannerTrajectoryState &referenceState) {
	units::meters_per_second_t xFF = referenceState.fieldSpeeds.vx;
	units::meters_per_second_t yFF = referenceState.fieldSpeeds.vy;

	m_translationError = currentPose.Translation()
			- referenceState.pose.Translation();

	if (!m_enabled) {
		return frc::ChassisSpeeds::FromFieldRelativeSpeeds(xFF, yFF,
				0_rad_per_s, currentPose.Rotation());
	}

	units::meters_per_second_t xFeedback { m_xController.Calculate(
			currentPose.X()(), referenceState.pose.X()()) };
	units::meters_per_second_t yFeedback { m_yController.Calculate(
			currentPose.Y()(), referenceState.pose.Y()()) };

	frc::Rotation2d targetRotation = referenceState.pose.Rotation();
	if (rotationTargetOverride) {
		targetRotation = rotationTargetOverride().value_or(targetRotation);
	}

	units::radians_per_second_t rotationFeedback {
			m_rotationController.Calculate(currentPose.Rotation().Radians()(),
					targetRotation.Radians()()) };
	units::radians_per_second_t rotationFF = referenceState.fieldSpeeds.omega;

	if (xFeedbackOverride) {
		xFeedback = xFeedbackOverride();
	}
	if (yFeedbackOverride) {
		yFeedback = yFeedbackOverride();
	}
	if (rotationFeedbackOverride) {
		rotationFeedback = rotationFeedbackOverride();
	}

	return frc::ChassisSpeeds::FromFieldRelativeSpeeds(xFF + xFeedback,
			yFF + yFeedback, rotationFF + rotationFeedback,
			currentPose.Rotation());
}
