#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"
#include <units/velocity.h>
#include <units/angular_velocity.h>
#include <utility>

using namespace pathplanner;

PPHolonomicDriveController::PPHolonomicDriveController(
		frc2::PIDController xController, frc2::PIDController yController,
		frc2::PIDController rotationController) : m_xController(xController), m_yController(
		yController), m_rotationController(rotationController) {
	this->m_rotationController.EnableContinuousInput(-PI, PI);
}

bool PPHolonomicDriveController::atReference() const {
	frc::Translation2d translationTolerance = this->m_tolerance.Translation();
	frc::Rotation2d rotationTolerance = this->m_tolerance.Rotation();

	return units::math::abs(this->m_translationError.X())
			< translationTolerance.X()
			&& units::math::abs(this->m_translationError.Y())
					< translationTolerance.Y()
			&& units::math::abs(this->m_rotationError.Radians())
					< rotationTolerance.Radians();
}

void PPHolonomicDriveController::setTolerance(frc::Pose2d const tolerance) {
	this->m_tolerance = tolerance;
}

void PPHolonomicDriveController::setEnabled(bool enabled) {
	this->m_isEnabled = enabled;
}

frc::ChassisSpeeds PPHolonomicDriveController::calculate(
		frc::Pose2d const currentPose,
		PathPlannerTrajectory::PathPlannerState const &referenceState) {
	units::meters_per_second_t xFF = referenceState.velocity
			* referenceState.pose.Rotation().Cos();
	units::meters_per_second_t yFF = referenceState.velocity
			* referenceState.pose.Rotation().Sin();
	units::radians_per_second_t rotationFF =
			referenceState.holonomicAngularVelocity;

	this->m_translationError =
			referenceState.pose.RelativeTo(currentPose).Translation();
	this->m_rotationError = referenceState.holonomicRotation
			- currentPose.Rotation();

	if (!this->m_isEnabled) {
		return frc::ChassisSpeeds::FromFieldRelativeSpeeds(xFF, yFF, rotationFF,
				currentPose.Rotation());
	}

	units::meters_per_second_t xFeedback = units::meters_per_second_t(
			this->m_xController.Calculate(currentPose.X().value(),
					referenceState.pose.X().value()));
	units::meters_per_second_t yFeedback = units::meters_per_second_t(
			this->m_yController.Calculate(currentPose.Y().value(),
					referenceState.pose.Y().value()));
	units::radians_per_second_t rotationFeedback = units::radians_per_second_t(
			this->m_rotationController.Calculate(
					currentPose.Rotation().Radians().value(),
					referenceState.holonomicRotation.Radians().value()));

	return frc::ChassisSpeeds::FromFieldRelativeSpeeds(xFF + xFeedback,
			yFF + yFeedback, rotationFF + rotationFeedback,
			currentPose.Rotation());
}
