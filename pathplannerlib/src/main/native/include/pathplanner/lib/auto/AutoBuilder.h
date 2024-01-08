#pragma once

#include <functional>
#include <frc2/command/CommandPtr.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/controller/RamseteController.h>
#include <memory>
#include <wpi/json.h>
#include <wpi/array.h>
#include <string>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/util/HolonomicPathFollowerConfig.h"
#include "pathplanner/lib/util/ReplanningConfig.h"

namespace pathplanner {
class AutoBuilder {
public:
	/**
	 * Configures the AutoBuilder for a holonomic drivetrain.
	 *
	 * @param poseSupplier a function that returns the robot's current pose
	 * @param resetPose a function used for resetting the robot's pose
	 * @param robotRelativeSpeedsSupplier a function that returns the robot's current robot relative chassis speeds
	 * @param robotRelativeOutput a function for setting the robot's robot-relative chassis speeds
	 * @param config HolonomicPathFollowerConfig for configuring the
	 *     path following commands
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem a pointer to the subsystem for the robot's drive
	 */
	static void configureHolonomic(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			HolonomicPathFollowerConfig config,
			std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder for a differential drivetrain using a RAMSETE path follower.
	 *
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param resetPose a consumer for resetting the robot's pose
	 * @param speedsSupplier a supplier for the robot's current chassis speeds
	 * @param output a consumer for setting the robot's chassis speeds
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem the subsystem for the robot's drive
	 */
	static void configureRamsete(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder for a differential drivetrain using a RAMSETE path follower.
	 *
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param resetPose a consumer for resetting the robot's pose
	 * @param speedsSupplier a supplier for the robot's current chassis speeds
	 * @param output a consumer for setting the robot's chassis speeds
	 * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
	 *     aggressive like a proportional term.
	 * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
	 *     more damping in response.
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem the subsystem for the robot's drive
	 */
	static void configureRamsete(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<frc::RamseteController::b_unit> b,
			units::unit_t<frc::RamseteController::zeta_unit> zeta,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder for a differential drivetrain using a LTVUnicycleController path
	 * follower.
	 *
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param resetPose a consumer for resetting the robot's pose
	 * @param speedsSupplier a supplier for the robot's current chassis speeds
	 * @param output a consumer for setting the robot's chassis speeds
	 * @param qelems The maximum desired error tolerance for each state.
	 * @param relems The maximum desired control effort for each input.
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem the subsystem for the robot's drive
	 */
	static void configureLTV(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelms,
			const wpi::array<double, 2> &Relms, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder for a differential drivetrain using a LTVUnicycleController path
	 * follower.
	 *
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param resetPose a consumer for resetting the robot's pose
	 * @param speedsSupplier a supplier for the robot's current chassis speeds
	 * @param output a consumer for setting the robot's chassis speeds
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Supplier that determines if paths should be flipped to the other side of
	 *     the field. This will maintain a global blue alliance origin.
	 * @param driveSubsystem the subsystem for the robot's drive
	 */
	static void configureLTV(std::function<frc::Pose2d()> poseSupplier,
			std::function<void(frc::Pose2d)> resetPose,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Subsystem *driveSubsystem);

	/**
	 * Configures the AutoBuilder with custom path following command builder. Building pathfinding commands is not supported when using a custom path following command builder.
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
	 * @param rotationDelayDistance The distance the robot should move from the start position before
	 *     attempting to rotate to the final rotation
	 * @return A command to pathfind to a given pose
	 */
	static frc2::CommandPtr pathfindToPose(frc::Pose2d pose,
			PathConstraints constraints, units::meters_per_second_t goalEndVel =
					0_mps, units::meter_t rotationDelayDistance = 0_m);

	/**
	 * Build a command to pathfind to a given path, then follow that path. If not using a holonomic
	 * drivetrain, the pose rotation delay distance will have no effect.
	 *
	 * @param goalPath The path to pathfind to, then follow
	 * @param pathfindingConstraints The constraints to use while pathfinding
	 * @param rotationDelayDistance The distance the robot should move from the start position before
	 *     attempting to rotate to the final rotation
	 * @return A command to pathfind to a given path, then follow the path
	 */
	static frc2::CommandPtr pathfindThenFollowPath(
			std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			units::meter_t rotationDelayDistance = 0_m);

private:
	static bool m_configured;
	static std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> m_pathFollowingCommandBuilder;
	static std::function<frc::Pose2d()> m_getPose;
	static std::function<void(frc::Pose2d)> m_resetPose;
	static std::function<bool()> m_shouldFlipPath;

	static bool m_pathfindingConfigured;
	static std::function<
			frc2::CommandPtr(frc::Pose2d, PathConstraints,
					units::meters_per_second_t, units::meter_t)> m_pathfindToPoseCommandBuilder;
	static std::function<
			frc2::CommandPtr(std::shared_ptr<PathPlannerPath>, PathConstraints,
					units::meter_t)> m_pathfindThenFollowPathCommandBuilder;
};
}
