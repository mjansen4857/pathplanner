#pragma once

#include "pathplanner/lib/PathPlannerTrajectory.h"
#include "pathplanner/lib/PathConstraints.h"
#include "pathplanner/lib/PathPoint.h"
#include <units/velocity.h>
#include <units/acceleration.h>
#include <string>
#include <vector>
#include <initializer_list>
#include <wpi/json.h>

namespace pathplanner {
class PathPlanner {
public:
	static double resolution;

	/**
	 * @brief Load a path file from storage
	 *
	 * @param name The name of the path to load
	 * @param constraints The max velocity and acceleration of the path
	 * @param reversed Should the robot follow the path reversed
	 * @return The generated path
	 */
	static PathPlannerTrajectory loadPath(std::string const &name,
			PathConstraints const constraints, bool const reversed = false);

	/**
	 * @brief Load a path file from storage
	 *
	 * @param name The name of the path to load
	 * @param maxVel Max velocity of the path
	 * @param maxAccel Max acceleration of the path
	 * @param reversed Should the robot follow the path reversed
	 * @return The generated path
	 */
	static PathPlannerTrajectory loadPath(std::string const &name,
			units::meters_per_second_t const maxVel,
			units::meters_per_second_squared_t const maxAccel,
			bool const reversed = false) {
		return loadPath(name, PathConstraints(maxVel, maxAccel), reversed);
	}

	/**
	 * @brief Load a path file from storage as a path group. This will separate the path into multiple paths based on the waypoints marked as "stop points"
	 *
	 * @param name The name of the path group to load
	 * @param constraints Initializer list of path constraints for each path in the group. This requires at least one path constraint. If less constraints than paths are provided, the last constraint will be used for the rest of the paths.
	 * @param reversed Should the robot follow the path group reversed
	 * @return Vector of all generated paths in the group
	 */
	static std::vector<PathPlannerTrajectory> loadPathGroup(
			std::string const &name,
			std::initializer_list<PathConstraints> const constraints,
			bool const reversed = false);

	/**
	 * @brief Load a path file from storage as a path group. This will separate the path into multiple paths based on the waypoints marked as "stop points"
	 *
	 * @param name The name of the path group to load
	 * @param constraints Vector of path constraints for each path in the group. This requires at least one path constraint. If less constraints than paths are provided, the last constraint will be used for the rest of the paths.
	 * @param reversed Should the robot follow the path group reversed
	 * @return Vector of all generated paths in the group
	 */
	static std::vector<PathPlannerTrajectory> loadPathGroup(
			std::string const &name,
			std::vector<PathConstraints> const constraints,
			bool const reversed = false);

