#pragma once

#include "pathplanner/lib/path/RotationTarget.h"
#include "pathplanner/lib/path/ConstraintsZone.h"
#include "pathplanner/lib/path/EventMarker.h"
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/path/GoalEndState.h"
#include "pathplanner/lib/path/PathPoint.h"
#include <vector>
#include <frc/geometry/Translation2d.h>
#include <wpi/json.h>
#include <string>
#include <units/length.h>
#include <memory>

namespace pathplanner {
class PathPlannerPath {
public:
	/**
	 * Create a new path planner path
	 *
	 * @param bezierPoints List of points representing the cubic Bezier curve of the path
	 * @param holonomicRotations List of rotation targets along the path
	 * @param constraintZones List of constraint zones along the path
	 * @param eventMarkers List of event markers along the path
	 * @param globalConstraints The global constraints of the path
	 * @param goalEndState The goal end state of the path
	 * @param reversed Should the robot follow the path reversed (differential drive only)
	 */
	PathPlannerPath(std::vector<frc::Translation2d> bezierPoints,
			std::vector<RotationTarget> rotationTargets,
			std::vector<ConstraintsZone> constraintZones,
			std::vector<EventMarker> eventMarkers,
			PathConstraints globalConstraints, GoalEndState goalEndState,
			bool reversed);

	void hotReload(const wpi::json &json);

	/**
	 * Load a path from a path file in storage
	 *
	 * @param pathName The name of the path to load
	 * @return shared ptr to the PathPlannerPath created from the given file name
	 */
	static std::shared_ptr<PathPlannerPath> fromPathFile(std::string pathName);

	/**
	 * Get the constraints for a point along the path
	 *
	 * @param idx Index of the point to get constraints for
	 * @return The constraints that should apply to the point
	 */
	inline PathConstraints getConstraintsForPoint(size_t idx) {
		return getPoint(idx).constraints.value_or(m_globalConstraints);
	}

	/**
	 * Create a path planner path from pre-generated path points. This is used internally, and you
	 * likely should not use this
	 */
	static PathPlannerPath fromPathPoints(std::vector<PathPoint> pathPoints,
			PathConstraints globalConstraints, GoalEndState goalEndState);

	/** Generate path points for a path. This is used internally and should not be used directly. */
	static std::vector<PathPoint> createPath(
			std::vector<frc::Translation2d> bezierPoints,
			std::vector<RotationTarget> holonomicRotations,
			std::vector<ConstraintsZone> constraintZones);

	/**
	 * Get all the path points in this path
	 *
	 * @return Path points in the path
	 */
	constexpr const std::vector<PathPoint>& getAllPathPoints() const {
		return m_allPoints;
	}

	/**
	 * Get the number of points in this path
	 *
	 * @return Number of points in the path
	 */
	inline size_t numPoints() const {
		return m_allPoints.size();
	}

	/**
	 * Get a specific point along this path
	 *
	 * @param index Index of the point to get
	 * @return The point at the given index
	 */
	inline const PathPoint& getPoint(size_t index) const {
		return m_allPoints[index];
	}

	/**
	 * Get the global constraints for this path
	 *
	 * @return Global constraints that apply to this path
	 */
	constexpr const PathConstraints& getGlobalConstraints() const {
		return m_globalConstraints;
	}

	/**
	 * Get the goal end state of this path
	 *
	 * @return The goal end state
	 */
	constexpr const GoalEndState& getGoalEndState() const {
		return m_goalEndState;
	}

	/**
	 * Get all the event markers for this path
	 *
	 * @return The event markers for this path
	 */
	constexpr std::vector<EventMarker>& getEventMarkers() {
		return m_eventMarkers;
	}

	/**
	 * Should the path be followed reversed (differential drive only)
	 * 
	 * @return True if reversed
	 */
	constexpr bool isReversed() const {
		return m_reversed;
	}

private:
	PathPlannerPath(PathConstraints globalConstraints,
			GoalEndState goalEndState);

	static PathPlannerPath fromJson(const wpi::json &json);

	static std::vector<frc::Translation2d> bezierPointsFromWaypointsJson(
			const wpi::json &json);

	static frc::Translation2d pointFromJson(const wpi::json &json);

	void precalcValues();

	static units::meter_t getCurveRadiusAtPoint(size_t index,
			std::vector<PathPoint> &points);

	std::vector<frc::Translation2d> m_bezierPoints;
	std::vector<RotationTarget> m_rotationTargets;
	std::vector<ConstraintsZone> m_constraintZones;
	std::vector<EventMarker> m_eventMarkers;
	PathConstraints m_globalConstraints;
	GoalEndState m_goalEndState;
	std::vector<PathPoint> m_allPoints;
	bool m_reversed;
};
}
