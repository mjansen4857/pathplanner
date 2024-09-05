#pragma once

#include <functional>
#include <frc2/command/CommandPtr.h>
#include <frc2/command/Commands.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/controller/RamseteController.h>
#include <vector>
#include <frc2/command/Command.h>
#include <frc/smartdashboard/SendableChooser.h>
#include <memory>
#include <wpi/json.h>
#include <wpi/array.h>
#include <string>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/config/RobotConfig.h"
#include "pathplanner/lib/config/ReplanningConfig.h"
#include "pathplanner/lib/controllers/PathFollowingController.h"

namespace pathplanner {
class AutoBuilder {
public:
	/**
	 * Configures the AutoBuilder for using PathPlanner's built-in commands.
	 *
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param resetPose a function used for resetting the robot's pose
	 * @param robotRelativeSpeedsSupplier a function that returns the robot's current robot relative chassis speeds
	 * @param robotRelativeOutput a function for setting the robot's robot-relative chassis speeds
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem a pointer to the subsystem for the robot's drive
	 */
	static void configure(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder with custom path following command builder. Building pathfinding
	 * commands is not supported if using a custom command builder. Custom path following commands
	 * will not have the path flipped for them, and event markers will not be triggered automatically.
	 *
	 * @param pathFollowingCommandBuilder a function that builds a command to follow a given path
	 * @param resetPose a function for resetting the robot's pose
	 * @param shouldFlipPose Supplier that determines if the starting pose should be flipped to the
	 *     other side of the field. This will maintain a global blue alliance origin. NOTE: paths will
	 *     not be flipped when configured with a custom path following command. Flipping the paths
	 *     must be handled in your command.
	 */
	static void configureCustom(
			std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> pathFollowingCommandBuilder,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<bool()> shouldFlipPose = []() {
				return false;
			});

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
	static frc2::CommandPtr followPath(std::shared_ptr<PathPlannerPath> path);

	/**
	 * Builds a command to follow a path with event markers.
	 *
	 * @param path the path to follow
	 * @return a path following command with events for the given path
	 * @deprecated Renamed to followPath
	 */
	[[deprecated("Renamed to followPath")]]
	static frc2::CommandPtr followPathWithEvents(
			std::shared_ptr<PathPlannerPath> path) {
		return followPath(path);
	}

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

	/**
	 * Build a command to pathfind to a given pose. If not using a holonomic drivetrain, the pose
	 * rotation and rotation delay distance will have no effect.
	 *
	 * @param pose The pose to pathfind to
	 * @param constraints The constraints to use while pathfinding
	 * @param goalEndVelocity The goal end velocity of the robot when reaching the target pose
	 * @return A command to pathfind to a given pose
	 */
	static frc2::CommandPtr pathfindToPose(frc::Pose2d pose,
			PathConstraints constraints, units::meters_per_second_t goalEndVel =
					0_mps);

	/**
	 * Build a command to pathfind to a given pose that will be flipped based on the value of the path
	 * flipping supplier when this command is run. If not using a holonomic drivetrain, the pose
	 * rotation and rotation delay distance will have no effect.
	 *
	 * @param pose The pose to pathfind to. This will be flipped if the path flipping supplier returns
	 *     true
	 * @param constraints The constraints to use while pathfinding
	 * @param goalEndVelocity The goal end velocity of the robot when reaching the target pose
	 * @return A command to pathfind to a given pose
	 */
	static frc2::CommandPtr pathfindToPoseFlipped(frc::Pose2d pose,
			PathConstraints constraints, units::meters_per_second_t goalEndVel =
					0_mps) {
		return frc2::cmd::Either(
				pathfindToPose(GeometryUtil::flipFieldPose(pose), constraints,
						goalEndVel),
				pathfindToPose(pose, constraints, goalEndVel), m_shouldFlipPath);
	}

	/**
	 * Build a command to pathfind to a given path, then follow that path. If not using a holonomic
	 * drivetrain, the pose rotation delay distance will have no effect.
	 *
	 * @param goalPath The path to pathfind to, then follow
	 * @param pathfindingConstraints The constraints to use while pathfinding
	 * @return A command to pathfind to a given path, then follow the path
	 */
	static frc2::CommandPtr pathfindThenFollowPath(
			std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints);

	/**
	 * Create and populate a sendable chooser with all PathPlannerAutos in the project
	 *
	 * @param defaultAutoName The name of the auto that should be the default option. If this is an
	 *     empty string, or if an auto with the given name does not exist, the default option will be
	 *     frc2::cmd::None()
	 * @return SendableChooser populated with all autos
	 */
	static frc::SendableChooser<frc2::Command*> buildAutoChooser(
			std::string defaultAutoName = "");

	/**
	 * Get a vector of all auto names in the project
	 *
	 * @return vector of all auto names
	 */
	static std::vector<std::string> getAllAutoNames();

private:
	static bool m_configured;
	static std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> m_pathFollowingCommandBuilder;
	static std::function<void(frc::Pose2d)> m_resetPose;
	static std::function<bool()> m_shouldFlipPath;

	static std::vector<frc2::CommandPtr> m_autoCommands;

	static bool m_pathfindingConfigured;
	static std::function<
			frc2::CommandPtr(frc::Pose2d, PathConstraints,
					units::meters_per_second_t)> m_pathfindToPoseCommandBuilder;
	static std::function<
			frc2::CommandPtr(std::shared_ptr<PathPlannerPath>, PathConstraints)> m_pathfindThenFollowPathCommandBuilder;
};
}
