#pragma once

#include <frc2/command/CommandBase.h>
#include <frc2/command/CommandHelper.h>
#include <frc/Timer.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/kinematics/SwerveModuleState.h>
#include <frc/smartdashboard/Field2d.h>
#include "pathplanner/lib/PathPlannerTrajectory.h"
#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"
#include <span>

namespace pathplanner {
class PPSwerveControllerCommand: public frc2::CommandHelper<frc2::CommandBase,
		PPSwerveControllerCommand> {
public:
	/**
	 * @brief Constructs a new PPSwerveControllerCommand that when executed will follow the
	 * provided trajectory.
	 *
	 * @param trajectory         The trajectory to follow.
	 * @param pose               A function that returns the robot pose - use one of the odometry classes to provide this.
	 * @param kinematics         The kinematics for the robot drivetrain.
	 * @param xController        The Trajectory Tracker PID controller for the robot's x position.
	 * @param yController        The Trajectory Tracker PID controller for the robot's y position.
	 * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
	 * @param output             The raw output module states from the position controllers.
	 * @param requirements       The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPSwerveControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose, frc2::PIDController xController,
			frc2::PIDController yController,
			frc2::PIDController rotationController,
			std::function<void(frc::ChassisSpeeds)> output,
			std::initializer_list<frc2::Subsystem*> requirements,
			bool useAllianceColor = false);

	/**
	 * @brief Constructs a new PPSwerveControllerCommand that when executed will follow the
	 * provided trajectory.
	 *
	 * @param trajectory         The trajectory to follow.
	 * @param pose               A function that returns the robot pose - use one of the odometry classes to provide this.
	 * @param kinematics         The kinematics for the robot drivetrain.
	 * @param xController        The Trajectory Tracker PID controller for the robot's x position.
	 * @param yController        The Trajectory Tracker PID controller for the robot's y position.
	 * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
	 * @param output             The raw output module states from the position controllers.
	 * @param requirements       The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPSwerveControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose, frc2::PIDController xController,
			frc2::PIDController yController,
			frc2::PIDController rotationController,
			std::function<void(frc::ChassisSpeeds)> output,
			std::span<frc2::Subsystem* const > requirements = { },
			bool useAllianceColor = false);

	/**
	 * @brief Constructs a new PPSwerveControllerCommand that when executed will follow the
	 * provided trajectory.
	 *
	 * @param trajectory         The trajectory to follow.
	 * @param pose               A function that returns the robot pose - use one of the odometry classes to provide this.
	 * @param kinematics         The kinematics for the robot drivetrain.
	 * @param xController        The Trajectory Tracker PID controller for the robot's x position.
	 * @param yController        The Trajectory Tracker PID controller for the robot's y position.
	 * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
	 * @param output             The raw output module states from the position controllers.
	 * @param requirements       The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPSwerveControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose,
			frc::SwerveDriveKinematics<4> kinematics,
			frc2::PIDController xController, frc2::PIDController yController,
			frc2::PIDController rotationController,
			std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
			std::initializer_list<frc2::Subsystem*> requirements,
			bool useAllianceColor = false);

	/**
	 * @brief Constructs a new PPSwerveControllerCommand that when executed will follow the
	 * provided trajectory.
	 *
	 * @param trajectory         The trajectory to follow.
	 * @param pose               A function that returns the robot pose - use one of the odometry classes to provide this.
	 * @param kinematics         The kinematics for the robot drivetrain.
	 * @param xController        The Trajectory Tracker PID controller for the robot's x position.
	 * @param yController        The Trajectory Tracker PID controller for the robot's y position.
	 * @param rotationController The Trajectory Tracker PID controller for angle for the robot.
	 * @param output             The raw output module states from the position controllers.
	 * @param requirements       The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPSwerveControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose,
			frc::SwerveDriveKinematics<4> kinematics,
			frc2::PIDController xController, frc2::PIDController yController,
			frc2::PIDController rotationController,
			std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
			std::span<frc2::Subsystem* const > requirements = { },
			bool useAllianceColor = false);

	void Initialize() override;

	void Execute() override;

	void End(bool interrupted) override;

	bool IsFinished() override;

	static void setLoggingCallbacks(
			std::function<void(PathPlannerTrajectory)> logActiveTrajectory,
			std::function<void(frc::Pose2d)> logTargetPose,
			std::function<void(frc::ChassisSpeeds)> logSetpoint,
			std::function<void(frc::Translation2d, frc::Rotation2d)> logError) {
		PPSwerveControllerCommand::logActiveTrajectory = logActiveTrajectory;
		PPSwerveControllerCommand::logTargetPose = logTargetPose;
		PPSwerveControllerCommand::logSetpoint = logSetpoint;
		PPSwerveControllerCommand::logError = logError;
	}

private:
	PathPlannerTrajectory m_trajectory;
	std::function<frc::Pose2d()> m_pose;
	frc::SwerveDriveKinematics<4> m_kinematics;
	std::function<void(std::array<frc::SwerveModuleState, 4>)> m_outputStates;
	std::function<void(frc::ChassisSpeeds)> m_outputChassisSpeeds;
	bool m_useKinematics;

	frc::Timer m_timer;
	PPHolonomicDriveController m_controller;

	bool m_useAllianceColor;

	PathPlannerTrajectory m_transformedTrajectory;

	static std::function<void(PathPlannerTrajectory)> logActiveTrajectory;
	static std::function<void(frc::Pose2d)> logTargetPose;
	static std::function<void(frc::ChassisSpeeds)> logSetpoint;
	static std::function<void(frc::Translation2d, frc::Rotation2d)> logError;
};
}
