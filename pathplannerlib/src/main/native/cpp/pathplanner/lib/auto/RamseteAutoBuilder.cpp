#include "pathplanner/lib/auto/RamseteAutoBuilder.h"

#include <frc2/command/RamseteCommand.h>

using namespace pathplanner;

RamseteAutoBuilder::RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		frc::RamseteController controller,
		frc::DifferentialDriveKinematics kinematics,
		std::function<
				void(units::meters_per_second_t, units::meters_per_second_t)> output,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		std::initializer_list<frc2::Subsystem*> driveRequirements) : BaseAutoBuilder(
		pose, resetPose, eventMap, BaseAutoBuilder::DriveTrainType::STANDARD), m_controller(
		controller), m_kinematics(kinematics), m_output(output), m_driveRequirements(
		driveRequirements) {

}

frc2::CommandPtr RamseteAutoBuilder::followPath(
		PathPlannerTrajectory trajectory) {
	return frc2::RamseteCommand(trajectory.asWPILibTrajectory(), m_pose,
			m_controller, m_kinematics, m_output, m_driveRequirements).ToPtr();
}
