#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"

using namespace pathplanner;

std::function<std::optional<frc::Rotation2d>()> PPHolonomicDriveController::rotationTargetOverride;

PPHolonomicDriveController::PPHolonomicDriveController(
		PIDConstants translationConstants, PIDConstants rotationConstants,
		units::meters_per_second_t maxModuleSpeed,
		units::meter_t driveBaseRadius, units::second_t period) : m_xController(
		translationConstants.kP, translationConstants.kI,
		translationConstants.kD, period), m_yController(translationConstants.kP,
		translationConstants.kI, translationConstants.kD, period), m_rotationController(
		rotationConstants.kP, rotationConstants.kI, rotationConstants.kD, {
				0_rad_per_s, 0_rad_per_s_sq }, period), m_maxModuleSpeed(
		maxModuleSpeed), m_mpsToRps { 1.0 / driveBaseRadius() } {
	m_xController.SetIntegratorRange(-translationConstants.iZone,
			translationConstants.iZone);
	m_yController.SetIntegratorRange(-translationConstants.iZone,
			translationConstants.iZone);

	m_rotationController.SetIntegratorRange(-rotationConstants.iZone,
			rotationConstants.iZone);
	m_rotationController.EnableContinuousInput(units::radian_t { -PI },
			units::radian_t { PI });
}

frc::ChassisSpeeds PPHolonomicDriveController::calculateRobotRelativeSpeeds(
		const frc::Pose2d &currentPose,
		const PathPlannerTrajectory::State &referenceState) {
	units::meters_per_second_t xFF = referenceState.velocity
			* referenceState.heading.Cos();
	units::meters_per_second_t yFF = referenceState.velocity
			* referenceState.heading.Sin();

	m_translationError = currentPose.Translation() - referenceState.position;

	if (!m_enabled) {
		return frc::ChassisSpeeds::FromFieldRelativeSpeeds(xFF, yFF,
				0_rad_per_s, currentPose.Rotation());
	}

	units::meters_per_second_t xFeedback { m_xController.Calculate(
			currentPose.X()(), referenceState.position.X()()) };
	units::meters_per_second_t yFeedback { m_yController.Calculate(
			currentPose.Y()(), referenceState.position.Y()()) };

	units::radians_per_second_t angVelConstraint =
			referenceState.constraints.getMaxAngularVelocity();
	units::radians_per_second_t maxAngVel = angVelConstraint;
	if (std::isfinite(maxAngVel())) {
		// Approximation of available module speed to do rotation with
		units::radians_per_second_t maxAngVelModule = units::math::max(
				0_rad_per_s,
				(m_maxModuleSpeed - referenceState.velocity) * m_mpsToRps);
		maxAngVel = units::math::min(angVelConstraint, maxAngVelModule);
	}

	frc::Rotation2d targetRotation = referenceState.targetHolonomicRotation;
	if (rotationTargetOverride) {
		targetRotation = rotationTargetOverride().value_or(targetRotation);
	}

	units::radians_per_second_t rotationFeedback {
			m_rotationController.Calculate(currentPose.Rotation().Radians(),
					referenceState.targetHolonomicRotation.Radians(),
					{ maxAngVel,
							referenceState.constraints.getMaxAngularAcceleration() }) };
	units::radians_per_second_t rotationFF =
			referenceState.holonomicAngularVelocityRps.value_or(
					m_rotationController.GetSetpoint().velocity);

	return frc::ChassisSpeeds::FromFieldRelativeSpeeds(xFF + xFeedback,
			yFF + yFeedback, rotationFF + rotationFeedback,
			currentPose.Rotation());
}