	/**
	 * @brief Load a path file from storage as a path group. This will separate the path into multiple paths based on the waypoints marked as "stop points"
	 *
	 * @param name The name of the path group to load
	 * @param maxVel Max velocity of every path in the group
	 * @param maxAccel Max acceleration of every path in the group
	 * @param reversed Should the robot follow the path group reversed
	 * @return Vector of all generated paths in the group
	 */
	static std::vector<PathPlannerTrajectory> loadPathGroup(
			std::string const &name, units::meters_per_second_t const maxVel,
			units::meters_per_second_squared_t const maxAccel,
			bool const reversed = false) {
		return loadPathGroup(name, { PathConstraints(maxVel, maxAccel) },
				reversed);
	}

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param constraints The max velocity and max acceleration of the path
	 * @param reversed Should the robot follow this path reversed
	 * @param points Points in the path
	 * @return The generated path
	 */
	static PathPlannerTrajectory generatePath(PathConstraints const constraints,
			bool const reversed, std::vector<PathPoint> const points);

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param maxVel The max velocity of the path
	 * @param maxAccel The max acceleration of the path
	 * @param reversed Should the robot follow this path reversed
	 * @param points Points in the path
	 * @return The generated path
	 */
	[[deprecated("Use generatePath(PathConstraints, bool, std::vector<PathPoint>) instead")]]
	static PathPlannerTrajectory generatePath(
			units::meters_per_second_t const maxVel,
			units::meters_per_second_squared_t const maxAccel,
			bool const reversed, std::vector<PathPoint> const points) {
		return generatePath(PathConstraints { maxVel, maxAccel }, reversed,
				points);
	}

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param constraints The max velocity and max acceleration of the path
	 * @param reversed Should the robot follow this path reversed
	 * @param points Points in the path
	 * @return The generated path
	 */
	static PathPlannerTrajectory generatePath(PathConstraints const constraints,
			std::vector<PathPoint> const points) {
		return generatePath(constraints, false, points);
	}

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param maxVel The max velocity of the path
	 * @param maxAccel The max acceleration of the path
	 * @param points Points in the path
	 * @return The generated path
	 */
	[[deprecated("Use generatePath(PathConstraints, std::vector<PathPoint>) instead")]]
	static PathPlannerTrajectory generatePath(
			units::meters_per_second_t const maxVel,
			units::meters_per_second_squared_t const maxAccel,
			std::vector<PathPoint> const points) {
		return generatePath(PathConstraints { maxVel, maxAccel }, points);
	}

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param constraints The max velocity and max acceleration of the path
	 * @param reversed Should the robot follow this path reversed
	 * @param point1 First point in the path
	 * @param point2 Second point in the path
	 * @param points Remaining points in the path
	 * @return The generated path
	 */
	static PathPlannerTrajectory generatePath(PathConstraints const constraints,
			bool const reversed, PathPoint const point1, PathPoint const point2,
			std::initializer_list<PathPoint> const points = { });

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param maxVel The max velocity of the path
	 * @param maxAccel The max acceleration of the path
	 * @param reversed Should the robot follow this path reversed
	 * @param point1 First point in the path
	 * @param point2 Second point in the path
	 * @param points Remaining points in the path
	 * @return The generated path
	 */
	[[deprecated("Use generatePath(PathConstraints, bool, PathPoint, PathPoint, std::initalizer_list<PathPoint>) instead.")]]
	static PathPlannerTrajectory generatePath(
			units::meters_per_second_t const maxVel,
			units::meters_per_second_squared_t const maxAccel,
			bool const reversed, PathPoint const point1, PathPoint const point2,
			std::initializer_list<PathPoint> const points = { }) {
		return generatePath(PathConstraints(maxVel, maxAccel), reversed, point1,
				point2, points);
	}

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param constraints The max velocity and max acceleration of the path
	 * @param point1 First point in the path
	 * @param point2 Second point in the path
	 * @param points Remaining points in the path
	 * @return The generated path
	 */
	static PathPlannerTrajectory generatePath(PathConstraints const constraints,
			PathPoint const point1, PathPoint const point2,
			std::initializer_list<PathPoint> const points = { }) {
		return generatePath(constraints, false, point1, point2, points);
	}

	/**
	 * @brief Generate a path on-the-fly from a list of points
	 * As you can't see the path in the GUI when using this method, make sure you have a good idea
	 * of what works well and what doesn't before you use this method in competition. Points positioned in weird
	 * configurations such as being too close together can lead to really janky paths.
	 *
	 * @param maxVel The max velocity of the path
	 * @param maxAccel The max acceleration of the path
	 * @param point1 First point in the path
	 * @param point2 Second point in the path
	 * @param points Remaining points in the path
	 * @return The generated path
	 */
	[[deprecated("Use generatePath(PathConstraints, PathPoint, PathPoint, std::initializer_list<PathPoint>) instead.")]]
	static PathPlannerTrajectory generatePath(
			units::meters_per_second_t const maxVel,
			units::meters_per_second_squared_t const maxAccel,
			PathPoint const point1, PathPoint const point2,
			std::initializer_list<PathPoint> const points = { }) {
		return generatePath(PathConstraints(maxVel, maxAccel), false, point1,
				point2, points);
	}

	/**
	 * Load path constraints from a path file in storage. This can be used to change path max vel/accel in the
	 * GUI instead of updating and rebuilding code. This requires that max velocity and max acceleration have been
	 * explicitly set in the GUI.
	 *
	 * Throws a runtime error if constraints are not present in the file
	 * @param name The name of the path to load constraints from
	 * @return The constraints from the path file
	 */
	static PathConstraints getConstraintsFromPath(std::string const &name);

private:
	static std::vector<PathPlannerTrajectory::Waypoint> getWaypointsFromJson(
			wpi::json json);
	static std::vector<PathPlannerTrajectory::EventMarker> getMarkersFromJson(
			wpi::json json);
	static int indexOfWaypoint(
			std::vector<PathPlannerTrajectory::Waypoint> const &waypoints,
			PathPlannerTrajectory::Waypoint const waypoint);
};
}
