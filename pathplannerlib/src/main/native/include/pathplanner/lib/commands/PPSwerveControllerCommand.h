#pragma once

#include <frc2/command/CommandBase.h>
#include <frc2/command/CommandHelper.h>
#include <frc/Timer.h>
#include <frc/controller/PIDController.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/kinematics/SwerveModuleState.h>
#include <frc/smartdashboard/SmartDashboard.h>
#include <frc/smartdashboard/Field2d.h>
#include <pathplanner/lib/PathPlannerTrajectory.h>
#include <pathplanner/lib/controllers/PPHolonomicDriveController.h>
#include <unordered_map>
#include <deque>
#include <memory>

namespace pathplanner {
template<size_t NumModules>
class PPSwerveControllerCommand: public frc2::CommandHelper<frc2::CommandBase,
		PPSwerveControllerCommand<NumModules>> {

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
	 * @param eventMap           Map of event marker names to the commands that should run when reaching that marker.
	 *                           This SHOULD NOT contain any commands requiring the same subsystems as this command, or it will be interrupted
	 * @param requirements       The subsystems to require.
	 */
	PPSwerveControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose,
			frc::SwerveDriveKinematics<NumModules> kinematics,
			frc2::PIDController xController, frc2::PIDController yController,
			frc2::PIDController rotationController,
			std::function<void(std::array<frc::SwerveModuleState, NumModules>)> output,
			std::unordered_map<std::string, std::unique_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> requirements) : m_trajectory(
			trajectory), m_pose(pose), m_kinematics(kinematics), m_output(
			output), m_eventMap(eventMap), m_controller(xController,
			yController, rotationController) {
		this->AddRequirements(requirements);
	}

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
	 */
	PPSwerveControllerCommand(PathPlannerTrajectory trajectory,
			std::function<frc::Pose2d()> pose,
			frc::SwerveDriveKinematics<NumModules> kinematics,
			frc2::PIDController xController, frc2::PIDController yController,
			frc2::PIDController rotationController,
			std::function<void(std::array<frc::SwerveModuleState, NumModules>)> output,
			std::initializer_list<frc2::Subsystem*> requirements) : m_trajectory(
			trajectory), m_pose(pose), m_kinematics(kinematics), m_output(
			output), m_controller(xController, yController, rotationController) {
		this->AddRequirements(requirements);
	}

	void Initialize() override {
		this->m_unpassedMarkers.clear();
		this->m_unpassedMarkers.insert(this->m_unpassedMarkers.end(),
				this->m_trajectory.getMarkers().begin(),
				this->m_trajectory.getMarkers().end());

		frc::SmartDashboard::PutData("PPSwerveControllerCommand_field",
				&this->m_field);
		this->m_field.GetObject("traj")->SetTrajectory(
				this->m_trajectory.asWPILibTrajectory());

		this->m_timer.Reset();
		this->m_timer.Start();
	}

	void Execute() override {
		auto currentTime = this->m_timer.Get();
		auto desiredState = this->m_trajectory.sample(currentTime);

		frc::Pose2d currentPose = this->m_pose();
		this->m_field.SetRobotPose(currentPose);

		frc::SmartDashboard::PutNumber("PPSwerveControllerCommand_xError",
				(currentPose.X() - desiredState.pose.X())());
		frc::SmartDashboard::PutNumber("PPSwerveControllerCommand_yError",
				(currentPose.Y() - desiredState.pose.Y())());
		frc::SmartDashboard::PutNumber(
				"PPSwerveControllerCommand_rotationError",
				(currentPose.Rotation().Radians()
						- desiredState.holonomicRotation.Radians())());

		frc::ChassisSpeeds targetChassisSpeeds = this->m_controller.calculate(
				currentPose, desiredState);
		auto targetModuleStates = this->m_kinematics.ToSwerveModuleStates(
				targetChassisSpeeds);

		this->m_output(targetModuleStates);

		if (this->m_unpassedMarkers.size() > 0
				&& currentTime >= this->m_unpassedMarkers[0].time) {
			PathPlannerTrajectory::EventMarker marker =
					this->m_unpassedMarkers[0];
			this->m_unpassedMarkers.pop_front();

			for (std::string name : marker.names) {
				if (this->m_eventMap.find(name) != this->m_eventMap.end()) {
					this->m_eventMap[name]->Schedule();
				}
			}
		}
	}

	void End(bool interrupted) override {
		this->m_timer.Stop();

		if (interrupted) {
			this->m_output(
					this->m_kinematics.ToSwerveModuleStates(
							frc::ChassisSpeeds()));
		}
	}

	bool IsFinished() override {
		return this->m_timer.HasElapsed(this->m_trajectory.getTotalTime());
	}

private:
	PathPlannerTrajectory m_trajectory;
	std::function<frc::Pose2d()> m_pose;
	frc::SwerveDriveKinematics<NumModules> m_kinematics;
	std::function<void(std::array<frc::SwerveModuleState, NumModules>)> m_output;
	std::unordered_map<std::string, std::shared_ptr<frc2::Command>> m_eventMap;

	frc::Timer m_timer;
	PPHolonomicDriveController m_controller;
	std::deque<PathPlannerTrajectory::EventMarker> m_unpassedMarkers;
	frc::Field2d m_field;
};
}
