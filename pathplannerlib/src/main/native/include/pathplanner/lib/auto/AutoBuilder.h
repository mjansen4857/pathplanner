#pragma once

#include <functional>
#include <frc2/command/CommandPtr.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <memory>
#include <wpi/json.h>
#include <string>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/util/HolonomicPathFollowerConfig.h"

namespace pathplanner {
class AutoBuilder {
public:
	/**
	 * Configures the AutoBuilder for a holonomic drivetrain.
	 *
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param resetPose a function used for resetting the robot's pose
	 * @param robotRelativeSpeedsSupplier a function that returns the robot's current robot relative chassis speeds
	 * @param robotRelativeOutput a function for setting the robot's field-relative chassis speeds
	 * @param config HolonomicPathFollowerConfig for configuring the
	 *     path following commands
	 * @param driveSubsystem a pointer to the subsystem for the robot's drive
	 */
	static void configureHolonomic(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			HolonomicPathFollowerConfig config,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder for a differential drivetrain.
	 *
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param resetPose a function used for resetting the robot's pose
	 * @param speedsSupplier a function that returns the robot's current chassis speeds
	 * @param output a function for setting the robot's chassis speeds
	 * @param driveSubsystem a pointer to the subsystem for the robot's drive
	 */
	static void configureDifferential(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder with custom path following command builder.
	 *
	 * @param pathFollowingCommandBuilder a function that builds a command to follow a given path
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param resetPose a function for resetting the robot's pose
	 */
	static void configureCustom(
			std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> pathFollowingCommandBuilder,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose);

	/**
	 * Returns whether the AutoBuilder has been configured.
	 *
	 * @return true if the AutoBuilder has been configured, false otherwise
	 */
	static inline bool isConfigured() {
		return m_configured;
	}

	/**
	 * Builds a command to follow a path with event markers.
	 *
	 * @param path the path to follow
	 * @return a path following command with events for the given path
	 */
	static frc2::CommandPtr followPathWithEvents(
			std::shared_ptr<PathPlannerPath> path);

	/**
	 * Builds an auto command for the given auto name.
	 *
	 * @param autoName the name of the auto to build
	 * @return an auto command for the given auto name
	 */
	static frc2::CommandPtr buildAuto(std::string autoName);

	/**
	 * Builds an auto command from the given JSON.
	 *
	 * @param json the JSON to build the command from
	 * @return an auto command built from the JSON
	 */
	static frc2::CommandPtr getAutoCommandFromJson(const wpi::json &json);

	static frc::Pose2d getStartingPoseFromJson(const wpi::json &json);

private:
	static bool m_configured;
	static std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> m_pathFollowingCommandBuilder;
	static std::function<frc::Pose2d()> m_getPose;
	static std::function<void(frc::Pose2d)> m_resetPose;
};
}
