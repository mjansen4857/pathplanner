#include "pathplanner/lib/auto/MecanumAutoBuilder.h"

#include "pathplanner/lib/commands/PPMecanumControllerCommand.h"

using namespace pathplanner;

MecanumAutoBuilder::MecanumAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::MecanumDriveKinematics kinematics,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		units::meters_per_second_t maxWheelVelocity,
		std::function<
				void(units::meters_per_second_t, units::meters_per_second_t,
						units::meters_per_second_t, units::meters_per_second_t)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements) : BaseAutoBuilder(
		pose, resetPose, eventMap, BaseAutoBuilder::DriveTrainType::HOLONOMIC), m_kinematics(
		kinematics), m_translationConstants(translationConstants), m_rotationConstants(
		rotationConstants), m_maxWheelVelocity(maxWheelVelocity), m_outputVel(
		output), m_driveRequirements(driveRequirements) {

}

frc2::CommandPtr MecanumAutoBuilder::followPath(
		PathPlannerTrajectory trajectory) {
	return PPMecanumControllerCommand(trajectory, m_pose, m_kinematics,
			frc2::PIDController(m_translationConstants.m_kP,
					m_translationConstants.m_kI, m_translationConstants.m_kD,
					m_translationConstants.m_period),
			frc2::PIDController(m_translationConstants.m_kP,
					m_translationConstants.m_kI, m_translationConstants.m_kD,
					m_translationConstants.m_period),
			frc2::PIDController(m_rotationConstants.m_kP,
					m_rotationConstants.m_kI, m_rotationConstants.m_kD,
					m_rotationConstants.m_period), m_maxWheelVelocity,
			m_outputVel, m_driveRequirements).ToPtr();
}
