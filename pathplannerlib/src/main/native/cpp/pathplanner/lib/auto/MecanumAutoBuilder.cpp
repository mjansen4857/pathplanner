#include "pathplanner/lib/auto/MecanumAutoBuilder.h"

#include "pathplanner/lib/commands/PPMecanumControllerCommand.h"

using namespace pathplanner;

MecanumAutoBuilder::MecanumAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements,
		bool useAllianceColor) : BaseAutoBuilder(pose, resetPose, eventMap,
		BaseAutoBuilder::DriveTrainType::HOLONOMIC, useAllianceColor), m_kinematics(
		frc::Translation2d(), frc::Translation2d(), frc::Translation2d(),
		frc::Translation2d()), m_translationConstants(translationConstants), m_rotationConstants(
		rotationConstants), m_maxWheelVelocity(0_mps), m_outputChassisSpeeds(
		output), m_driveRequirements(driveRequirements), m_useKinematics(false) {
}

MecanumAutoBuilder::MecanumAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::MecanumDriveKinematics kinematics,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		units::meters_per_second_t maxWheelVelocity,
		std::function<void(frc::MecanumDriveWheelSpeeds)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements,
		bool useAllianceColor) : BaseAutoBuilder(pose, resetPose, eventMap,
		BaseAutoBuilder::DriveTrainType::HOLONOMIC, useAllianceColor), m_kinematics(
		kinematics), m_translationConstants(translationConstants), m_rotationConstants(
		rotationConstants), m_maxWheelVelocity(maxWheelVelocity), m_outputVel(
		output), m_driveRequirements(driveRequirements), m_useKinematics(true) {
}

frc2::CommandPtr MecanumAutoBuilder::followPath(
		PathPlannerTrajectory trajectory) {
	if (m_useKinematics) {
		return PPMecanumControllerCommand(trajectory, m_pose, m_kinematics,
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_rotationConstants), m_maxWheelVelocity, m_outputVel,
				m_driveRequirements, m_useAllianceColor).ToPtr();
	} else {
		return PPMecanumControllerCommand(trajectory, m_pose,
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_rotationConstants), m_outputChassisSpeeds,
				m_driveRequirements, m_useAllianceColor).ToPtr();
	}
}
