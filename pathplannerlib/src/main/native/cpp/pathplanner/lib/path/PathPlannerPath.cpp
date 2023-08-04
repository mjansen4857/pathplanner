#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/path/PathSegment.h"
#include "pathplanner/lib/GeometryUtil.h"
#include <frc/Filesystem.h>
#include <wpi/raw_istream.h>
#include <limits>

using namespace pathplanner;

PathPlannerPath::PathPlannerPath(std::vector<frc::Translation2d> bezierPoints,
		std::vector<RotationTarget> rotationTargets,
		std::vector<ConstraintsZone> constraintZones,
		std::vector<EventMarker> eventMarkers,
		PathConstraints globalConstraints, GoalEndState goalEndState) : m_bezierPoints(
		bezierPoints), m_rotationTargets(rotationTargets), m_constraintZones(
		constraintZones), m_eventMarkers(eventMarkers), m_globalConstraints(
		globalConstraints), m_goalEndState(goalEndState) {
	m_allPoints = PathPlannerPath::createPath(m_bezierPoints, m_rotationTargets,
			m_constraintZones);

	precalcValues();
}

PathPlannerPath::PathPlannerPath(PathConstraints globalConstraints,
		GoalEndState goalEndState) : m_globalConstraints(globalConstraints), m_goalEndState(
		goalEndState) {

}

void PathPlannerPath::hotReload(const wpi::json &json) {
	PathPlannerPath updatedPath = PathPlannerPath::fromJson(json);

	m_bezierPoints = updatedPath.m_bezierPoints;
	m_rotationTargets = updatedPath.m_rotationTargets;
	m_constraintZones = updatedPath.m_constraintZones;
	m_eventMarkers = updatedPath.m_eventMarkers;
	m_globalConstraints = updatedPath.m_globalConstraints;
	m_goalEndState = updatedPath.m_goalEndState;
	m_allPoints = updatedPath.m_allPoints;
}

