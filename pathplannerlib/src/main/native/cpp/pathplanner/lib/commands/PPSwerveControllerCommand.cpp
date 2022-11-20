#include "pathplanner/lib/commands/PPSwerveControllerCommand.h"

#include <frc/smartdashboard/SmartDashboard.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/controller/PIDController.h>

using namespace pathplanner;

PPSwerveControllerCommand::PPSwerveControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::SwerveDriveKinematics<4> kinematics,
		frc2::PIDController xController, frc2::PIDController yController,
		frc2::PIDController rotationController,
		std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
		std::initializer_list<frc2::Subsystem*> requirements) : m_trajectory(
		trajectory), m_pose(pose), m_kinematics(kinematics), m_output(output), m_controller(
		xController, yController, rotationController) {
	this->AddRequirements(requirements);
}

PPSwerveControllerCommand::PPSwerveControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::SwerveDriveKinematics<4> kinematics,
		frc2::PIDController xController, frc2::PIDController yController,
		frc2::PIDController rotationController,
		std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
		std::span<frc2::Subsystem* const > requirements) : m_trajectory(
		trajectory), m_pose(pose), m_kinematics(kinematics), m_output(output), m_controller(
		xController, yController, rotationController) {
	this->AddRequirements(requirements);
}

void PPSwerveControllerCommand::Initialize() {
	frc::SmartDashboard::PutData("PPSwerveControllerCommand_field",
			&this->m_field);
	this->m_field.GetObject("traj")->SetTrajectory(
			this->m_trajectory.asWPILibTrajectory());

	this->m_timer.Reset();
	this->m_timer.Start();
}

void PPSwerveControllerCommand::Execute() {
	auto currentTime = this->m_timer.Get();
	auto desiredState = this->m_trajectory.sample(currentTime);

	frc::Pose2d currentPose = this->m_pose();
	this->m_field.SetRobotPose(currentPose);

	frc::SmartDashboard::PutNumber("PPSwerveControllerCommand_xError",
			(currentPose.X() - desiredState.pose.X())());
	frc::SmartDashboard::PutNumber("PPSwerveControllerCommand_yError",
			(currentPose.Y() - desiredState.pose.Y())());
	frc::SmartDashboard::PutNumber("PPSwerveControllerCommand_rotationError",
			(currentPose.Rotation().Radians()
					- desiredState.holonomicRotation.Radians())());

	frc::ChassisSpeeds targetChassisSpeeds = this->m_controller.calculate(
			currentPose, desiredState);
	auto targetModuleStates = this->m_kinematics.ToSwerveModuleStates(
			targetChassisSpeeds);

	this->m_output(targetModuleStates);
}

void PPSwerveControllerCommand::End(bool interrupted) {
	this->m_timer.Stop();

	if (interrupted) {
		this->m_output(
				this->m_kinematics.ToSwerveModuleStates(frc::ChassisSpeeds()));
	}
}

bool PPSwerveControllerCommand::IsFinished() {
	return this->m_timer.HasElapsed(this->m_trajectory.getTotalTime());
}
