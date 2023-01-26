#include "pathplanner/lib/commands/PPMecanumControllerCommand.h"

#include <frc/smartdashboard/SmartDashboard.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

std::function<void(PathPlannerTrajectory)> PPMecanumControllerCommand::logActiveTrajectory =
		[](auto traj) {
		};
std::function<void(frc::Pose2d)> PPMecanumControllerCommand::logTargetPose = [](
		auto pose) {
};
std::function<void(frc::ChassisSpeeds)> PPMecanumControllerCommand::logSetpoint =
		[](auto speeds) {
		};
std::function<void(frc::Translation2d, frc::Rotation2d)> PPMecanumControllerCommand::logError =
		[](auto transError, auto rotError) {
			frc::SmartDashboard::PutNumber(
					"PPMecanumControllerCommand/xErrorMeters",
					transError.X()());
			frc::SmartDashboard::PutNumber(
					"PPMecanumControllerCommand/yErrorMeters",
					transError.Y()());
			frc::SmartDashboard::PutNumber(
					"PPMecanumControllerCommand/rotationErrorDegrees",
					rotError.Degrees()());
		};

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

	m_timer.Reset();
	m_timer.Start();

	if (PPMecanumControllerCommand::logActiveTrajectory) {
		PPMecanumControllerCommand::logActiveTrajectory (m_transformedTrajectory);
	}
}

void PPMecanumControllerCommand::Execute() {
	auto currentTime = m_timer.Get();
	auto desiredState = m_transformedTrajectory.sample(currentTime);

	frc::Pose2d currentPose = m_pose();

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

	if (PPMecanumControllerCommand::logTargetPose) {
		PPMecanumControllerCommand::logTargetPose(
				frc::Pose2d(desiredState.pose.Translation(),
						desiredState.holonomicRotation));
	}

	if (PPMecanumControllerCommand::logError) {
		PPMecanumControllerCommand::logError(
				currentPose.Translation() - desiredState.pose.Translation(),
				currentPose.Rotation() - desiredState.holonomicRotation);
	}

	if (PPMecanumControllerCommand::logSetpoint) {
		PPMecanumControllerCommand::logSetpoint(targetChassisSpeeds);
	}
}

void PPMecanumControllerCommand::End(bool interrupted) {
	m_timer.Stop();

	if (interrupted
			|| std::abs(m_transformedTrajectory.getEndState().velocity())
					< 0.1) {
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
