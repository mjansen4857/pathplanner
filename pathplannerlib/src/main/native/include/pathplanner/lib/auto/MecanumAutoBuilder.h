#pragma once

#include <frc/kinematics/MecanumDriveKinematics.h>
#include <frc/kinematics/MecanumDriveWheelSpeeds.h>
#include <frc/kinematics/ChassisSpeeds.h>
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
	 * @param translationConstants PID Constants for the controller that will correct for translation
	 *     error
	 * @param rotationConstants PID Constants for the controller that will correct for rotation error
	 * @param output The output of the position PIDs.
	 * @param eventMap Map of event marker names to the commands that should run when reaching that
	 *     marker.
	 * @param driveRequirements The subsystems that the path following commands should require.
	 *     Usually just a Drive subsystem.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	MecanumAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			std::function<void(frc::ChassisSpeeds)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements,
			bool useAllianceColor = false);

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
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	MecanumAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::MecanumDriveKinematics kinematics,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			units::meters_per_second_t maxWheelVelocity,
			std::function<void(frc::MecanumDriveWheelSpeeds)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements,
			bool useAllianceColor = false);

	frc2::CommandPtr followPath(PathPlannerTrajectory trajectory) override;

private:
	frc::MecanumDriveKinematics m_kinematics;
	PIDConstants m_translationConstants;
	PIDConstants m_rotationConstants;
	const units::meters_per_second_t m_maxWheelVelocity;
	std::function<void(frc::MecanumDriveWheelSpeeds)> m_outputVel;
	std::function<void(frc::ChassisSpeeds)> m_outputChassisSpeeds;
	std::initializer_list<frc2::Subsystem*> m_driveRequirements;

	const bool m_useKinematics;
};
}
