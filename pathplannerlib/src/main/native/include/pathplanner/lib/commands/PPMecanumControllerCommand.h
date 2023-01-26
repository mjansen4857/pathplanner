#pragma once

#include <cmath>
#include <functional>
#include <initializer_list>
#include <memory>
#include <span>

#include <frc/Timer.h>
#include <frc/controller/PIDController.h>
#include <frc/controller/SimpleMotorFeedforward.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/kinematics/MecanumDriveKinematics.h>
#include <frc2/command/CommandBase.h>
#include <frc2/command/CommandHelper.h>
#include <units/angle.h>
#include <units/length.h>
#include <units/velocity.h>
#include <units/voltage.h>
#include <frc/smartdashboard/Field2d.h>

#include "pathplanner/lib/PathPlannerTrajectory.h"
#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"

namespace pathplanner {
/**
 * A command that uses two PID controllers (PIDController) and a profiled PID
 * controller (ProfiledPIDController) to follow a trajectory (Trajectory) with a
 * mecanum drive.
 *
 * <p>The command handles trajectory-following,
 * Velocity PID calculations, and feedforwards internally. This
 * is intended to be a more-or-less "complete solution" that can be used by
 * teams without a great deal of controls expertise.
 *
 */
class PPMecanumControllerCommand: public frc2::CommandHelper<frc2::CommandBase,
		PPMecanumControllerCommand> {
public:
	/**
	 * Constructs a new PPMecanumControllerCommand that when executed will follow
	 * the provided trajectory. The user should implement a velocity PID on the
	 * desired output wheel velocities.
	 *
	 * <p>Note: The controllers will *not* set the outputVolts to zero upon
	 * completion of the path - this is left to the user, since it is not
	 * appropriate for paths with non-stationary end-states.
	 *
	 * @param trajectory       The trajectory to follow.
	 * @param pose             A function that supplies the robot pose - use one
	 * of the odometry classes to provide this.
	 * @param xController      The Trajectory Tracker PID controller
	 *                         for the robot's x position.
	 * @param yController      The Trajectory Tracker PID controller
	 *                         for the robot's y position.
	 * @param thetaController  The Trajectory Tracker PID controller
	 *                         for angle for the robot.
	 * @param output           The output of the position PIDs.
	 * @param requirements     The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPMecanumControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose, frc2::PIDController xController,
			frc2::PIDController yController, frc::PIDController thetaController,
			std::function<void(frc::ChassisSpeeds)> output,
			std::initializer_list<frc2::Subsystem*> requirements,
			bool useAllianceColor = false);

	/**
	 * Constructs a new PPMecanumControllerCommand that when executed will follow
	 * the provided trajectory. The user should implement a velocity PID on the
	 * desired output wheel velocities.
	 *
	 * <p>Note: The controllers will *not* set the outputVolts to zero upon
	 * completion of the path - this is left to the user, since it is not
	 * appropriate for paths with non-stationary end-states.
	 *
	 * @param trajectory       The trajectory to follow.
	 * @param pose             A function that supplies the robot pose - use one
	 * of the odometry classes to provide this.
	 * @param xController      The Trajectory Tracker PID controller
	 *                         for the robot's x position.
	 * @param yController      The Trajectory Tracker PID controller
	 *                         for the robot's y position.
	 * @param thetaController  The Trajectory Tracker PID controller
	 *                         for angle for the robot.
	 * @param output           The output of the position PIDs.
	 * @param requirements     The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPMecanumControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose, frc2::PIDController xController,
			frc2::PIDController yController, frc::PIDController thetaController,
			std::function<void(frc::ChassisSpeeds)> output,
			std::span<frc2::Subsystem* const > requirements = { },
			bool useAllianceColor = false);

	/**
	 * Constructs a new PPMecanumControllerCommand that when executed will follow
	 * the provided trajectory. The user should implement a velocity PID on the
	 * desired output wheel velocities.
	 *
	 * <p>Note: The controllers will *not* set the outputVolts to zero upon
	 * completion of the path - this is left to the user, since it is not
	 * appropriate for paths with non-stationary end-states.
	 *
	 * @param trajectory       The trajectory to follow.
	 * @param pose             A function that supplies the robot pose - use one
	 * of the odometry classes to provide this.
	 * @param kinematics       The kinematics for the robot drivetrain.
	 * @param xController      The Trajectory Tracker PID controller
	 *                         for the robot's x position.
	 * @param yController      The Trajectory Tracker PID controller
	 *                         for the robot's y position.
	 * @param thetaController  The Trajectory Tracker PID controller
	 *                         for angle for the robot.
	 * @param maxWheelVelocity The maximum velocity of a drivetrain wheel.
	 * @param output           The output of the position PIDs.
	 * @param requirements     The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPMecanumControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose,
			frc::MecanumDriveKinematics kinematics,
			frc2::PIDController xController, frc2::PIDController yController,
			frc::PIDController thetaController,
			units::meters_per_second_t maxWheelVelocity,
			std::function<void(frc::MecanumDriveWheelSpeeds)> output,
			std::initializer_list<frc2::Subsystem*> requirements,
			bool useAllianceColor = false);

	/**
	 * Constructs a new PPMecanumControllerCommand that when executed will follow
	 * the provided trajectory. The user should implement a velocity PID on the
	 * desired output wheel velocities.
	 *
	 * <p>Note: The controllers will *not* set the outputVolts to zero upon
	 * completion of the path - this is left to the user, since it is not
	 * appropriate for paths with non-stationary end-states.
	 *
	 * @param trajectory       The trajectory to follow.
	 * @param pose             A function that supplies the robot pose - use one
	 * of the odometry classes to provide this.
	 * @param kinematics       The kinematics for the robot drivetrain.
	 * @param xController      The Trajectory Tracker PID controller
	 *                         for the robot's x position.
	 * @param yController      The Trajectory Tracker PID controller
	 *                         for the robot's y position.
	 * @param thetaController  The Trajectory Tracker PID controller
	 *                         for angle for the robot.
	 * @param maxWheelVelocity The maximum velocity of a drivetrain wheel.
	 * @param output           The output of the position PIDs.
	 * @param requirements     The subsystems to require.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	PPMecanumControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose,
			frc::MecanumDriveKinematics kinematics,
			frc2::PIDController xController, frc2::PIDController yController,
			frc::PIDController thetaController,
			units::meters_per_second_t maxWheelVelocity,
			std::function<void(frc::MecanumDriveWheelSpeeds)> output,
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
		PPMecanumControllerCommand::logActiveTrajectory = logActiveTrajectory;
		PPMecanumControllerCommand::logTargetPose = logTargetPose;
		PPMecanumControllerCommand::logSetpoint = logSetpoint;
		PPMecanumControllerCommand::logError = logError;
	}

private:
	PathPlannerTrajectory m_trajectory;
	std::function<frc::Pose2d()> m_pose;
	frc::MecanumDriveKinematics m_kinematics;
	PPHolonomicDriveController m_controller;
	const units::meters_per_second_t m_maxWheelVelocity;
	std::function<void(frc::MecanumDriveWheelSpeeds)> m_outputVel;
	std::function<void(frc::ChassisSpeeds)> m_outputChassisSpeeds;
	bool m_useKinematics;

	frc::Timer m_timer;

	bool m_useAllianceColor;

	PathPlannerTrajectory m_transformedTrajectory;

	static std::function<void(PathPlannerTrajectory)> logActiveTrajectory;
	static std::function<void(frc::Pose2d)> logTargetPose;
	static std::function<void(frc::ChassisSpeeds)> logSetpoint;
	static std::function<void(frc::Translation2d, frc::Rotation2d)> logError;
};
}
