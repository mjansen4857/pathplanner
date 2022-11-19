#include <frc/controller/PIDController.h>
#include <frc/geometry/Pose2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Translation2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include "pathplanner/lib/PathPlannerTrajectory.h"

namespace pathplanner {
class PPHolonomicDriveController {
public:
	/**
	 * Constructs a PPHolonomicDriveController
	 *
	 * @param xController A PID controller to respond to error in the field-relative X direction
	 * @param yController A PID controller to respond to error in the field-relative Y direction
	 * @param rotationController A PID controller to respond to error in rotation
	 */
	PPHolonomicDriveController(frc2::PIDController xController,
			frc2::PIDController yController,
			frc2::PIDController rotationController);

	/**
	 * Returns true if the pose error is within tolerance of the reference.
	 *
	 * @return True if the pose error is within tolerance of the reference.
	 */
	bool atReference() const;

	/**
	 * Sets the pose error whic is considered tolerance for use with atReference()
	 *
	 * @param tolerance The pose error which is tolerable
	 */
	void setTolerance(frc::Pose2d const tolerance);

	/**
	 * Enables and disables the controller for troubleshooting. When calculate() is called on a disabled
	 * controller, only feedforward values are returned.
	 *
	 * @param enabled If the controller is enabled or not
	 */
	void setEnabled(bool enabled);

	/**
	 * Calculates the next output of the holonomic drive controller
	 *
	 * @param currentPose The current pose
	 * @param referenceState The desired trajectory state
	 * @return The next output of the holonomic drive controller
	 */
	frc::ChassisSpeeds calculate(frc::Pose2d const currentPose,
			PathPlannerTrajectory::PathPlannerState const &referenceState);

private:
	frc2::PIDController m_xController;
	frc2::PIDController m_yController;
	frc2::PIDController m_rotationController;

	frc::Translation2d m_translationError;
	frc::Rotation2d m_rotationError;
	frc::Pose2d m_tolerance;
	bool m_isEnabled = true;
};
}
