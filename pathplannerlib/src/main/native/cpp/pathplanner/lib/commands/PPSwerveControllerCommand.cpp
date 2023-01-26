#include "pathplanner/lib/commands/PPSwerveControllerCommand.h"

#include <frc/smartdashboard/SmartDashboard.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/controller/PIDController.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

std::function<void(PathPlannerTrajectory)> PPSwerveControllerCommand::logActiveTrajectory =
		[](auto traj) {
		};
std::function<void(frc::Pose2d)> PPSwerveControllerCommand::logTargetPose = [](
		auto pose) {
};
std::function<void(frc::ChassisSpeeds)> PPSwerveControllerCommand::logSetpoint =
		[](auto speeds) {
		};
std::function<void(frc::Translation2d, frc::Rotation2d)> PPSwerveControllerCommand::logError =
		[](auto transError, auto rotError) {
			frc::SmartDashboard::PutNumber(
					"PPSwerveControllerCommand/xErrorMeters", transError.X()());
			frc::SmartDashboard::PutNumber(
					"PPSwerveControllerCommand/yErrorMeters", transError.Y()());
			frc::SmartDashboard::PutNumber(
					"PPSwerveControllerCommand/rotationErrorDegrees",
					rotError.Degrees()());
		};

PPSwerveControllerCommand::PPSwerveControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc2::PIDController xController, frc2::PIDController yController,
		frc2::PIDController rotationController,
		std::function<void(frc::ChassisSpeeds)> output,
		std::initializer_list<frc2::Subsystem*> requirements,
		bool useAllianceColor) : m_trajectory(trajectory), m_pose(pose), m_kinematics(
		frc::Translation2d(), frc::Translation2d(), frc::Translation2d(),
		frc::Translation2d()), m_outputChassisSpeeds(output), m_useKinematics(
		false), m_controller(xController, yController, rotationController), m_useAllianceColor(
		useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

PPSwerveControllerCommand::PPSwerveControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc2::PIDController xController, frc2::PIDController yController,
		frc2::PIDController rotationController,
		std::function<void(frc::ChassisSpeeds)> output,
		std::span<frc2::Subsystem* const > requirements, bool useAllianceColor) : m_trajectory(
		trajectory), m_pose(pose), m_kinematics(frc::Translation2d(),
		frc::Translation2d(), frc::Translation2d(), frc::Translation2d()), m_outputChassisSpeeds(
		output), m_useKinematics(false), m_controller(xController, yController,
		rotationController), m_useAllianceColor(useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

PPSwerveControllerCommand::PPSwerveControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::SwerveDriveKinematics<4> kinematics,
		frc2::PIDController xController, frc2::PIDController yController,
		frc2::PIDController rotationController,
		std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
		std::initializer_list<frc2::Subsystem*> requirements,
		bool useAllianceColor) : m_trajectory(trajectory), m_pose(pose), m_kinematics(
		kinematics), m_outputStates(output), m_useKinematics(true), m_controller(
		xController, yController, rotationController), m_useAllianceColor(
		useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

PPSwerveControllerCommand::PPSwerveControllerCommand(
		PathPlannerTrajectory trajectory, std::function<frc::Pose2d()> pose,
		frc::SwerveDriveKinematics<4> kinematics,
		frc2::PIDController xController, frc2::PIDController yController,
		frc2::PIDController rotationController,
		std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
		std::span<frc2::Subsystem* const > requirements, bool useAllianceColor) : m_trajectory(
		trajectory), m_pose(pose), m_kinematics(kinematics), m_outputStates(
		output), m_useKinematics(true), m_controller(xController, yController,
		rotationController), m_useAllianceColor(useAllianceColor) {
	this->AddRequirements(requirements);

	if (m_useAllianceColor && m_trajectory.fromGUI
			&& m_trajectory.getInitialPose().X() > 8.27_m) {
		FRC_ReportError(frc::warn::Warning,
				"You have constructed a path following command that will automatically transform path states depending on the alliance color, however, it appears this path was created on the red side of the field instead of the blue side. This is likely an error.");
	}
}

void PPSwerveControllerCommand::Initialize() {
	if (m_useAllianceColor && m_trajectory.fromGUI) {
		m_transformedTrajectory =
				PathPlannerTrajectory::transformTrajectoryForAlliance(
						m_trajectory, frc::DriverStation::GetAlliance());
	} else {
		m_transformedTrajectory = m_trajectory;
	}

	this->m_timer.Reset();
	this->m_timer.Start();

	if (PPSwerveControllerCommand::logActiveTrajectory) {
		PPSwerveControllerCommand::logActiveTrajectory (m_transformedTrajectory);
	}
}

void PPSwerveControllerCommand::Execute() {
	auto currentTime = this->m_timer.Get();
	auto desiredState = m_transformedTrajectory.sample(currentTime);

	frc::Pose2d currentPose = this->m_pose();

	frc::ChassisSpeeds targetChassisSpeeds = this->m_controller.calculate(
			currentPose, desiredState);

	if (m_useKinematics) {
		auto targetModuleStates = this->m_kinematics.ToSwerveModuleStates(
				targetChassisSpeeds);

		this->m_outputStates(targetModuleStates);
	} else {
		this->m_outputChassisSpeeds(targetChassisSpeeds);
	}

	if (PPSwerveControllerCommand::logTargetPose) {
		PPSwerveControllerCommand::logTargetPose(
				frc::Pose2d(desiredState.pose.Translation(),
						desiredState.holonomicRotation));
	}

	if (PPSwerveControllerCommand::logError) {
		PPSwerveControllerCommand::logError(
				currentPose.Translation() - desiredState.pose.Translation(),
				currentPose.Rotation() - desiredState.holonomicRotation);
	}

	if (PPSwerveControllerCommand::logSetpoint) {
		PPSwerveControllerCommand::logSetpoint(targetChassisSpeeds);
	}
}

void PPSwerveControllerCommand::End(bool interrupted) {
	this->m_timer.Stop();

	if (interrupted
			|| std::abs(m_transformedTrajectory.getEndState().velocity())
					< 0.1) {
		if (m_useKinematics) {
			this->m_outputStates(
					this->m_kinematics.ToSwerveModuleStates(
							frc::ChassisSpeeds()));
		} else {
			this->m_outputChassisSpeeds(frc::ChassisSpeeds());
		}
	}
}

bool PPSwerveControllerCommand::IsFinished() {
	return this->m_timer.HasElapsed(m_transformedTrajectory.getTotalTime());
}
