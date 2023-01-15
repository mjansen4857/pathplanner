#include "pathplanner/lib/commands/PPMecanumControllerCommand.h"

#include <frc/smartdashboard/SmartDashboard.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

PPMecanumControllerCommand::PPMecanumControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc2::PIDController xController, frc2::PIDController yController,
		frc::PIDController thetaController,
		std::function<void(frc::ChassisSpeeds)> output,
		std::initializer_list<frc2::Subsystem*> requirements,
		bool useAllianceColor) : m_trajectory(std::move(trajectory)), m_pose(
		std::move(pose)), m_kinematics(frc::Translation2d(),
		frc::Translation2d(), frc::Translation2d(), frc::Translation2d()), m_controller(
		xController, yController, thetaController), m_maxWheelVelocity(0_mps), m_outputChassisSpeeds(
		output), m_useKinematics(false), m_useAllianceColor(useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

PPMecanumControllerCommand::PPMecanumControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc2::PIDController xController, frc2::PIDController yController,
		frc::PIDController thetaController,
		std::function<void(frc::ChassisSpeeds)> output,
		std::span<frc2::Subsystem* const > requirements, bool useAllianceColor) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_kinematics(
		frc::Translation2d(), frc::Translation2d(), frc::Translation2d(),
		frc::Translation2d()), m_controller(xController, yController,
		thetaController), m_maxWheelVelocity(0_mps), m_outputChassisSpeeds(
		output), m_useKinematics(false), m_useAllianceColor(useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

PPMecanumControllerCommand::PPMecanumControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::MecanumDriveKinematics kinematics, frc2::PIDController xController,
		frc2::PIDController yController, frc::PIDController thetaController,
		units::meters_per_second_t maxWheelVelocity,
		std::function<void(frc::MecanumDriveWheelSpeeds)> output,
		std::initializer_list<frc2::Subsystem*> requirements,
		bool useAllianceColor) : m_trajectory(std::move(trajectory)), m_pose(
		std::move(pose)), m_kinematics(kinematics), m_controller(xController,
		yController, thetaController), m_maxWheelVelocity(maxWheelVelocity), m_outputVel(
		output), m_useKinematics(true), m_useAllianceColor(useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

PPMecanumControllerCommand::PPMecanumControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::MecanumDriveKinematics kinematics, frc2::PIDController xController,
		frc2::PIDController yController, frc::PIDController thetaController,
		units::meters_per_second_t maxWheelVelocity,
		std::function<void(frc::MecanumDriveWheelSpeeds)> output,
		std::span<frc2::Subsystem* const > requirements, bool useAllianceColor) : m_trajectory(
		std::move(trajectory)), m_pose(std::move(pose)), m_kinematics(
		kinematics), m_controller(xController, yController, thetaController), m_maxWheelVelocity(
		maxWheelVelocity), m_outputVel(output), m_useKinematics(true), m_useAllianceColor(
		useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

void PPMecanumControllerCommand::Initialize() {
	if (m_useAllianceColor && m_trajectory.fromGUI) {
		m_transformedTrajectory =
				PathPlannerTrajectory::transformTrajectoryForAlliance(
						m_trajectory, frc::DriverStation::GetAlliance());
	} else {
		m_transformedTrajectory = m_trajectory;
	}

	frc::SmartDashboard::PutData("PPSwerveControllerCommand_field",
			&this->m_field);
	this->m_field.GetObject("traj")->SetTrajectory(
			m_transformedTrajectory.asWPILibTrajectory());

	m_timer.Reset();
	m_timer.Start();
}

void PPMecanumControllerCommand::Execute() {
	auto currentTime = m_timer.Get();
	auto desiredState = m_transformedTrajectory.sample(currentTime);

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

	if (m_useKinematics) {
		auto targetWheelSpeeds = m_kinematics.ToWheelSpeeds(
				targetChassisSpeeds);

		targetWheelSpeeds.Desaturate(m_maxWheelVelocity);

		m_outputVel(targetWheelSpeeds);
	} else {
		m_outputChassisSpeeds(targetChassisSpeeds);
	}
}

void PPMecanumControllerCommand::End(bool interrupted) {
	m_timer.Stop();

	if (interrupted) {
		if (m_useKinematics) {
			m_outputVel(frc::MecanumDriveWheelSpeeds());
		} else {
			m_outputChassisSpeeds(frc::ChassisSpeeds());
		}
	}
}

bool PPMecanumControllerCommand::IsFinished() {
	return m_timer.HasElapsed(m_transformedTrajectory.getTotalTime());
}