PathPlannerPath PathPlannerPath::fromPathFile(std::string pathName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/paths/" + pathName + ".path";

	std::error_code error_code;
	wpi::raw_fd_istream input { filePath, error_code };

	if (error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json;
	input >> json;

	PathPlannerPath path = PathPlannerPath::fromJson(json);
	// TODO: register hot reload
	return path;
}

PathPlannerPath PathPlannerPath::fromJson(const wpi::json &json) {
	std::vector < frc::Translation2d > bezierPoints =
			PathPlannerPath::bezierPointsFromWaypointsJson(
					json.at("waypoints"));
	PathConstraints globalConstraints = PathConstraints::fromJson(
			json.at("globalConstraints"));
	GoalEndState goalEndState = GoalEndState::fromJson(json.at("goalEndState"));
	std::vector < RotationTarget > rotationTargets;
	std::vector < ConstraintsZone > constraintZones;
	std::vector < EventMarker > eventMarkers;

	for (wpi::json::const_reference rotJson : json.at("rotationTargets")) {
		rotationTargets.push_back(RotationTarget::fromJson(rotJson));
	}

	for (wpi::json::const_reference zoneJson : json.at("constraintZones")) {
		constraintZones.push_back(ConstraintsZone::fromJson(zoneJson));
	}

	for (wpi::json::const_reference markerJson : json.at("eventMarkers")) {
		eventMarkers.push_back(EventMarker::fromJson(markerJson));
	}

	return PathPlannerPath(bezierPoints, rotationTargets, constraintZones,
			eventMarkers, globalConstraints, goalEndState);
}

std::vector<frc::Translation2d> PathPlannerPath::bezierPointsFromWaypointsJson(
		const wpi::json &json) {
	std::vector < frc::Translation2d > bezierPoints;

	// First point
	wpi::json::const_reference firstPoint = json[0];
	bezierPoints.push_back(
			PathPlannerPath::pointFromJson(firstPoint.at("anchor")));
	bezierPoints.push_back(
			PathPlannerPath::pointFromJson(firstPoint.at("nextControl")));

	// Mid points
	for (size_t i = 1; i < json.size() - 1; i++) {
		wpi::json::const_reference point = json[i];
		bezierPoints.push_back(
				PathPlannerPath::pointFromJson(point.at("prevControl")));
		bezierPoints.push_back(
				PathPlannerPath::pointFromJson(point.at("anchor")));
		bezierPoints.push_back(
				PathPlannerPath::pointFromJson(point.at("nextControl")));
	}

	// Last point
	wpi::json::const_reference lastPoint = json[json.size() - 1];
	bezierPoints.push_back(
			PathPlannerPath::pointFromJson(lastPoint.at("prevControl")));
	bezierPoints.push_back(
			PathPlannerPath::pointFromJson(lastPoint.at("anchor")));

	return bezierPoints;
}

frc::Translation2d PathPlannerPath::pointFromJson(const wpi::json &json) {
	auto x = units::meter_t { static_cast<double>(json.at("x")) };
	auto y = units::meter_t { static_cast<double>(json.at("y")) };

	return frc::Translation2d(x, y);
}

PathPlannerPath PathPlannerPath::fromPathPoints(
		std::vector<PathPoint> pathPoints, PathConstraints globalConstraints,
		GoalEndState goalEndState) {
	PathPlannerPath path = PathPlannerPath(globalConstraints, goalEndState);
	path.m_allPoints = pathPoints;

	path.precalcValues();

	return path;
}

std::vector<PathPoint> PathPlannerPath::createPath(
		std::vector<frc::Translation2d> bezierPoints,
		std::vector<RotationTarget> holonomicRotations,
		std::vector<ConstraintsZone> constraintZones) {
	if (bezierPoints.size() < 4) {
		throw std::runtime_error(
				"Failed to create path, not enough bezier points");
	}

	std::vector < PathPoint > points;

	size_t numSegments = (bezierPoints.size() - 1) / 3;
	for (size_t s = 0; s < numSegments; s++) {
		size_t iOffset = s * 3;
		frc::Translation2d p1 = bezierPoints[iOffset];
		frc::Translation2d p2 = bezierPoints[iOffset + 1];
		frc::Translation2d p3 = bezierPoints[iOffset + 2];
		frc::Translation2d p4 = bezierPoints[iOffset + 3];

		std::vector < RotationTarget > segmentRotations;
		for (RotationTarget t : holonomicRotations) {
			if (t.getPosition() >= s && t.getPosition() <= s + 1) {
				segmentRotations.push_back(t.forSegmentIndex(s));
			}
		}

		std::vector < ConstraintsZone > segmentZones;
		for (ConstraintsZone z : constraintZones) {
			if (z.overlapsRange(s, s + 1)) {
				segmentZones.push_back(z.forSegmentIndex(s));
			}
		}

		PathSegment segment(p1, p2, p3, p4, segmentRotations, segmentZones,
				s == numSegments - 1);
		auto segmentPoints = segment.getSegmentPoints();
		points.insert(points.end(), segmentPoints.begin(), segmentPoints.end());
	}

	return points;
}

void PathPlannerPath::precalcValues() {
	if (numPoints() > 0) {
		for (size_t i = 0; i < m_allPoints.size(); i++) {
			PathConstraints constraints = m_allPoints[i].constraints.value_or(
					m_globalConstraints);
			units::meter_t curveRadius = units::math::abs(
					getCurveRadiusAtPoint(i, m_allPoints));

			if (GeometryUtil::isFinite(curveRadius)) {
				m_allPoints[i].maxV = units::math::min(
						units::math::sqrt(
								constraints.getMaxAcceleration() * curveRadius),
						constraints.getMaxVelocity());
			} else {
				m_allPoints[i].maxV = constraints.getMaxVelocity();
			}

			if (i != 0) {
				m_allPoints[i].distanceAlongPath =
						m_allPoints[i - 1].distanceAlongPath
								+ (m_allPoints[i - 1].position.Distance(
										m_allPoints[i].position));
			}
		}

		for (EventMarker &m : m_eventMarkers) {
			size_t pointIndex = static_cast<size_t>(std::round(
					m.getWaypointRelativePos() / PathSegment::RESOLUTION));
			m.setMarkerPosition(m_allPoints[pointIndex].position);
		}

		m_allPoints[m_allPoints.size() - 1].holonomicRotation =
				m_goalEndState.getRotation();
		m_allPoints[m_allPoints.size() - 1].maxV = m_goalEndState.getVelocity();
	}
}

units::meter_t PathPlannerPath::getCurveRadiusAtPoint(size_t index,
		std::vector<PathPoint> &points) {
	if (points.size() < 3) {
		return units::meter_t { std::numeric_limits<double>::infinity() };
	}

	if (index == 0) {
		return GeometryUtil::calculateRadius(points[index].position,
				points[index + 1].position, points[index + 2].position);
	} else if (index == points.size() - 1) {
		return GeometryUtil::calculateRadius(points[index - 2].position,
				points[index - 1].position, points[index].position);
	} else {
		return GeometryUtil::calculateRadius(points[index - 1].position,
				points[index].position, points[index + 1].position);
	}
}
