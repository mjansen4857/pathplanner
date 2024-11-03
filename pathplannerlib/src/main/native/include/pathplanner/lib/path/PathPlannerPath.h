#pragma once

#include "pathplanner/lib/path/RotationTarget.h"
#include "pathplanner/lib/path/PointTowardsZone.h"
#include "pathplanner/lib/path/ConstraintsZone.h"
#include "pathplanner/lib/path/EventMarker.h"
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/path/IdealStartingState.h"
#include "pathplanner/lib/path/GoalEndState.h"
#include "pathplanner/lib/path/PathPoint.h"
#include "pathplanner/lib/path/Waypoint.h"
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include "pathplanner/lib/config/RobotConfig.h"
#include <vector>
#include <optional>
#include <frc/geometry/Translation2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <wpi/json.h>
#include <string>
#include <unordered_map>
#include <units/length.h>
#include <memory>
#include <initializer_list>

namespace pathplanner {
class PathPlannerPath: public std::enable_shared_from_this<PathPlannerPath> {
public:
	std::string name;
	bool preventFlipping = false;

	/**
	 * Create a new path planner path
	 *
	 * @param waypoints List of waypoints representing the path. For on-the-fly paths, you likely want
	 *     to use waypointsFromPoses to create these.
	 * @param holonomicRotations List of rotation targets along the path
	 * @param pointTowardsZones List of point towards zones along the path
	 * @param constraintZones List of constraint zones along the path
	 * @param eventMarkers List of event markers along the path
	 * @param globalConstraints The global constraints of the path
	 * @param idealStartingState The ideal starting state of the path. Can be nullopt if unknown
	 * @param goalEndState The goal end state of the path
	 * @param reversed Should the robot follow the path reversed (differential drive only)
	 */
	PathPlannerPath(std::vector<Waypoint> waypoints,
			std::vector<RotationTarget> rotationTargets,
			std::vector<PointTowardsZone> pointTowardsZones,
			std::vector<ConstraintsZone> constraintZones,
			std::vector<EventMarker> eventMarkers,
			PathConstraints globalConstraints,
			std::optional<IdealStartingState> idealStartingState,
			GoalEndState goalEndState, bool reversed);

	/**
	 * Simplified constructor to create a path with no rotation targets, constraint zones, or event
	 * markers.
	 *
	 * @param waypoints List of waypoints representing the path. For on-the-fly paths, you likely want
	 *     to use waypointsFromPoses to create these.
	 * @param constraints The global constraints of the path
	 * @param idealStartingState The ideal starting state of the path. Can be nullopt if unknown
	 * @param goalEndState The goal end state of the path
	 * @param reversed Should the robot follow the path reversed (differential drive only)
	 */
	PathPlannerPath(std::vector<Waypoint> waypoints,
			PathConstraints constraints,
			std::optional<IdealStartingState> idealStartingState,
			GoalEndState goalEndState, bool reversed = false) : PathPlannerPath(
			waypoints, std::vector<RotationTarget>(),
			std::vector<PointTowardsZone>(), std::vector<ConstraintsZone>(),
			std::vector<EventMarker>(), constraints, idealStartingState,
			goalEndState, reversed) {
	}

	/**
	 * USED INTERNALLY. DO NOT USE!
	 */
	PathPlannerPath(PathConstraints constraints, GoalEndState goalEndState);

	void hotReload(const wpi::json &json);

	/**
	 * Create the bezier waypoints necessary to create a path using a list of poses
	 *
	 * @param poses List of poses. Each pose represents one waypoint.
	 * @return Bezier curve waypoints
	 */
	static std::vector<Waypoint> waypointsFromPoses(
			std::vector<frc::Pose2d> poses);

	/**
	 * Create the bezier waypoints necessary to create a path using a list of poses
	 *
	 * @param poses List of poses. Each pose represents one waypoint.
	 * @return Bezier curve waypoints
	 */
	[[deprecated("Renamed to waypointsFromPoses")]]
	static inline std::vector<Waypoint> bezierFromPoses(
			std::vector<frc::Pose2d> poses) {
		return waypointsFromPoses(poses);
	}

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
	 * Load a Choreo trajectory as a PathPlannerPath
	 *
	 * @param trajectoryName The name of the Choreo trajectory to load. This should be just the name
	 *     of the trajectory.
	 * @param splitIndex The index of the split to use
	 * @return PathPlannerPath created from the given Choreo trajectory and split index
	 */
	static inline std::shared_ptr<PathPlannerPath> fromChoreoTrajectory(
			std::string trajectoryName, size_t splitIndex) {
		std::string cacheName = trajectoryName + "."
				+ std::to_string(splitIndex);
		if (getChoreoPathCache().contains(cacheName)) {
			return getChoreoPathCache()[cacheName];
		}

		// Path is not in the cache, load the main trajectory to load all splits
		loadChoreoTrajectoryIntoCache(trajectoryName);
		return getChoreoPathCache()[cacheName];
	}

	/**
	 * Get the differential pose for the start point of this path
	 *
	 * @return Pose at the path's starting point
	 */
	frc::Pose2d getStartingDifferentialPose();

	/**
	 * Get the holonomic pose for the start point of this path. If the path does not have an ideal
	 * starting state, this will return nullopt.
	 *
	 * @return The ideal starting pose if an ideal starting state is present, nullopt otherwise
	 */
	std::optional<frc::Pose2d> getStartingHolonomicPose();

