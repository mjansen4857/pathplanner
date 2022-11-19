#include "pathplanner/lib/commands/PPMecanumControllerCommand.h"

#include <frc/smartdashboard/SmartDashboard.h>

using namespace pathplanner;

PPMecanumControllerCommand::PPMecanumControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::MecanumDriveKinematics kinematics, frc2::PIDController xController,
		frc2::PIDController yController, frc::PIDController thetaController,
		units::meters_per_second_t maxWheelVelocity,
		std::function<
				void(units::meters_per_second_t, units::meters_per_second_t,
						units::meters_per_second_t, units::meters_per_second_t)> output,
		std::initializer_list<frc2::Subsystem*> requirements) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_kinematics(
		kinematics), m_controller(xController, yController, thetaController), m_maxWheelVelocity(
		maxWheelVelocity), m_outputVel(output) {
	this->AddRequirements(requirements);
}

PPMecanumControllerCommand::PPMecanumControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::MecanumDriveKinematics kinematics, frc2::PIDController xController,
		frc2::PIDController yController, frc::PIDController thetaController,
		units::meters_per_second_t maxWheelVelocity,
		std::function<
				void(units::meters_per_second_t, units::meters_per_second_t,
						units::meters_per_second_t, units::meters_per_second_t)> output,
		std::span<frc2::Subsystem* const > requirements) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_kinematics(
		kinematics), m_controller(xController, yController, thetaController), m_maxWheelVelocity(
		maxWheelVelocity), m_outputVel(output) {
	this->AddRequirements(requirements);
}

void PPMecanumControllerCommand::Initialize() {
	frc::SmartDashboard::PutData("PPSwerveControllerCommand_field",
			&this->m_field);
	this->m_field.GetObject("traj")->SetTrajectory(
			this->m_trajectory.asWPILibTrajectory());

	m_timer.Reset();
	m_timer.Start();
}

void PPMecanumControllerCommand::Execute() {
	auto currentTime = m_timer.Get();
	auto desiredState = m_trajectory.sample(currentTime);

	frc::Pose2d currentPose = m_pose();
	m_field.SetRobotPose(currentPose);

	frc::SmartDashboard::PutNumber("PPMecanumControllerCommand_xError",
			(currentPose.X() - desiredState.pose.X())());
	frc::SmartDashboard::PutNumber("PPMecanumControllerCommand_yError",
			(currentPose.Y() - desiredState.pose.Y())());
	frc::SmartDashboard::PutNumber("PPMecanumControllerCommand_rotationError",
			(currentPose.Rotation().Radians()
					- desiredState.holonomicRotation.Radians())());

	auto targetChassisSpeeds = m_controller.calculate(currentPose,
			desiredState);
	auto targetWheelSpeeds = m_kinematics.ToWheelSpeeds(targetChassisSpeeds);

	targetWheelSpeeds.Desaturate(m_maxWheelVelocity);

	m_outputVel(targetWheelSpeeds.frontLeft, targetWheelSpeeds.rearLeft,
			targetWheelSpeeds.frontRight, targetWheelSpeeds.rearRight);
}

void PPMecanumControllerCommand::End(bool interrupted) {
	m_timer.Stop();
}

bool PPMecanumControllerCommand::IsFinished() {
	return m_timer.HasElapsed(m_trajectory.getTotalTime());
}
