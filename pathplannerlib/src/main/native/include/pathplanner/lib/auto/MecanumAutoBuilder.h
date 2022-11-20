#pragma once

#include <frc/kinematics/MecanumDriveKinematics.h>
#include <frc/kinematics/MecanumDriveWheelSpeeds.h>
#include <units/velocity.h>

#include "pathplanner/lib/auto/BaseAutoBuilder.h"
#include "pathplanner/lib/auto/PIDConstants.h"
#include "pathplanner/lib/commands/PPMecanumControllerCommand.h"

namespace pathplanner {
class MecanumAutoBuilder: public BaseAutoBuilder {
public:
	/**
	 * Create an auto builder that will create command groups that will handle path following and
	 * triggering events.
	 *
	 * <p>This auto builder will use PPMecanumControllerCommand to follow paths.
	 *
	 * @param pose A function that supplies the robot pose - use one of the odometry classes
	 *     to provide this.
	 * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
	 *     be called once at the beginning of an auto.
	 * @param kinematics The kinematics for the robot drivetrain.
	 * @param translationConstants PID Constants for the controller that will correct for translation
	 *     error
	 * @param rotationConstants PID Constants for the controller that will correct for rotation error
	 * @param maxWheelVelocity The maximum velocity of a drivetrain wheel.
	 * @param output The output of the position PIDs.
	 * @param eventMap Map of event marker names to the commands that should run when reaching that
	 *     marker.
	 * @param driveRequirements The subsystems that the path following commands should require.
	 *     Usually just a Drive subsystem.
	 */
	MecanumAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::MecanumDriveKinematics kinematics,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			units::meters_per_second_t maxWheelVelocity,
			std::function<
					void(units::meters_per_second_t, units::meters_per_second_t,
							units::meters_per_second_t,
							units::meters_per_second_t)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements);

	frc2::CommandPtr followPath(PathPlannerTrajectory trajectory) override;

private:
	frc::MecanumDriveKinematics m_kinematics;
	PIDConstants m_translationConstants;
	PIDConstants m_rotationConstants;
	const units::meters_per_second_t m_maxWheelVelocity;
	std::function<
			void(units::meters_per_second_t, units::meters_per_second_t,
					units::meters_per_second_t, units::meters_per_second_t)> m_outputVel;
	std::initializer_list<frc2::Subsystem*> m_driveRequirements;
};
}