	/**
	 * Create a path planner path from pre-generated path points. This is used internally, and you
	 * likely should not use this
	 */
	static std::shared_ptr<PathPlannerPath> fromPathPoints(
			std::vector<PathPoint> pathPoints,
			PathConstraints globalConstraints, GoalEndState goalEndState);

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
	 * If possible, get the ideal trajectory for this path. This trajectory can be used if the robot
	 * is currently near the start of the path and at the ideal starting state. If there is no ideal
	 * starting state, there can be no ideal trajectory.
	 *
	 * @param robotConfig The config to generate the ideal trajectory with if it has not already been
	 *     generated
	 * @return An optional containing the ideal trajectory if it exists, an empty optional otherwise
	 */
	std::optional<PathPlannerTrajectory> getIdealTrajectory(
			RobotConfig robotConfig);

	/**
	 * Get the initial heading, or direction of travel, at the start of the path.
	 *
	 * @return Initial heading
	 */
	inline frc::Rotation2d getInitialHeading() const {
		return (getPoint(1).position - getPoint(0).position).Angle();
	}

	/**
	 * Get the waypoints for this path
	 * @return vector of this path's waypoints
	 */
	constexpr std::vector<Waypoint>& getWaypoints() {
		return m_waypoints;
	}

	/**
	 * Get the rotation targets for this path
	 * @return vector of this path's rotation targets
	 */
	constexpr std::vector<RotationTarget>& getRotationTargets() {
		return m_rotationTargets;
	}

	/**
	 * Get the point towards zones for this path
	 *
	 * @return vector of this path's point towards zones
	 */
	constexpr std::vector<PointTowardsZone>& getPointTowardsZones() {
		return m_pointTowardsZones;
	}

	/**
	 * Get the constraint zones for this path
	 * @return vector of this path's constraint zones
	 */
	constexpr std::vector<ConstraintsZone>& getConstraintZones() {
		return m_constraintZones;
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
	 * Get the ideal starting state of this path
	 *
	 * @return The ideal starting state
	 */
	constexpr const std::optional<IdealStartingState>& getIdealStartingState() const {
		return m_idealStartingState;
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

	inline PathPlannerTrajectory generateTrajectory(
			frc::ChassisSpeeds startingSpeeds, frc::Rotation2d startingRotation,
			const RobotConfig &config) {
		if (m_isChoreoPath) {
			return m_idealTrajectory.value();
		} else {
			return PathPlannerTrajectory(shared_from_this(), startingSpeeds,
					startingRotation, config);
		}
	}

	/**
	 * Flip a path to the other side of the field, maintaining a global blue alliance origin
	 *
	 * @return The flipped path
	 */
	std::shared_ptr<PathPlannerPath> flipPath();

	/**
	 * Get a list of poses representing every point in this path. This can be used to display a path
	 * on a field 2d widget, for example.
	 *
	 * @return List of poses for each point in this path
	 */
	inline std::vector<frc::Pose2d> getPathPoses() const {
		std::vector < frc::Pose2d > poses;
		for (const PathPoint &point : m_allPoints) {
			poses.emplace_back(point.position, frc::Rotation2d());
		}
		return poses;
	}

	/** Clear the cache of previously loaded paths. */
	static inline void clearPathCache() {
		PathPlannerPath::getPathCache().clear();
		PathPlannerPath::getChoreoPathCache().clear();
	}

private:
	std::vector<PathPoint> createPath();

	static std::shared_ptr<PathPlannerPath> fromJson(const wpi::json &json);

	static inline std::vector<Waypoint> waypointsFromJson(
			const wpi::json &waypointsJson) {
		std::vector < Waypoint > waypoints;
		for (wpi::json::const_reference waypoint : waypointsJson) {
			waypoints.emplace_back(Waypoint::fromJson(waypoint));
		}
		return waypoints;
	}

	static void loadChoreoTrajectoryIntoCache(std::string trajectoryName);

	void precalcValues();

	static units::meter_t getCurveRadiusAtPoint(size_t index,
			std::vector<PathPoint> &points);

	inline PathConstraints constraintsForWaypointPos(double pos) const {
		for (auto z : m_constraintZones) {
			if (pos >= z.getMinWaypointRelativePos()
					&& pos <= z.getMaxWaypointRelativePos()) {
				return z.getConstraints();
			}
		}

		// Check if constraints should be unlimited
		if (m_globalConstraints.isUnlimited()) {
			return PathConstraints::unlimitedConstraints(
					m_globalConstraints.getNominalVoltage());
		}

		return m_globalConstraints;
	}

	inline std::optional<PointTowardsZone> pointZoneForWaypointPos(
			double pos) const {
		for (auto z : m_pointTowardsZones) {
			if (pos >= z.getMinWaypointRelativePos()
					&& pos <= z.getMaxWaypointRelativePos()) {
				return z;
			}
		}
		return std::nullopt;
	}

	frc::Translation2d samplePath(double waypointRelativePos) const;

	static std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>>& getPathCache();

	static std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>>& getChoreoPathCache();

	std::vector<Waypoint> m_waypoints;
	std::vector<RotationTarget> m_rotationTargets;
	std::vector<PointTowardsZone> m_pointTowardsZones;
	std::vector<ConstraintsZone> m_constraintZones;
	std::vector<EventMarker> m_eventMarkers;
	PathConstraints m_globalConstraints;
	std::optional<IdealStartingState> m_idealStartingState;
	GoalEndState m_goalEndState;
	std::vector<PathPoint> m_allPoints;
	bool m_reversed;

	bool m_isChoreoPath;
	std::optional<PathPlannerTrajectory> m_idealTrajectory = std::nullopt;

	static int m_instances;

	static constexpr double targetIncrement = 0.05;
	static constexpr units::meter_t targetSpacing = 0.2_m;
};
}
