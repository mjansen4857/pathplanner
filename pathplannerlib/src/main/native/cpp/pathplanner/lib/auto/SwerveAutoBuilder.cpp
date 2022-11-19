#include "pathplanner/lib/auto/SwerveAutoBuilder.h"

#include "pathplanner/lib/commands/PPSwerveControllerCommand.h"

using namespace pathplanner;

SwerveAutoBuilder::SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::SwerveDriveKinematics<4> kinematics,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements) : BaseAutoBuilder(
		pose, resetPose, eventMap, BaseAutoBuilder::DriveTrainType::HOLONOMIC), m_kinematics(
		kinematics), m_translationConstants(translationConstants), m_rotationConstants(
		rotationConstants), m_output(output) {
	m_driveRequirements.insert(driveRequirements.begin(),
			driveRequirements.end());
}

SwerveAutoBuilder::SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::SwerveDriveKinematics<4> kinematics,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::span<frc2::Subsystem* const > driveRequirements) : BaseAutoBuilder(
		pose, resetPose, eventMap, BaseAutoBuilder::DriveTrainType::HOLONOMIC), m_kinematics(
		kinematics), m_translationConstants(translationConstants), m_rotationConstants(
		rotationConstants), m_output(output) {
	m_driveRequirements.insert(driveRequirements.begin(),
			driveRequirements.end());
}

frc2::CommandPtr SwerveAutoBuilder::followPath(
		PathPlannerTrajectory trajectory) {
	PPSwerveControllerCommand cmd(trajectory, m_pose, m_kinematics,
			frc2::PIDController(m_translationConstants.m_kP,
					m_translationConstants.m_kI, m_translationConstants.m_kD,
					m_translationConstants.m_period),
			frc2::PIDController(m_translationConstants.m_kP,
					m_translationConstants.m_kI, m_translationConstants.m_kD,
					m_translationConstants.m_period),
			frc2::PIDController(m_rotationConstants.m_kP,
					m_rotationConstants.m_kI, m_rotationConstants.m_kD,
					m_rotationConstants.m_period), m_output);

	cmd.AddRequirements(m_driveRequirements);

	return std::move(cmd).ToPtr();
}
