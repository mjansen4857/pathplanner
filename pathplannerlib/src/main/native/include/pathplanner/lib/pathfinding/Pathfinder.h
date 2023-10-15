#pragma once

#include "pathplanner/lib/path/GoalEndState.h"
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/path/PathPlannerPath.h"
#include <vector>
#include <utility>
#include <frc/geometry/Translation2d.h>
#include <memory>

namespace pathplanner {
class Pathfinder {
public:
	virtual ~Pathfinder() {
	}

	/**
	 * Get if a new path has been calculated since the last time a path was retrieved
	 *
	 * @return True if a new path is available
	 */
	virtual bool isNewPathAvailable() = 0;

	/**
	 * Get the most recently calculated path
	 *
	 * @param constraints The path constraints to use when creating the path
	 * @param goalEndState The goal end state to use when creating the path
	 * @return The PathPlannerPath created from the points calculated by the pathfinder
	 */
	virtual std::shared_ptr<PathPlannerPath> getCurrentPath(
			PathConstraints constraints, GoalEndState goalEndState) = 0;

	/**
	 * Set the start position to pathfind from
	 *
	 * @param startPosition Start position on the field. If this is within an obstacle it will be
	 *     moved to the nearest non-obstacle node.
	 */
	virtual void setStartPosition(const frc::Translation2d &startPosition) = 0;

	/**
	 * Set the goal position to pathfind to
	 *
	 * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
	 *     to the nearest non-obstacle node.
	 */
	virtual void setGoalPosition(const frc::Translation2d &goalPosition) = 0;

	/**
	 * Set the dynamic obstacles that should be avoided while pathfinding.
	 *
	 * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
	 *     opposite corners of a bounding box.
	 * @param currentRobotPos The current position of the robot. This is needed to change the start
	 *     position of the path to properly avoid obstacles
	 */
	virtual void setDynamicObstacles(
			const std::vector<std::pair<frc::Translation2d, frc::Translation2d>> &obs,
			const frc::Translation2d &currentRobotPos) = 0;
};
}
