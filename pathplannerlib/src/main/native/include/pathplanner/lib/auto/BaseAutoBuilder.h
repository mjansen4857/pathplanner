#pragma once

#include <functional>
#include <unordered_map>
#include <frc/geometry/Pose2d.h>
#include <frc2/command/CommandBase.h>

#include "pathplanner/lib/PathPlannerTrajectory.h"

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
	frc2::CommandPtr followPathGroup(
			std::vector<PathPlannerTrajectory> pathGroup);

	/**
	 * Create a path following command that will trigger events as it goes.
	 *
	 * @param trajectory The trajectory to follow
	 * @return Command that will follow the trajectory and trigger events
	 */
	frc2::CommandPtr followPathWithEvents(PathPlannerTrajectory trajectory);

	/**
	 * Create a sequential command group that will follow each path in a path group and trigger events
	 * as it goes.
	 *
	 * @param pathGroup The path group to follow
	 * @return Command for following all paths in the group
	 */
	frc2::CommandPtr followPathGroupWithEvents(
			std::vector<PathPlannerTrajectory> pathGroup);

	/**
	 * Create a command that will call the resetPose consumer with the first pose of the path. This is
	 * usually only used once at the beginning of auto.
	 *
	 * @param trajectory The trajectory to reset the pose for
	 * @return Command that will reset the pose
	 */
	frc2::CommandPtr resetPose(PathPlannerTrajectory trajectory);

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
	 */
	BaseAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			DriveTrainType drivetrainType);

	std::function<frc::Pose2d()> m_pose;
	std::function<void(frc::Pose2d)> m_resetPose;
	std::unordered_map<std::string, std::shared_ptr<frc2::Command>> m_eventMap;
	DriveTrainType m_drivetrainType;
};
}
