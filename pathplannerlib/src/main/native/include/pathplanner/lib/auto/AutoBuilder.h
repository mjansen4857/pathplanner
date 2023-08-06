#pragma once

#include <functional>
#include <frc2/command/CommandPtr.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <memory>
#include <wpi/json.h>
#include <string>
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
class AutoBuilder {
public:
	static void configureHolonomic(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
			std::function<void(frc::ChassisSpeeds)> fieldRelativeOutput,
			frc2::Subsystem *driveSubsystem);

	static void configureDifferential(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			frc2::Subsystem *driveSubsystem);

	static void configureCustom(
			std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> pathFollowingCommandBuilder,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose);

	static inline bool isConfigured() {
		return m_configured;
	}

	static frc2::CommandPtr followPathWithEvents(
			std::shared_ptr<PathPlannerPath> path);

	static frc2::CommandPtr buildAuto(std::string autoName);

	static frc2::CommandPtr getAutoCommandFromJson(const wpi::json &json);

private:
	static frc::Pose2d getStartingPoseFromJson(const wpi::json &json);

	static bool m_configured;
	static std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> m_pathFollowingCommandBuilder;
	static std::function<frc::Pose2d()> m_getPose;
	static std::function<void(frc::Pose2d)> m_resetPose;
};
}
