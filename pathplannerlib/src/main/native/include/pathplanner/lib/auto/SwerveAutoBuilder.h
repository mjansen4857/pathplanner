#pragma once

#include "pathplanner/lib/auto/BaseAutoBuilder.h"
#include "pathplanner/lib/auto/PIDConstants.h"

#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/kinematics/SwerveModuleState.h>

namespace pathplanner {
class SwerveAutoBuilder: public BaseAutoBuilder {
public:
	SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::SwerveDriveKinematics<4> kinematics,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements);

	SwerveAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::SwerveDriveKinematics<4> kinematics,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			std::function<void(std::array<frc::SwerveModuleState, 4>)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::span<frc2::Subsystem* const > driveRequirements = { });

	frc2::CommandPtr followPath(PathPlannerTrajectory trajectory) override;

private:
	frc::SwerveDriveKinematics<4> m_kinematics;
	PIDConstants m_translationConstants;
	PIDConstants m_rotationConstants;
	std::function<void(std::array<frc::SwerveModuleState, 4>)> m_output;
	wpi::SmallSet<frc2::Subsystem*, 4> m_driveRequirements;
};
}
