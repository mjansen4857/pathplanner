#include "pathplanner/lib/auto/RamseteAutoBuilder.h"

#include "pathplanner/lib/commands/PPRamseteCommand.h"

using namespace pathplanner;

RamseteAutoBuilder::RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::RamseteController controller,
		frc::DifferentialDriveKinematics kinematics,
		frc::SimpleMotorFeedforward<units::meters> feedforward,
		std::function<frc::DifferentialDriveWheelSpeeds()> speedsSupplier,
		PIDConstants driveConstants,
		std::function<void(units::volt_t, units::volt_t)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements,
		bool useAllianceColor) : BaseAutoBuilder(pose, resetPose, eventMap,
		BaseAutoBuilder::DriveTrainType::STANDARD, useAllianceColor), m_controller(
		controller), m_kinematics(kinematics), m_feedforward(feedforward), m_speeds(
		speedsSupplier), m_driveConstants(driveConstants), m_outputVolts(
		output), m_driveRequirements(driveRequirements), m_usePID(true) {
}

RamseteAutoBuilder::RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::RamseteController controller,
		frc::DifferentialDriveKinematics kinematics,
		std::function<
				void(units::meters_per_second_t, units::meters_per_second_t)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements,
		bool useAllianceColor) : BaseAutoBuilder(pose, resetPose, eventMap,
		BaseAutoBuilder::DriveTrainType::STANDARD, useAllianceColor), m_controller(
		controller), m_kinematics(kinematics), m_outputVel(output), m_driveRequirements(
		driveRequirements), m_usePID(false) {

}

frc2::CommandPtr RamseteAutoBuilder::followPath(
		PathPlannerTrajectory trajectory) {
	if (m_usePID) {
		return PPRamseteCommand(trajectory, m_pose, m_controller, m_feedforward,
				m_kinematics, m_speeds,
				BaseAutoBuilder::pidControllerFromConstants(m_driveConstants),
				BaseAutoBuilder::pidControllerFromConstants(m_driveConstants),
				m_outputVolts, m_driveRequirements, m_useAllianceColor).ToPtr();
	} else {
		return PPRamseteCommand(trajectory, m_pose, m_controller, m_kinematics,
				m_outputVel, m_driveRequirements, m_useAllianceColor).ToPtr();
	}
}
