#pragma once

#include <functional>
#include <unordered_map>
#include <frc/geometry/Pose2d.h>
#include <frc2/command/CommandBase.h>
#include <frc/controller/PIDController.h>

#include "pathplanner/lib/PathPlannerTrajectory.h"
#include "pathplanner/lib/auto/PIDConstants.h"

namespace pathplanner {
class BaseAutoBuilder {
public:
	/**
	 * Create a path following command for a given trajectory. This will not trigger any events while
	 * path following.
	 * 
	 * <p>Override this to create auto builders for your custom path following commands.
	 * 
	 * @param trajectory The trajectory to follow
	 * @return A path following command for the given trajectory
	 */
	virtual frc2::CommandPtr followPath(PathPlannerTrajectory trajectory) = 0;

	/**
	 * Create a sequential command group that will follow each path in a path group. This will not
	 * trigger any events while path following.
	 *
	 * @param pathGroup The path group to follow
	 * @return Command for following all paths in the group
	 */
	virtual frc2::CommandPtr followPathGroup(
			std::vector<PathPlannerTrajectory> pathGroup);

	/**
	 * Create a path following command that will trigger events as it goes.
	 *
	 * @param trajectory The trajectory to follow
	 * @return Command that will follow the trajectory and trigger events
	 */
	virtual frc2::CommandPtr followPathWithEvents(
			PathPlannerTrajectory trajectory);

	/**
	 * Create a sequential command group that will follow each path in a path group and trigger events
	 * as it goes. This will not run any stop events.
	 *
	 * @param pathGroup The path group to follow
	 * @return Command for following all paths in the group
	 */
	virtual frc2::CommandPtr followPathGroupWithEvents(
			std::vector<PathPlannerTrajectory> pathGroup);

	/**
	 * Create a command that will call the resetPose consumer with the first pose of the path. This is
	 * usually only used once at the beginning of auto.
	 *
	 * @param trajectory The trajectory to reset the pose for
	 * @return Command that will reset the pose
	 */
	virtual frc2::CommandPtr resetPose(PathPlannerTrajectory trajectory);

	/**
	 * Create a command group to handle all of the commands at a stop event
	 *
	 * @param stopEvent The stop event to create the command group for
	 * @return Command group for the stop event
	 */
	virtual frc2::CommandPtr stopEventGroup(
			PathPlannerTrajectory::StopEvent stopEvent);

	/**
	 * Create a complete autonomous command group. This will reset the robot pose at the begininng of
	 * the first path, follow paths, trigger events during path following, and run commands between
	 * paths with stop events.
	 *
	 * <p>Using this does have its limitations, but it should be good enough for most teams. However,
	 * if you want the auto command to function in a different way, you can create your own class that
	 * extends BaseAutoBuilder and override existing builder methods to create the command group
	 * however you wish.
	 *
	 * @param trajectory Single trajectory to follow during the auto
	 * @return Autonomous command
	 */
	virtual frc2::CommandPtr fullAuto(PathPlannerTrajectory trajectory);

	/**
	 * Create a complete autonomous command group. This will reset the robot pose at the begininng of
	 * the first path, follow paths, trigger events during path following, and run commands between
	 * paths with stop events.
	 *
	 * <p>Using this does have its limitations, but it should be good enough for most teams. However,
	 * if you want the auto command to function in a different way, you can create your own class that
	 * extends BaseAutoBuilder and override existing builder methods to create the command group
	 * however you wish.
	 *
	 * @param pathGroup Path group to follow during the auto
	 * @return Autonomous command
	 */
	virtual frc2::CommandPtr fullAuto(
			std::vector<PathPlannerTrajectory> pathGroup);

protected:
	enum class DriveTrainType {
		HOLONOMIC, STANDARD
	};

	/**
	 * Construct a BaseAutoBuilder
	 *
	 * @param pose A function that supplies the robot pose - use one of the odometry classes
	 *     to provide this.
	 * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
	 *     be called once ath the beginning of an auto.
	 * @param eventMap Event map for triggering events at markers
	 * @param drivetrainType Type of drivetrain the autobuilder is building for
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	BaseAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			DriveTrainType drivetrainType, bool useAllianceColor = false);

	/**
	 * Construct a BaseAutoBuilder
	 *
	 * @param pose A function that supplies the robot pose - use one of the odometry classes
	 *     to provide this.
	 * @param eventMap Event map for triggering events at markers
	 * @param drivetrainType Type of drivetrain the autobuilder is building for
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	BaseAutoBuilder(std::function<frc::Pose2d()> pose,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			DriveTrainType drivetrainType, bool useAllianceColor = false) : BaseAutoBuilder(
			pose, [](frc::Pose2d pose) {
			}, eventMap, drivetrainType, useAllianceColor) {
	}

	/**
	 * Creates a Command Group of events on a stop event, excluding the wait
	 * @param stopEvent The stop event to create the event command group for
	 * @return Command group for the "stop event" events
	 */
	virtual frc2::CommandPtr getStopEventCommands(
			PathPlannerTrajectory::StopEvent stopEvent);

	/**
	 * Wrap an event command, so it can be added to a command group
	 *
	 * @param eventCommand The event command to wrap
	 * @return Wrapped event command
	 */
	virtual frc2::CommandPtr wrappedEventCommand(
			std::shared_ptr<frc2::Command> command);

	static inline frc::PIDController pidControllerFromConstants(
			PIDConstants constants) {
		return frc::PIDController(constants.m_kP, constants.m_kI,
				constants.m_kD, constants.m_period);
	}

	std::function<frc::Pose2d()> m_pose;
	std::function<void(frc::Pose2d)> m_resetPose;
	std::unordered_map<std::string, std::shared_ptr<frc2::Command>> m_eventMap;
	DriveTrainType m_drivetrainType;
	const bool m_useAllianceColor;
};
}
