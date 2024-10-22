#pragma once

#include <functional>
#include <frc2/command/CommandPtr.h>
#include <frc2/command/Commands.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/controller/RamseteController.h>
#include <vector>
#include <map>
#include <frc2/command/Command.h>
#include <frc/smartdashboard/SendableChooser.h>
#include <memory>
#include <wpi/json.h>
#include <wpi/array.h>
#include <string>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/config/RobotConfig.h"
#include "pathplanner/lib/controllers/PathFollowingController.h"
#include "pathplanner/lib/util/DriveFeedforwards.h"
#include "pathplanner/lib/util/FlippingUtil.h"

namespace pathplanner {

class PathPlannerAuto;

class AutoBuilder {
public:
	/**
	 * Configures the AutoBuilder for using PathPlanner's built-in commands.
	 *
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param resetPose a function used for resetting the robot's pose
	 * @param robotRelativeSpeedsSupplier a function that returns the robot's current robot relative chassis speeds
	 * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
	 *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
	 *     using a differential drive, they will be in L, R order.
	 *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
	 *     module states, you will need to reverse the feedforwards for modules that have been flipped
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem a pointer to the subsystem for the robot's drive
	 */
	static void configure(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(const frc::Pose2d&)> resetPose,
			std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
			std::function<
					void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder for using PathPlanner's built-in commands.
	 *
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param resetPose a function used for resetting the robot's pose
	 * @param robotRelativeSpeedsSupplier a function that returns the robot's current robot relative chassis speeds
	 * @param output Output function that accepts robot-relative ChassisSpeeds.
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem a pointer to the subsystem for the robot's drive
	 */
	static inline void configure(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(const frc::Pose2d&)> resetPose,
			std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
			std::function<void(const frc::ChassisSpeeds&)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem) {
		configure(poseSupplier, resetPose, robotRelativeSpeedsSupplier,
				[output](auto &&speeds, auto &&feedforwards) {
					output(speeds);
				}, std::move(controller), std::move(robotConfig),
				shouldFlipPath, driveSubsystem);
	}

	/**
	 * Configures the AutoBuilder with custom path following command builder. Building pathfinding
	 * commands is not supported if using a custom command builder. Custom path following commands
	 * will not have the path flipped for them, and event markers will not be triggered automatically.
	 *
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param pathFollowingCommandBuilder a function that builds a command to follow a given path
	 * @param resetPose a function for resetting the robot's pose
	 * @param isHolonomic Does the robot have a holonomic drivetrain
	 * @param shouldFlipPose Supplier that determines if the starting pose should be flipped to the
	 *     other side of the field. This will maintain a global blue alliance origin. NOTE: paths will
	 *     not be flipped when configured with a custom path following command. Flipping the paths
	 *     must be handled in your command.
	 */
	static void configureCustom(std::function<frc::Pose2d()> poseSupplier,
			std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> pathFollowingCommandBuilder,
			std::function<void(const frc::Pose2d&)> resetPose, bool isHolonomic,
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
	 * Returns whether the AutoBuilder has been configured for a holonomic drivetrain.
	 *
	 * @return true if the AutoBuilder has been configured for a holonomic drivetrain, false otherwise
	 */
	static inline bool isHolonomic() {
		return m_isHolonomic;
	}

	/**
	 * Get the current robot pose
	 *
	 * @return Current robot pose
	 */
	static inline frc::Pose2d getCurrentPose() {
		return m_poseSupplier();
	}

	/**
	 * Get if a path or field position should currently be flipped
	 *
	 * @return True if path/positions should be flipped
	 */
	static inline bool shouldFlip() {
		return m_shouldFlipPath();
	}

	/**
	 * Builds a command to follow a path with event markers.
	 *
	 * @param path the path to follow
	 * @return a path following command with events for the given path
	 */
	static frc2::CommandPtr followPath(std::shared_ptr<PathPlannerPath> path);

	/**
	 * Builds an auto command for the given auto name.
	 *
	 * @param autoName the name of the auto to build
	 * @return an auto command for the given auto name
	 */
	static inline frc2::CommandPtr buildAuto(std::string autoName);

	/**
	 * Create a command to reset the robot's odometry to a given blue alliance pose
	 * 
	 * @param bluePose The pose to reset to, relative to blue alliance origin
	 * @return Command to reset the robot's odometry
	 */
	static frc2::CommandPtr resetOdom(frc::Pose2d bluePose);

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
				pathfindToPose(FlippingUtil::flipFieldPose(pose), constraints,
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
	 * Modifies the existing references that buildAutoChooser returns in SendableChooser to the most recent in the pathplanner/auto deploy directory
	 * 
	 * Loads PathPlannerAutos from deploy/pathplanner/auto directory (recursively) on every call
	 * Adds new auto paths from the pathplanner/auto deploy directory however doesn't remove autos already previously loaded
	 */

	static void regenerateSendableReferences();

	/**
	 * Populate a sendable chooser with all loaded PathPlannerAutos in the project in pathplanner/auto deploy directory (recursively)
	 * Loads PathPlannerAutos from deploy/pathplanner/auto directory (recursively) on first call
	 *
	 * @param defaultAutoName The name of the auto that should be the default option. If this is an
	 *     empty string, or if an auto with the given name does not exist, the default option will be
	 *     frc2::cmd::None()
	 * @return SendableChooser populated with all autos
	 */
	static frc::SendableChooser<frc2::Command*> buildAutoChooser(
			std::string defaultAutoName = "");

	/**
	 * Populate a sendable chooser with all loaded PathPlannerAutos in the project in pathplanner/auto deploy directory (recursively)
	 * Loads PathPlannerAutos from deploy/pathplanner/auto directory (recursively) on first call
	 * Filters certain PathPlannerAuto bases on their properties
	 *
	 * @param filter Function which filters the auto commands out, returning true allows the command to be uploaded to sendable chooser 
	 * 		while returning false prevents it from being added. 
	 * 		autoCommand, const reference to PathPlannerAuto command which was generated
	 * @param defaultAutoName The name of the auto that should be the default option. If this is an
	 *     empty string, or if an auto with the given name does not exist, the default option will be
	 *     frc2::cmd::None(), defaultAutoName doesn't get filter out and always is in final sendable chooser (if found)
	 * @return SendableChooser populated with all autos
	 */
	static frc::SendableChooser<frc2::Command*> buildAutoChooserFilter(
			std::function<bool(const PathPlannerAuto&)> filter,
			std::string defaultAutoName = "");

	/**
	 * Populate a sendable chooser with all loaded PathPlannerAutos in the project in pathplanner/auto deploy directory (recursively)
	 * Loads PathPlannerAutos from deploy/pathplanner/auto directory (recursively) on first call
	 * Filters certain PathPlannerAuto bases on their properties and their filepath
	 *
	 * @param filter Function which filters the auto commands out, returning true allows the command to be uploaded to sendable chooser 
	 * 		while returning false prevents it from being added. 
	 * 		autoCommand, const reference to PathPlannerAuto command which was generated
	 * 		autoPath, path to the autoCommand relative to pathplanner/auto deploy directory with extension ".auto"
	 * @param defaultAutoName The name of the auto that should be the default option. If this is an
	 *     empty string, or if an auto with the given name does not exist, the default option will be
	 *     frc2::cmd::None(), defaultAutoName doesn't get filter out and always is in final sendable chooser (if found)
	 * @return SendableChooser populated with all autos
	 */
	static frc::SendableChooser<frc2::Command*> buildAutoChooserFilterPath(
			std::function<bool(const PathPlannerAuto&, std::filesystem::path)> filter,
			std::string defaultAutoName = "");

	/**
	 * Get a vector of all auto names in the pathplanner/auto deploy directory (recursively)
	 *
	 * @return Vector of strings containing all auto names
	 */
	static std::vector<std::string> getAllAutoNames();

	/**
	 * Get a vector of all auto paths in the pathplanner/auto deploy directory (recursively)
	 * 
	 * @return Vector of paths relative to autos deploy directory
	 */
	static std::vector<std::filesystem::path> getAllAutoPaths();

private:
	static bool m_configured;
	static std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> m_pathFollowingCommandBuilder;
	static std::function<frc::Pose2d()> m_poseSupplier;
	static std::function<void(const frc::Pose2d&)> m_resetPose;
	static std::function<bool()> m_shouldFlipPath;
	static bool m_isHolonomic;

	static bool m_commandRefsGeneratedForSendable;
	static frc2::CommandPtr m_noneCommand;
	static std::map<std::filesystem::path, frc2::CommandPtr> m_autoCommands;

	static bool m_pathfindingConfigured;
	static std::function<
			frc2::CommandPtr(frc::Pose2d, PathConstraints,
					units::meters_per_second_t)> m_pathfindToPoseCommandBuilder;
	static std::function<
			frc2::CommandPtr(std::shared_ptr<PathPlannerPath>, PathConstraints)> m_pathfindThenFollowPathCommandBuilder;
};
}
