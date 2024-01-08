#pragma once

#include "pathplanner/lib/path/RotationTarget.h"
#include "pathplanner/lib/path/ConstraintsZone.h"
#include "pathplanner/lib/path/EventMarker.h"
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/path/GoalEndState.h"
#include "pathplanner/lib/path/PathPoint.h"
#include "pathplanner/lib/path/PathSegment.h"
#include "pathplanner/lib/path/PathPlannerTrajectory.h"
#include <vector>
#include <frc/geometry/Translation2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <wpi/json.h>
#include <string>
#include <units/length.h>
#include <memory>
#include <initializer_list>

namespace pathplanner {
class PathPlannerPath: public std::enable_shared_from_this<PathPlannerPath> {
public:
	bool preventFlipping = false;

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
			bool reversed, frc::Rotation2d previewStartingRotation =
					frc::Rotation2d());

	/**
	 * Simplified constructor to create a path with no rotation targets, constraint zones, or event
	 * markers.
	 *
	 * <p>You likely want to use bezierFromPoses to create the bezier points.
	 *
	 * @param bezierPoints List of points representing the cubic Bezier curve of the path
	 * @param constraints The global constraints of the path
	 * @param goalEndState The goal end state of the path
	 * @param reversed Should the robot follow the path reversed (differential drive only)
	 */
	PathPlannerPath(std::vector<frc::Translation2d> bezierPoints,
			PathConstraints constraints, GoalEndState goalEndState,
			bool reversed = false) : PathPlannerPath(bezierPoints,
			std::vector<RotationTarget>(), std::vector<ConstraintsZone>(),
			std::vector<EventMarker>(), constraints, goalEndState, reversed) {
	}

	/**
	 * USED INTERNALLY. DO NOT USE!
	 */
	PathPlannerPath(PathConstraints constraints, GoalEndState goalEndState);

	void hotReload(const wpi::json &json);

	/**
	 * Create the bezier points necessary to create a path using a list of poses
	 *
	 * @param poses List of poses. Each pose represents one waypoint.
	 * @return Bezier points
	 */
	static std::vector<frc::Translation2d> bezierFromPoses(
			std::vector<frc::Pose2d> poses);

	/**
	 * Load a path from a path file in storage
	 *
	 * @param pathName The name of the path to load
	 * @return shared ptr to the PathPlannerPath created from the given file name
	 */
	static std::shared_ptr<PathPlannerPath> fromPathFile(std::string pathName);

	/**
	 * Load a Choreo trajectory as a PathPlannerPath
	 *
	 * @param trajectoryName The name of the Choreo trajectory to load. This should be just the name
	 *     of the trajectory. The trajectories must be located in the "deploy/choreo" directory.
	 * @return PathPlannerPath created from the given Choreo trajectory file
	 */
	static std::shared_ptr<PathPlannerPath> fromChoreoTrajectory(
			std::string trajectoryName);

	/**
	 * Get the differential pose for the start point of this path
	 *
	 * @return Pose at the path's starting point
	 */
	frc::Pose2d getStartingDifferentialPose();

	/**
	 * Get the starting pose for the holomonic path based on the preview settings.
	 *
	 * NOTE: This should only be used for the first path you are running, and only if you are not using an auto mode file. Using this pose to reset the robots pose between sequential paths will cause a loss of accuracy.
	 *
	 * @return Pose at the path's starting point
	 */
	frc::Pose2d getPreviewStartingHolonomicPose();

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
	static std::shared_ptr<PathPlannerPath> fromPathPoints(
			std::vector<PathPoint> pathPoints,
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

	/**
	 * Check if this path is loaded from a Choreo trajectory
	 *
	 * @return True if this path is from choreo, false otherwise
	 */
	constexpr bool isChoreoPath() const {
		return m_isChoreoPath;
	}

	inline PathPlannerTrajectory getTrajectory(
			frc::ChassisSpeeds startingSpeeds,
			frc::Rotation2d startingRotation) {
		if (m_isChoreoPath) {
			return m_choreoTrajectory;
		} else {
			return PathPlannerTrajectory(shared_from_this(), startingSpeeds,
					startingRotation);
		}
	}

	/**
	 * Replan this path based on the current robot position and speeds
	 *
	 * @param startingPose New starting pose for the replanned path
	 * @param currentSpeeds Current chassis speeds of the robot
	 * @return The replanned path
	 */
	std::shared_ptr<PathPlannerPath> replan(const frc::Pose2d startingPose,
			const frc::ChassisSpeeds currentSpeeds);

	/**
	 * Flip a path to the other side of the field, maintaining a global blue alliance origin
	 *
	 * @return The flipped path
	 */
	std::shared_ptr<PathPlannerPath> flipPath();

private:
	static std::shared_ptr<PathPlannerPath> fromJson(const wpi::json &json);

	static std::vector<frc::Translation2d> bezierPointsFromWaypointsJson(
			const wpi::json &json);

	static frc::Translation2d pointFromJson(const wpi::json &json);

	void precalcValues();

	static units::meter_t getCurveRadiusAtPoint(size_t index,
			std::vector<PathPoint> &points);

	/**
	 * Map a given percentage/waypoint relative position over 2 segments
	 *
	 * @param pct The percent to map
	 * @param seg1Pct The percentage of the 2 segments made up by the first segment
	 * @return The waypoint relative position over the 2 segments
	 */
	static double mapPct(double pct, double seg1Pct) {
		double mappedPct;
		if (pct <= seg1Pct) {
			// Map to segment 1
			mappedPct = pct / seg1Pct;
		} else {
			// Map to segment 2
			mappedPct = 1.0 + ((pct - seg1Pct) / (1.0 - seg1Pct));
		}

		return std::round(mappedPct * (1.0 / PathSegment::RESOLUTION))
				/ (1.0 / PathSegment::RESOLUTION);
	}

	static inline units::meter_t positionDelta(const frc::Translation2d &a,
			const frc::Translation2d &b) {
		frc::Translation2d delta = a - b;

		return units::math::abs(delta.X()) + units::math::abs(delta.Y());
	}

	std::vector<frc::Translation2d> m_bezierPoints;
	std::vector<RotationTarget> m_rotationTargets;
	std::vector<ConstraintsZone> m_constraintZones;
	std::vector<EventMarker> m_eventMarkers;
	PathConstraints m_globalConstraints;
	GoalEndState m_goalEndState;
	std::vector<PathPoint> m_allPoints;
	bool m_reversed;
	frc::Rotation2d m_previewStartingRotation;
	bool m_isChoreoPath;
	PathPlannerTrajectory m_choreoTrajectory;

	static int m_instances;
};
}
