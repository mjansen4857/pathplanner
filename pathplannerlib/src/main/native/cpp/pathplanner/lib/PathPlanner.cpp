#include "pathplanner/lib/PathPlanner.h"
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/Filesystem.h>
#include <wpi/SmallString.h>
#include <wpi/raw_istream.h>
#include <units/length.h>
#include <units/angle.h>
#include <units/velocity.h>
#include <vector>

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

	return PathPlannerTrajectory(waypoints, markers, constraints, reversed);
}

std::vector<PathPlannerTrajectory> PathPlanner::loadPathGroup(
		std::string const &name,
		std::initializer_list<PathConstraints> const constraints,
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

		currentPath.push_back(w);
		if (w.isStopPoint || i == waypoints.size() - 1) {
			// Get the markers that should be part of this path and correct their positions
			std::vector < PathPlannerTrajectory::EventMarker > currentMarkers;
			for (PathPlannerTrajectory::EventMarker const &marker : markers) {
				if (marker.waypointRelativePos
						>= indexOfWaypoint(waypoints, currentPath[0])
						&& marker.waypointRelativePos <= i) {
					currentMarkers.push_back(
							PathPlannerTrajectory::EventMarker(marker.names,
									marker.waypointRelativePos
											- indexOfWaypoint(waypoints,
													currentPath[0])));
				}
			}
			splitMarkers.push_back(currentMarkers);

			splitWaypoints.push_back(currentPath);
			currentPath = std::vector<PathPlannerTrajectory::Waypoint>();
			currentPath.push_back(w);
		}
	}

	if (splitWaypoints.size() != splitMarkers.size()) {
		throw std::runtime_error(
				"Size of splitWaypoints does not match splitMarkers. Something went very wrong");
	}

	std::vector < PathPlannerTrajectory > pathGroup;
	std::vector < PathConstraints > constraintsVec(constraints);
	bool shouldReverse = reversed;
	for (size_t i = 0; i < splitWaypoints.size(); i++) {
		PathConstraints const currentConstraints =
				(i > constraintsVec.size() - 1) ?
						constraintsVec[constraintsVec.size() - 1] :
						constraintsVec[i];

		pathGroup.emplace_back(splitWaypoints[i], splitMarkers[i],
				currentConstraints, shouldReverse);

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
		PathPoint const point1, PathPoint const point2,
		std::initializer_list<PathPoint> const points) {
	std::vector < PathPoint > allPoints;
	allPoints.push_back(point1);
	allPoints.push_back(point2);
	allPoints.insert(allPoints.end(), points);

	std::vector < PathPlannerTrajectory::Waypoint > waypoints;
	waypoints.emplace_back(point1.m_position, frc::Translation2d(),
			frc::Translation2d(), point1.m_velocityOverride,
			point1.m_holonomicRotation, false, false, 0_s);

	for (size_t i = 1; i < allPoints.size(); i++) {
		PathPoint const p1 = allPoints[i - 1];
		PathPoint const p2 = allPoints[i];

		units::meter_t thirdDistance = p1.m_position.Distance(p2.m_position)
				/ 3.0;

		frc::Translation2d p1Next = p1.m_position
				+ frc::Translation2d(p1.m_heading.Cos() * thirdDistance,
						p1.m_heading.Sin() * thirdDistance);
		waypoints[i - 1].nextControl = p1Next;

		frc::Translation2d p2Prev = p2.m_position
				- frc::Translation2d(p2.m_heading.Cos() * thirdDistance,
						p2.m_heading.Sin() * thirdDistance);
		waypoints.emplace_back(p2.m_position, p2Prev, frc::Translation2d(),
				p2.m_velocityOverride, p2.m_holonomicRotation, false, false,
				0_s);
	}

	return PathPlannerTrajectory(waypoints,
			std::vector<PathPlannerTrajectory::EventMarker>(), constraints,
			reversed);
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

		units::second_t const waitTime =
				(waypoint.find("waitTime") != waypoint.end()) ?
						(units::second_t { static_cast<double>(waypoint.at(
								"waitTime")) }) :
						0_s;

		waypoints.emplace_back(anchorPoint, prevControl, nextControl,
				velOverride, holonomicAngle, isReversal, isStopPoint, waitTime);
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
			markers.push_back(
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
