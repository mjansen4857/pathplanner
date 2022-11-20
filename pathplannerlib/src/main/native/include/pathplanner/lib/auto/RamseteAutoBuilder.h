#pragma once

#include <frc/controller/RamseteController.h>
#include <frc/kinematics/DifferentialDriveKinematics.h>
#include <units/velocity.h>

#include "pathplanner/lib/auto/BaseAutoBuilder.h"

namespace pathplanner {
class RamseteAutoBuilder: public BaseAutoBuilder {
public:
	RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::RamseteController controller,
			frc::DifferentialDriveKinematics kinematics,
			std::function<
					void(units::meters_per_second_t, units::meters_per_second_t)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements);

	frc2::CommandPtr followPath(PathPlannerTrajectory trajectory) override;

private:
	frc::RamseteController m_controller;
	frc::DifferentialDriveKinematics m_kinematics;
	std::function<void(units::meters_per_second_t, units::meters_per_second_t)> m_output;
	std::initializer_list<frc2::Subsystem*> m_driveRequirements;
};
}
