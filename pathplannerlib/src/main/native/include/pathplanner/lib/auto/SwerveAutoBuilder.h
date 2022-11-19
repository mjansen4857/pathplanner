#pragma once

#include "pathplanner/lib/auto/BaseAutoBuilder.h"
#include "pathplanner/lib/auto/PIDConstants.h"

#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/kinematics/SwerveModuleState.h>

namespace pathplanner {
class SwerveAutoBuilder: public BaseAutoBuilder {
public:
	/**
	 * Create an auto builder that will create command groups that will handle path following and
	 * triggering events.
	 *
	 * <p>This auto builder will use PPSwerveControllerCommand to follow paths.
	 *
	 * @param pose A function that supplies the robot pose - use one of the odometry classes
	 *     to provide this.
	 * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
	 *     be called once at the beginning of an auto.
	 * @param kinematics The kinematics for the robot drivetrain.
	 * @param translationConstants PID Constants for the controller that will correct for translation
	 *     error
	 * @param rotationConstants PID Constants for the controller that will correct for rotation error
	 * @param output A function that takes raw output module states from path following
	 *     commands
	 * @param eventMap Map of event marker names to the commands that should run when reaching that
	 *     marker.
	 * @param driveRequirements The subsystems that the path following commands should require.
	 *     Usually just a Drive subsystem.
	 */
	SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::SwerveDriveKinematics<4> kinematics,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements);

	/**
	 * Create an auto builder that will create command groups that will handle path following and
	 * triggering events.
	 *
	 * <p>This auto builder will use PPSwerveControllerCommand to follow paths.
	 *
	 * @param pose A function that supplies the robot pose - use one of the odometry classes
	 *     to provide this.
	 * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
	 *     be called once at the beginning of an auto.
	 * @param kinematics The kinematics for the robot drivetrain.
	 * @param translationConstants PID Constants for the controller that will correct for translation
	 *     error
	 * @param rotationConstants PID Constants for the controller that will correct for rotation error
	 * @param output A function that takes raw output module states from path following
	 *     commands
	 * @param eventMap Map of event marker names to the commands that should run when reaching that
	 *     marker.
	 * @param driveRequirements The subsystems that the path following commands should require.
	 *     Usually just a Drive subsystem.
	 */
	SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::SwerveDriveKinematics<4> kinematics,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::span<frc2::Subsystem* const > driveRequirements = { });

	frc2::CommandPtr followPath(PathPlannerTrajectory trajectory) override;

private:
	frc::SwerveDriveKinematics<4> m_kinematics;
	PIDConstants m_translationConstants;
	PIDConstants m_rotationConstants;
	std::function<void(std::array<frc::SwerveModuleState, 4>)> m_output;
	wpi::SmallSet<frc2::Subsystem*, 4> m_driveRequirements;
};
}
