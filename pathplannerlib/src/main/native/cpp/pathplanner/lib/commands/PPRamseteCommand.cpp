#include "pathplanner/lib/commands/PPRamseteCommand.h"

#include <frc/smartdashboard/SmartDashboard.h>

using namespace pathplanner;

PPRamseteCommand::PPRamseteCommand(PathPlannerTrajectory trajectory,
		std::function<frc::Pose2d()> pose, frc::RamseteController controller,
		frc::SimpleMotorFeedforward<units::meters> feedforward,
		frc::DifferentialDriveKinematics kinematics,
		std::function<frc::DifferentialDriveWheelSpeeds()> wheelSpeeds,
		frc2::PIDController leftController, frc2::PIDController rightController,
		std::function<void(units::volt_t, units::volt_t)> output,
		std::initializer_list<frc2::Subsystem*> requirements) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_controller(
		controller), m_feedforward(feedforward), m_kinematics(kinematics), m_speeds(
		std::move(wheelSpeeds)), m_leftController(
		std::make_unique < frc2::PIDController > (leftController)), m_rightController(
		std::make_unique < frc2::PIDController > (rightController)), m_outputVolts(
		std::move(output)), m_usePID(true) {
	this->AddRequirements(requirements);
}

PPRamseteCommand::PPRamseteCommand(PathPlannerTrajectory trajectory,
		std::function<frc::Pose2d()> pose, frc::RamseteController controller,
		frc::SimpleMotorFeedforward<units::meters> feedforward,
		frc::DifferentialDriveKinematics kinematics,
		std::function<frc::DifferentialDriveWheelSpeeds()> wheelSpeeds,
		frc2::PIDController leftController, frc2::PIDController rightController,
		std::function<void(units::volt_t, units::volt_t)> output,
		std::span<frc2::Subsystem* const > requirements) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_controller(
		controller), m_feedforward(feedforward), m_kinematics(kinematics), m_speeds(
		std::move(wheelSpeeds)), m_leftController(
		std::make_unique < frc2::PIDController > (leftController)), m_rightController(
		std::make_unique < frc2::PIDController > (rightController)), m_outputVolts(
		std::move(output)), m_usePID(true) {
	this->AddRequirements(requirements);
}

PPRamseteCommand::PPRamseteCommand(PathPlannerTrajectory trajectory,
		std::function<frc::Pose2d()> pose, frc::RamseteController controller,
		frc::DifferentialDriveKinematics kinematics,
		std::function<
				void(units::meters_per_second_t, units::meters_per_second_t)> output,
		std::initializer_list<frc2::Subsystem*> requirements) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_controller(
		controller), m_kinematics(kinematics), m_outputVel(std::move(output)), m_usePID(
		false) {
	this->AddRequirements(requirements);
}

PPRamseteCommand::PPRamseteCommand(PathPlannerTrajectory trajectory,
		std::function<frc::Pose2d()> pose, frc::RamseteController controller,
		frc::DifferentialDriveKinematics kinematics,
		std::function<
				void(units::meters_per_second_t, units::meters_per_second_t)> output,
		std::span<frc2::Subsystem* const > requirements) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_controller(
		controller), m_kinematics(kinematics), m_outputVel(std::move(output)), m_usePID(
		false) {
	this->AddRequirements(requirements);
}

void PPRamseteCommand::Initialize() {
	frc::SmartDashboard::PutData("PPSwerveControllerCommand_field",
			&this->m_field);
	this->m_field.GetObject("traj")->SetTrajectory(
			this->m_trajectory.asWPILibTrajectory());

	m_prevTime = -1_s;
	auto initialState = m_trajectory.sample(0_s);
	m_prevSpeeds = m_kinematics.ToWheelSpeeds(
			frc::ChassisSpeeds { initialState.velocity, 0_mps,
					initialState.velocity * initialState.curvature });
	m_timer.Reset();
	m_timer.Start();
	if (m_usePID) {
		m_leftController->Reset();
		m_rightController->Reset();
	}
}

void PPRamseteCommand::Execute() {
	auto curTime = m_timer.Get();
	auto dt = curTime - m_prevTime;

	if (m_prevTime < 0_s) {
		if (m_usePID) {
			m_outputVolts(0_V, 0_V);
		} else {
			m_outputVel(0_mps, 0_mps);
		}

		m_prevTime = curTime;
		return;
	}

	frc::Pose2d currentPose = m_pose();
	PathPlannerTrajectory::PathPlannerState desiredState = m_trajectory.sample(
			curTime);
	m_field.SetRobotPose(currentPose);

	frc::SmartDashboard::PutNumber("PPRamseteCommand_xError",
			(currentPose.X() - desiredState.pose.X())());
	frc::SmartDashboard::PutNumber("PPRamseteCommand_yError",
			(currentPose.Y() - desiredState.pose.Y())());
	frc::SmartDashboard::PutNumber("PPRamseteCommand_rotationError",
			(currentPose.Rotation().Radians()
					- desiredState.pose.Rotation().Radians())());

	auto targetWheelSpeeds = m_kinematics.ToWheelSpeeds(
			m_controller.Calculate(currentPose, desiredState.pose,
					desiredState.velocity, desiredState.angularVelocity));

	if (m_usePID) {
		auto leftFeedforward = m_feedforward.Calculate(targetWheelSpeeds.left,
				(targetWheelSpeeds.left - m_prevSpeeds.left) / dt);

		auto rightFeedforward = m_feedforward.Calculate(targetWheelSpeeds.right,
				(targetWheelSpeeds.right - m_prevSpeeds.right) / dt);

		auto leftOutput = units::volt_t { m_leftController->Calculate(
				m_speeds().left.value(), targetWheelSpeeds.left.value()) }
				+ leftFeedforward;

		auto rightOutput = units::volt_t { m_rightController->Calculate(
				m_speeds().right.value(), targetWheelSpeeds.right.value()) }
				+ rightFeedforward;

		m_outputVolts(leftOutput, rightOutput);
	} else {
		m_outputVel(targetWheelSpeeds.left, targetWheelSpeeds.right);
	}
	m_prevSpeeds = targetWheelSpeeds;
	m_prevTime = curTime;
}

void PPRamseteCommand::End(bool interrupted) {
	m_timer.Stop();

	if (interrupted) {
		if (m_usePID) {
			m_outputVolts(0_V, 0_V);
		} else {
			m_outputVel(0_mps, 0_mps);
		}
	}
}

bool PPRamseteCommand::IsFinished() {
	return m_timer.HasElapsed(m_trajectory.getTotalTime());
}
