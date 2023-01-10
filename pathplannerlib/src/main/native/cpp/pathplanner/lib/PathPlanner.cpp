#include "pathplanner/lib/PathPlanner.h"
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/Filesystem.h>
#include <initializer_list>
#include <stdexcept>
#include <wpi/SmallString.h>
#include <wpi/raw_istream.h>
#include <units/length.h>
#include <units/angle.h>

using namespace pathplanner;

double PathPlanner::resolution = 0.004;

PathPlannerTrajectory PathPlanner::loadPath(std::string const &name,
		PathConstraints const constraints, bool const reversed) {
	std::string const filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/" + name + ".path";

	std::error_code error_code;
	wpi::raw_fd_istream input { filePath, error_code };

	if (error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json;
	input >> json;

	std::vector < PathPlannerTrajectory::Waypoint > waypoints =
			getWaypointsFromJson(json);
	std::vector < PathPlannerTrajectory::EventMarker > markers =
			getMarkersFromJson(json);

	return PathPlannerTrajectory(waypoints, markers, constraints, reversed,
			true);
}

std::vector<PathPlannerTrajectory> PathPlanner::loadPathGroup(
		std::string const &name,
		std::initializer_list<PathConstraints> const constraints,
		bool const reversed) {
	return loadPathGroup(name, std::vector < PathConstraints > (constraints),
			reversed);
}

std::vector<PathPlannerTrajectory> PathPlanner::loadPathGroup(
		std::string const &name, std::vector<PathConstraints> const constraints,
		bool const reversed) {
	if (constraints.size() == 0) {
		throw std::runtime_error(
				"At least one PathConstraints is required but none were provized");
	}

	std::string const filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/" + name + ".path";

	std::error_code error_code;
	wpi::raw_fd_istream input { filePath, error_code };

	if (error_code) {
		throw std::runtime_error(("Cannot open file: " + filePath));
	}

	wpi::json json;
	input >> json;

	std::vector < PathPlannerTrajectory::Waypoint > waypoints =
			getWaypointsFromJson(json);
	std::vector < PathPlannerTrajectory::EventMarker > markers =
			getMarkersFromJson(json);

	std::vector < std::vector
			< PathPlannerTrajectory::Waypoint >> splitWaypoints;
	std::vector < std::vector
			< PathPlannerTrajectory::EventMarker >> splitMarkers;

	std::vector < PathPlannerTrajectory::Waypoint > currentPath;
	for (size_t i = 0; i < waypoints.size(); i++) {
		PathPlannerTrajectory::Waypoint const w = waypoints[i];

		currentPath.emplace_back(w);
		if (w.isStopPoint || i == waypoints.size() - 1) {
			// Get the markers that should be part of this path and correct their positions
			std::vector < PathPlannerTrajectory::EventMarker > currentMarkers;
			for (PathPlannerTrajectory::EventMarker const &marker : markers) {
				if (marker.waypointRelativePos
						>= indexOfWaypoint(waypoints, currentPath[0])
						&& marker.waypointRelativePos <= i) {
					currentMarkers.emplace_back(
							PathPlannerTrajectory::EventMarker(marker.names,
									marker.waypointRelativePos
											- indexOfWaypoint(waypoints,
													currentPath[0])));
				}
			}
			splitMarkers.emplace_back(currentMarkers);

			splitWaypoints.emplace_back(currentPath);
			currentPath = std::vector<PathPlannerTrajectory::Waypoint>();
			currentPath.emplace_back(w);
		}
	}

	if (splitWaypoints.size() != splitMarkers.size()) {
		throw std::runtime_error(
				"Size of splitWaypoints does not match splitMarkers. Something went very wrong");
	}

	std::vector < PathPlannerTrajectory > pathGroup;
	bool shouldReverse = reversed;
	for (size_t i = 0; i < splitWaypoints.size(); i++) {
		PathConstraints const currentConstraints =
				(i > constraints.size() - 1) ?
						constraints[constraints.size() - 1] : constraints[i];

		pathGroup.emplace_back(splitWaypoints[i], splitMarkers[i],
				currentConstraints, shouldReverse, true);

		// Loop through waypoints and invert shouldReverse for every reversal point.
		// This makes sure that other paths in the group are properly reversed.
		for (size_t j = 1; j < splitWaypoints[i].size(); j++) {
			if (splitWaypoints[i][j].isReversal) {
				shouldReverse = !shouldReverse;
			}
		}
	}

	return pathGroup;
}

PathPlannerTrajectory PathPlanner::generatePath(
		PathConstraints const constraints, bool const reversed,
		std::vector<PathPoint> const points) {
	if (points.size() < 2) {
		throw std::invalid_argument(
				"Error generating trajectory.  List of points in trajectory must have at least two points.");
	}

	PathPoint firstPoint = points.front();

	std::vector < PathPlannerTrajectory::Waypoint > waypoints;
	waypoints.emplace_back(firstPoint.m_position, frc::Translation2d(),
			frc::Translation2d(), firstPoint.m_velocityOverride,
			firstPoint.m_holonomicRotation, false, false,
			PathPlannerTrajectory::StopEvent());

	for (size_t i = 1; i < points.size(); i++) {
		PathPoint const p1 = points[i - 1];
		PathPoint const p2 = points[i];

		units::meter_t thirdDistance = p1.m_position.Distance(p2.m_position)
				/ 3.0;

		units::meter_t p1NextDistance =
				p1.m_nextControlLength <= 0_m ?
						thirdDistance : p1.m_nextControlLength;
		units::meter_t p2PrevDistance =
				p2.m_prevControlLength <= 0_m ?
						thirdDistance : p2.m_prevControlLength;

		frc::Translation2d p1Next = p1.m_position
				+ frc::Translation2d(p1.m_heading.Cos() * p1NextDistance,
						p1.m_heading.Sin() * p1NextDistance);
		waypoints[i - 1].nextControl = p1Next;

		frc::Translation2d p2Prev = p2.m_position
				- frc::Translation2d(p2.m_heading.Cos() * p2PrevDistance,
						p2.m_heading.Sin() * p2PrevDistance);
		waypoints.emplace_back(p2.m_position, p2Prev, frc::Translation2d(),
				p2.m_velocityOverride, p2.m_holonomicRotation, false, false,
				PathPlannerTrajectory::StopEvent());
	}

	return PathPlannerTrajectory(waypoints,
			std::vector<PathPlannerTrajectory::EventMarker>(), constraints,
			reversed, false);
}

PathPlannerTrajectory PathPlanner::generatePath(
		PathConstraints const constraints, bool const reversed,
		PathPoint point1, PathPoint point2,
		std::initializer_list<PathPoint> points) {
	std::vector < PathPoint > allPoints;
	allPoints.emplace_back(point1);
	allPoints.emplace_back(point2);
	allPoints.insert(allPoints.end(), points);
	return generatePath(constraints, reversed, allPoints);
}

PathConstraints PathPlanner::getConstraintsFromPath(std::string const &name) {
	std::string const filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/" + name + ".path";

	std::error_code error_code;
	wpi::raw_fd_istream input { filePath, error_code };

	if (error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json;
	input >> json;

	if (json.find("maxVelocity") != json.end()
			&& json.find("maxAcceleration") != json.end()) {
		double const maxV = json.at("maxVelocity");
		double const maxA = json.at("maxAcceleration");

		return PathConstraints(units::meters_per_second_t { maxV },
				units::meters_per_second_squared_t { maxA });
	} else {
		throw std::runtime_error(
				"Path constraints not present in path file. Make sure you explicitly set them in the GUI.");
	}
}

std::vector<PathPlannerTrajectory::Waypoint> PathPlanner::getWaypointsFromJson(
		wpi::json json) {
	std::vector < PathPlannerTrajectory::Waypoint > waypoints;

	for (wpi::json::const_reference waypoint : json.at("waypoints")) {
		wpi::json::const_reference jsonAnchor = waypoint.at("anchorPoint");
		frc::Translation2d const anchorPoint = frc::Translation2d(
				units::meter_t { static_cast<double>(jsonAnchor.at("x")) },
				units::meter_t { static_cast<double>(jsonAnchor.at("y")) });

		wpi::json::const_reference jsonPrevControl = waypoint.at("prevControl");
		frc::Translation2d prevControl =
				!(jsonPrevControl.is_null()) ?
						frc::Translation2d(units::meter_t {
								static_cast<double>(jsonPrevControl.at("x")) },
								units::meter_t {
										static_cast<double>(jsonPrevControl.at(
												"y")) }) :
						frc::Translation2d { };

		wpi::json::const_reference jsonNextControl = waypoint.at("nextControl");
		frc::Translation2d nextControl =
				(!jsonNextControl.is_null()) ?
						frc::Translation2d(units::meter_t {
								static_cast<double>(jsonNextControl.at("x")) },
								units::meter_t {
										static_cast<double>(jsonNextControl.at(
												"y")) }) :
						frc::Translation2d { };

		frc::Rotation2d const holonomicAngle =
				(!waypoint.at("holonomicAngle").is_null()) ?
						frc::Rotation2d(
								units::degree_t {
										static_cast<double>(waypoint.at(
												"holonomicAngle")) }) :
						999_rad;

		bool const isReversal = waypoint.at("isReversal");
		bool isStopPoint =
				(waypoint.find("isStopPoint") != waypoint.end()) ?
						static_cast<bool>(waypoint.at("isStopPoint")) : false;

		units::meters_per_second_t const velOverride =
				(!waypoint.at("velOverride").is_null()) ?
						units::meters_per_second_t {
								static_cast<double>(waypoint.at("velOverride")) } :
						-1_mps;

		PathPlannerTrajectory::StopEvent stopEvent;
		if (waypoint.find("stopEvent") != waypoint.end()) {
			std::vector < std::string > names;
			PathPlannerTrajectory::StopEvent::ExecutionBehavior executionBehavior =
					PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL;
			PathPlannerTrajectory::StopEvent::WaitBehavior waitBehvior =
					PathPlannerTrajectory::StopEvent::WaitBehavior::NONE;
			units::second_t waitTime = 0_s;

			wpi::json::const_reference stopEventJson = waypoint.at("stopEvent");
			if (stopEventJson.find("names") != stopEventJson.end()) {
				for (wpi::json::const_reference name : stopEventJson.at("names")) {
					names.push_back(name);
				}
			}
			if (stopEventJson.find("executionBehavior")
					!= stopEventJson.end()) {
				std::string behavior = stopEventJson.at("executionBehavior");

				if (behavior == "parallel") {
					executionBehavior =
							PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL;
				} else if (behavior == "sequential") {
					executionBehavior =
							PathPlannerTrajectory::StopEvent::ExecutionBehavior::SEQUENTIAL;
				} else if (behavior == "parallelDeadline") {
					executionBehavior =
							PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL_DEADLINE;
				}
			}
			if (stopEventJson.find("waitBehavior") != stopEventJson.end()) {
				std::string behavior = stopEventJson.at("waitBehavior");

				if (behavior == "none") {
					waitBehvior =
							PathPlannerTrajectory::StopEvent::WaitBehavior::NONE;
				} else if (behavior == "before") {
					waitBehvior =
							PathPlannerTrajectory::StopEvent::WaitBehavior::BEFORE;
				} else if (behavior == "after") {
					waitBehvior =
							PathPlannerTrajectory::StopEvent::WaitBehavior::AFTER;
				} else if (behavior == "deadline") {
					waitBehvior =
							PathPlannerTrajectory::StopEvent::WaitBehavior::DEADLINE;
				} else if (behavior == "minimum") {
					waitBehvior =
							PathPlannerTrajectory::StopEvent::WaitBehavior::MINIMUM;
				}
			}
			if (stopEventJson.find("waitTime") != stopEventJson.end()) {
				waitTime = units::second_t {
						static_cast<double>(stopEventJson.at("waitTime")) };
			}

			stopEvent = PathPlannerTrajectory::StopEvent(names,
					executionBehavior, waitBehvior, waitTime);
		}

		waypoints.emplace_back(anchorPoint, prevControl, nextControl,
				velOverride, holonomicAngle, isReversal, isStopPoint,
				stopEvent);
	}

	return waypoints;
}

std::vector<PathPlannerTrajectory::EventMarker> PathPlanner::getMarkersFromJson(
		wpi::json json) {
	std::vector < PathPlannerTrajectory::EventMarker > markers;

	if (json.find("markers") != json.end()) {
		for (wpi::json::const_reference marker : json.at("markers")) {
			std::vector < std::string > names;
			if (marker.find("names") != marker.end()) {
				for (wpi::json::const_reference name : marker.at("names")) {
					names.push_back(name);
				}
			} else {
				// Handle transition from one-event markers to multi-event markers. Remove next season
				names.push_back(marker.at("name"));
			}
			markers.emplace_back(
					PathPlannerTrajectory::EventMarker(std::move(names),
							marker.at("position")));
		}
	}

	return markers;
}

int PathPlanner::indexOfWaypoint(
		std::vector<PathPlannerTrajectory::Waypoint> const &waypoints,
		PathPlannerTrajectory::Waypoint const waypoint) {
	for (size_t i = 0; i < waypoints.size(); i++) {
		if (waypoints[i].anchorPoint == waypoint.anchorPoint) {
			return i;
		}
	}
	return -1;
}
