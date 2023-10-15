#pragma once

#include "pathplanner/lib/pathfinding/Pathfinder.h"
#include <memory>

namespace pathplanner {
class Pathfinding {
public:
	/**
	 * Set the pathfinder that should be used by the path following commands
	 *
	 * @param pathfinder The pathfinder to use
	 */
	static inline void setPathfinder(std::unique_ptr<Pathfinder> pathfinder) {
		Pathfinding::pathfinder = std::move(pathfinder);
	}

	/** Ensure that a pathfinding implementation has been chosen. If not, set it to the default. */
	static void ensureInitialized();

	/**
	 * Get if a new path has been calculated since the last time a path was retrieved
	 *
	 * @return True if a new path is available
	 */
	static inline bool isNewPathAvailable() {
		return pathfinder->isNewPathAvailable();
	}

	/**
	 * Get the most recently calculated path
	 *
	 * @param constraints The path constraints to use when creating the path
	 * @param goalEndState The goal end state to use when creating the path
	 * @return The PathPlannerPath created from the points calculated by the pathfinder
	 */
	static inline std::shared_ptr<PathPlannerPath> getCurrentPath(
			PathConstraints constraints, GoalEndState goalEndState) {
		return pathfinder->getCurrentPath(constraints, goalEndState);
	}

	/**
	 * Set the start position to pathfind from
	 *
	 * @param startPosition Start position on the field. If this is within an obstacle it will be
	 *     moved to the nearest non-obstacle node.
	 */
	static inline void setStartPosition(
			const frc::Translation2d &startPosition) {
		pathfinder->setStartPosition(startPosition);
	}

	/**
	 * Set the goal position to pathfind to
	 *
	 * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
	 *     to the nearest non-obstacle node.
	 */
	static inline void setGoalPosition(const frc::Translation2d &goalPosition) {
		pathfinder->setGoalPosition(goalPosition);
	}

	/**
	 * Set the dynamic obstacles that should be avoided while pathfinding.
	 *
	 * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
	 *     opposite corners of a bounding box.
	 * @param currentRobotPos The current position of the robot. This is needed to change the start
	 *     position of the path if the robot is now within an obstacle.
	 */
	static inline void setDynamicObstacles(
			const std::vector<std::pair<frc::Translation2d, frc::Translation2d>> &obs,
			const frc::Translation2d &currentRobotPos) {
		pathfinder->setDynamicObstacles(obs, currentRobotPos);
	}

private:
	static std::unique_ptr<Pathfinder> pathfinder;
};
}
