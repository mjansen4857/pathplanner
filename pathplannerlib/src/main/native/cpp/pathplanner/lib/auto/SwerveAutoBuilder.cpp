#include "pathplanner/lib/auto/SwerveAutoBuilder.h"

#include "pathplanner/lib/commands/PPSwerveControllerCommand.h"

using namespace pathplanner;

SwerveAutoBuilder::SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements,
		bool useAllianceColor) : BaseAutoBuilder(pose, resetPose, eventMap,
		BaseAutoBuilder::DriveTrainType::HOLONOMIC, useAllianceColor), m_kinematics(
		frc::Translation2d(), frc::Translation2d(), frc::Translation2d(),
		frc::Translation2d()), m_translationConstants(translationConstants), m_rotationConstants(
		rotationConstants), m_outputSpeeds(output), m_driveRequirements(
		driveRequirements), m_useKinematics(false) {

}

SwerveAutoBuilder::SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::SwerveDriveKinematics<4> kinematics,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements,
		bool useAllianceColor) : BaseAutoBuilder(pose, resetPose, eventMap,
		BaseAutoBuilder::DriveTrainType::HOLONOMIC, useAllianceColor), m_kinematics(
		kinematics), m_translationConstants(translationConstants), m_rotationConstants(
		rotationConstants), m_outputStates(output), m_driveRequirements(
		driveRequirements), m_useKinematics(true) {

}

frc2::CommandPtr SwerveAutoBuilder::followPath(
		PathPlannerTrajectory trajectory) {
	if (m_useKinematics) {
		return PPSwerveControllerCommand(trajectory, m_pose, m_kinematics,
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_rotationConstants), m_outputStates,
				m_driveRequirements, m_useAllianceColor).ToPtr();
	} else {
		return PPSwerveControllerCommand(trajectory, m_pose,
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_translationConstants),
				BaseAutoBuilder::pidControllerFromConstants(
						m_rotationConstants), m_outputSpeeds,
				m_driveRequirements, m_useAllianceColor).ToPtr();
	}
}
