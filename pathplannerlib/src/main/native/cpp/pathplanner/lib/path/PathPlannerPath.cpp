#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/ScheduleCommandEvent.h"
#include <frc/Filesystem.h>
#include <frc/MathUtil.h>
#include <wpi/MemoryBuffer.h>
#include <limits>
#include <optional>
#include <utility>
#include <hal/FRCUsageReporting.h>

using namespace pathplanner;

int PathPlannerPath::m_instances = 0;

PathPlannerPath::PathPlannerPath(std::vector<Waypoint> waypoints,
		std::vector<RotationTarget> rotationTargets,
		std::vector<ConstraintsZone> constraintZones,
		std::vector<EventMarker> eventMarkers,
		PathConstraints globalConstraints,
		std::optional<IdealStartingState> idealStartingState,
		GoalEndState goalEndState, bool reversed) : m_waypoints(waypoints), m_rotationTargets(
		rotationTargets), m_constraintZones(constraintZones), m_eventMarkers(
		eventMarkers), m_globalConstraints(globalConstraints), m_idealStartingState(
		idealStartingState), m_goalEndState(goalEndState), m_reversed(reversed), m_isChoreoPath(
		false) {
	std::sort(m_rotationTargets.begin(), m_rotationTargets.end(),
			[](auto &left, auto &right) {
				return left.getPosition() < right.getPosition();
			});
	std::sort(m_eventMarkers.begin(), m_eventMarkers.end(),
			[](auto &left, auto &right) {
				return left.getWaypointRelativePos()
						< right.getWaypointRelativePos();
			});

	m_allPoints = createPath();

	precalcValues();

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerPath, m_instances);
}

PathPlannerPath::PathPlannerPath(PathConstraints constraints,
		GoalEndState goalEndState) : m_waypoints(), m_rotationTargets(), m_constraintZones(), m_eventMarkers(), m_globalConstraints(
		constraints), m_idealStartingState(std::nullopt), m_goalEndState(
		goalEndState), m_reversed(false), m_isChoreoPath(false) {
	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerPath, m_instances);
}

void PathPlannerPath::hotReload(const wpi::json &json) {
	auto updatedPath = PathPlannerPath::fromJson(json);

	m_waypoints = updatedPath->m_waypoints;
	m_rotationTargets = updatedPath->m_rotationTargets;
	m_constraintZones = updatedPath->m_constraintZones;
	m_eventMarkers = updatedPath->m_eventMarkers;
	m_globalConstraints = updatedPath->m_globalConstraints;
	m_idealStartingState = updatedPath->m_idealStartingState;
	m_goalEndState = updatedPath->m_goalEndState;
	m_reversed = updatedPath->m_reversed;
	m_allPoints = updatedPath->m_allPoints;

	// Clear the ideal trajectory so it gets regenerated
	m_idealTrajectory = std::nullopt;
}

std::vector<Waypoint> PathPlannerPath::waypointsFromPoses(
		std::vector<frc::Pose2d> poses) {
	if (poses.size() < 2) {
		throw FRC_MakeError(frc::err::InvalidParameter,
				"Not enough poses provided to waypointsFromPoses");
	}

	std::vector < Waypoint > waypoints;

	// First pose
	waypoints.emplace_back(
			Waypoint::autoControlPoints(poses[0].Translation(),
					poses[0].Rotation(), std::nullopt, poses[1].Translation()));

	// Middle poses
	for (size_t i = 1; i < poses.size() - 1; i++) {
		waypoints.emplace_back(
				Waypoint::autoControlPoints(poses[i].Translation(),
						poses[i].Rotation(), poses[i - 1].Translation(),
						poses[i + 1].Translation()));
	}

	// Last pose
	waypoints.emplace_back(
			Waypoint::autoControlPoints(poses[poses.size() - 1].Translation(),
					poses[poses.size() - 1].Rotation(),
					poses[poses.size() - 2].Translation(), std::nullopt));

	return waypoints;
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromPathFile(
		std::string pathName) {
	if (PathPlannerPath::getPathCache().contains(pathName)) {
		return PathPlannerPath::getPathCache()[pathName];
	}

	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/paths/" + pathName + ".path";

	std::error_code error_code;
	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (!fileBuffer || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	std::shared_ptr < PathPlannerPath > path = PathPlannerPath::fromJson(json);
	PPLibTelemetry::registerHotReloadPath(pathName, path);

	PathPlannerPath::getPathCache().emplace(pathName, path);

	return path;
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromChoreoTrajectory(
		std::string trajectoryName) {
	if (PathPlannerPath::getChoreoPathCache().contains(trajectoryName)) {
		return PathPlannerPath::getChoreoPathCache()[trajectoryName];
	}

	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/choreo/" + trajectoryName + ".traj";

	std::error_code error_code;
	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (!fileBuffer || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	std::vector < PathPlannerTrajectoryState > trajStates;
	for (wpi::json::const_reference s : json.at("samples")) {
		PathPlannerTrajectoryState state;

		units::second_t time { s.at("timestamp").get<double>() };
		units::meter_t xPos { s.at("x").get<double>() };
		units::meter_t yPos { s.at("y").get<double>() };
		units::radian_t rotationRad { s.at("heading").get<double>() };
		units::meters_per_second_t xVel { s.at("velocityX").get<double>() };
		units::meters_per_second_t yVel { s.at("velocityY").get<double>() };
		units::radians_per_second_t angularVelRps { s.at("angularVelocity").get<
				double>() };

		state.time = time;
		state.linearVelocity = units::math::hypot(xVel, yVel);
		state.pose = frc::Pose2d(frc::Translation2d(xPos, yPos),
				frc::Rotation2d(rotationRad));
		state.fieldSpeeds = frc::ChassisSpeeds { xVel, yVel, angularVelRps };

		trajStates.emplace_back(state);
	}

	auto path = std::make_shared < PathPlannerPath
			> (PathConstraints(
					units::meters_per_second_t {
							std::numeric_limits<double>::infinity() },
					units::meters_per_second_squared_t { std::numeric_limits<
							double>::infinity() }, units::radians_per_second_t {
							std::numeric_limits<double>::infinity() },
					units::radians_per_second_squared_t { std::numeric_limits<
							double>::infinity() }), GoalEndState(
					trajStates[trajStates.size() - 1].linearVelocity,
					trajStates[trajStates.size() - 1].pose.Rotation()));

	std::vector < PathPoint > pathPoints;
	for (auto state : trajStates) {
		pathPoints.emplace_back(state.pose.Translation());
	}

	path->m_allPoints = pathPoints;
	path->m_isChoreoPath = true;

	std::vector < std::shared_ptr < Event >> events;
	if (json.contains("eventMarkers")) {
		for (wpi::json::const_reference m : json.at("eventMarkers")) {
			units::second_t timestamp { m.at("timestamp").get<double>() };

			EventMarker eventMarker = EventMarker(timestamp(),
					CommandUtil::commandFromJson(m.at("command"), false));

			path->m_eventMarkers.emplace_back(eventMarker);
			events.emplace_back(
					std::make_shared < ScheduleCommandEvent
							> (timestamp, eventMarker.getCommand()));
		}
	}

	std::sort(events.begin(), events.end(), [](auto left, auto right) {
		return left->getTimestamp() < right->getTimestamp();
	});

	path->m_idealTrajectory = PathPlannerTrajectory(trajStates, events);

	PathPlannerPath::getChoreoPathCache().emplace(trajectoryName, path);

	return path;
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromJson(
		const wpi::json &json) {
	std::vector < Waypoint > waypoints = PathPlannerPath::waypointsFromJson(
			json.at("waypoints"));
	PathConstraints globalConstraints = PathConstraints::fromJson(
			json.at("globalConstraints"));
	GoalEndState goalEndState = GoalEndState::fromJson(json.at("goalEndState"));
	IdealStartingState idealStartingState = IdealStartingState::fromJson(
			json.at("idealStartingState"));
	bool reversed = json.at("reversed").get<bool>();
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

	return std::make_shared < PathPlannerPath
			> (waypoints, rotationTargets, constraintZones, eventMarkers, globalConstraints, idealStartingState, goalEndState, reversed);
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromPathPoints(
		std::vector<PathPoint> pathPoints, PathConstraints globalConstraints,
		GoalEndState goalEndState) {
	auto path = std::make_shared < PathPlannerPath
			> (globalConstraints, goalEndState);
	path->m_allPoints = pathPoints;

	path->precalcValues();

	return path;
}

std::vector<PathPoint> PathPlannerPath::createPath() {
	if (m_waypoints.size() < 2) {
		throw std::runtime_error("A path must have at least 2 waypoints");
	}

	std::vector < RotationTarget > unaddedTargets;
	unaddedTargets.insert(unaddedTargets.begin(), m_rotationTargets.begin(),
			m_rotationTargets.end());
	std::vector < PathPoint > points;
	size_t numSegments = m_waypoints.size() - 1;

	// Add the first path point
	points.emplace_back(samplePath(0.0), std::nullopt,
			constraintsForWaypointPos(0.0));
	points[0].waypointRelativePos = 0.0;

	double pos = targetIncrement;

	while (pos < numSegments) {
		frc::Translation2d position = samplePath(pos);

		units::meter_t distance = points[points.size() - 1].position.Distance(
				position);
		if (distance <= 0.01_m) {
			pos = std::min(pos + targetIncrement,
					static_cast<double>(numSegments));
		}

		double prevWaypointPos = pos - targetIncrement;

		units::meter_t delta = distance - targetSpacing;
		if (delta > targetSpacing * 0.25) {
			// Points are too far apart, increment t by correct amount
			double correctIncrement = (targetSpacing * targetIncrement)
					/ distance;
			pos = pos - targetIncrement + correctIncrement;

			position = samplePath(pos);

			if (points[points.size() - 1].position.Distance(position)
					- targetSpacing > targetSpacing * 0.25) {
				// Points are still too far apart. Probably because of weird control
				// point placement. Just cut the correct increment in half and hope for the best
				pos = pos - (correctIncrement * 0.5);
				position = samplePath(pos);
			}
		} else if (delta < -targetSpacing * 0.25) {
			// Points are too close, increment waypoint relative pos by correct amount
			double correctIncrement = (targetSpacing * targetIncrement)
					/ distance;
			pos = pos - targetIncrement + correctIncrement;

			position = samplePath(pos);

			if (points[points.size() - 1].position.Distance(position)
					- targetSpacing < -targetSpacing * 0.25) {
				// Points are still too close. Probably because of weird control
				// point placement. Just cut the correct increment in half and hope for the best
				pos = pos + (correctIncrement * 0.5);
				position = samplePath(pos);
			}
		}

		// Add rotation targets
		std::optional < RotationTarget > target = std::nullopt;
		PathPoint prevPoint = points[points.size() - 1];

		while (!unaddedTargets.empty()
				&& unaddedTargets[0].getPosition() >= prevWaypointPos
				&& unaddedTargets[0].getPosition() <= pos) {
			if (std::abs(unaddedTargets[0].getPosition() - prevWaypointPos)
					< 0.001) {
				// Close enough to prev pos
				prevPoint.rotationTarget = unaddedTargets[0];
				unaddedTargets.erase(unaddedTargets.begin());
			} else if (std::abs(unaddedTargets[0].getPosition() - pos)
					< 0.001) {
				// Close enough to next pos
				target = unaddedTargets[0];
				unaddedTargets.erase(unaddedTargets.begin());
			} else {
				// We should insert a point at the exact position
				RotationTarget t = unaddedTargets[0];
				unaddedTargets.erase(unaddedTargets.begin());
				points.emplace_back(samplePath(t.getPosition()), t,
						constraintsForWaypointPos(t.getPosition()));
				points[points.size() - 1].waypointRelativePos = t.getPosition();
			}
		}

		points.emplace_back(position, target, constraintsForWaypointPos(pos));
		points[points.size() - 1].waypointRelativePos = pos;
		pos = std::min(pos + targetIncrement, static_cast<double>(numSegments));
	}

	// Keep trying to add the end point until its close enough to the prev point
	double trueIncrement = numSegments - (pos - targetIncrement);
	pos = numSegments;
	bool invalid = true;
	while (invalid) {
		frc::Translation2d position = samplePath(pos);

		units::meter_t distance = points[points.size() - 1].position.Distance(
				position);
		if (distance <= 0.01_m) {
			invalid = false;
			break;
		}

		double prevPos = pos - trueIncrement;

		units::meter_t delta = distance - targetSpacing;
		if (delta > targetSpacing * 0.25) {
			// Points are too far apart, increment waypoint relative pos by correct amount
			double correctIncrement = (targetSpacing * trueIncrement)
					/ distance;
			pos = pos - trueIncrement + correctIncrement;
			trueIncrement = correctIncrement;

			position = samplePath(pos);

			if (points[points.size() - 1].position.Distance(position)
					- targetSpacing > targetSpacing * 0.25) {
				// Points are still too far apart. Probably because of weird control
				// point placement. Just cut the correct increment in half and hope for the best
				pos = pos - (correctIncrement * 0.5);
				trueIncrement = correctIncrement * 0.5;
				position = samplePath(pos);
			}
		} else {
			invalid = false;
		}

		// Add a rotation target to the previous point if it is closer to it than
		// the current point
		if (!unaddedTargets.empty()) {
			if (std::abs(unaddedTargets[0].getPosition() - prevPos)
					<= std::abs(unaddedTargets[0].getPosition() - pos)) {
				points[points.size() - 1].rotationTarget = unaddedTargets[0];
				unaddedTargets.erase(unaddedTargets.begin());
			}
		}

		points.emplace_back(position, std::nullopt,
				constraintsForWaypointPos(pos));
		points[points.size() - 1].waypointRelativePos = pos;
		pos = numSegments;
	}

	for (size_t i = 1; i < points.size() - 1; i++) {
		units::meter_t curveRadius = GeometryUtil::calculateRadius(
				points[i - 1].position, points[i].position,
				points[i + 1].position);

		if (!GeometryUtil::isFinite(curveRadius)) {
			continue;
		}

		if (units::math::abs(curveRadius) < 0.25_m) {
			// Curve radius is too tight for default spacing, insert 4 more points
			double before1WaypointPos = GeometryUtil::doubleLerp(
					points[i - 1].waypointRelativePos,
					points[i].waypointRelativePos, 0.33);
			double before2WaypointPos = GeometryUtil::doubleLerp(
					points[i - 1].waypointRelativePos,
					points[i].waypointRelativePos, 0.67);
			double after1WaypointPos = GeometryUtil::doubleLerp(
					points[i].waypointRelativePos,
					points[i + 1].waypointRelativePos, 0.33);
			double after2WaypointPos = GeometryUtil::doubleLerp(
					points[i].waypointRelativePos,
					points[i + 1].waypointRelativePos, 0.67);

			PathPoint before1(samplePath(before1WaypointPos), std::nullopt,
					points[i].constraints);
			before1.waypointRelativePos = before1WaypointPos;
			PathPoint before2(samplePath(before2WaypointPos), std::nullopt,
					points[i].constraints);
			before2.waypointRelativePos = before2WaypointPos;
			PathPoint after1(samplePath(after1WaypointPos), std::nullopt,
					points[i].constraints);
			after1.waypointRelativePos = after1WaypointPos;
			PathPoint after2(samplePath(after2WaypointPos), std::nullopt,
					points[i].constraints);
			after2.waypointRelativePos = after2WaypointPos;

			points.insert(points.begin() + i, before2);
			points.insert(points.begin() + i, before1);
			points.insert(points.begin() + (i + 3), after2);
			points.insert(points.begin() + (i + 3), after1);
			i += 4;
		} else if (units::math::abs(curveRadius) < 0.5_m) {
			// Curve radius is too tight for default spacing, insert 2 more points
			double beforeWaypointPos = GeometryUtil::doubleLerp(
					points[i - 1].waypointRelativePos,
					points[i].waypointRelativePos, 0.5);
			double afterWaypointPos = GeometryUtil::doubleLerp(
					points[i].waypointRelativePos,
					points[i + 1].waypointRelativePos, 0.5);

			PathPoint before(samplePath(beforeWaypointPos), std::nullopt,
					points[i].constraints);
			before.waypointRelativePos = beforeWaypointPos;
			PathPoint after(samplePath(afterWaypointPos), std::nullopt,
					points[i].constraints);
			after.waypointRelativePos = afterWaypointPos;

			points.insert(points.begin() + i, before);
			points.insert(points.begin() + (i + 2), after);
			i += 2;
		}
	}

	return points;
}

frc::Pose2d PathPlannerPath::getStartingDifferentialPose() {
	frc::Translation2d startPos = getPoint(0).position;
	frc::Rotation2d heading = getInitialHeading();

	if (m_reversed) {
		heading = frc::Rotation2d(
				frc::InputModulus(heading.Degrees() + 180_deg, -180_deg,
						180_deg));
	}

	return frc::Pose2d(startPos, heading);
}

std::optional<PathPlannerTrajectory> PathPlannerPath::getIdealTrajectory(
		RobotConfig robotConfig) {
	if (!m_idealTrajectory.has_value() && m_idealStartingState.has_value()) {
		// The ideal starting state is known, generate the ideal trajectory
		frc::Rotation2d heading = getInitialHeading();
		frc::Translation2d fieldSpeeds(
				units::meter_t { m_idealStartingState.value().getVelocity()() },
				heading);
		frc::ChassisSpeeds startingSpeeds =
				frc::ChassisSpeeds::FromFieldRelativeSpeeds(frc::ChassisSpeeds {
						units::meters_per_second_t { fieldSpeeds.X()() },
						units::meters_per_second_t { fieldSpeeds.Y()() },
						0.0_rad_per_s },
						m_idealStartingState.value().getRotation());
		m_idealTrajectory = generateTrajectory(startingSpeeds,
				m_idealStartingState.value().getRotation(), robotConfig);
	}

	return m_idealTrajectory;
}

void PathPlannerPath::precalcValues() {
	if (numPoints() > 0) {
		for (size_t i = 0; i < m_allPoints.size(); i++) {
			PathConstraints constraints = m_allPoints[i].constraints.value_or(
					m_globalConstraints);
			if (!m_allPoints[i].constraints) {
				m_allPoints[i].constraints = m_globalConstraints;
			}
			units::meter_t curveRadius = units::math::abs(
					getCurveRadiusAtPoint(i, m_allPoints));

			if (GeometryUtil::isFinite(curveRadius)) {
				m_allPoints[i].maxV = units::math::min(
						units::math::sqrt(
								constraints.getMaxAcceleration()
										* units::math::abs(curveRadius)),
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

		m_allPoints[m_allPoints.size() - 1].rotationTarget = RotationTarget(-1,
				m_goalEndState.getRotation());
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

std::shared_ptr<PathPlannerPath> PathPlannerPath::flipPath() {
	std::optional < PathPlannerTrajectory > flippedTraj = std::nullopt;
	if (m_idealTrajectory.has_value()) {
		// Flip the ideal trajectory
		flippedTraj = m_idealTrajectory.value().flip();
	}

	std::vector < Waypoint > newWaypoints;
	for (auto w : m_waypoints) {
		newWaypoints.emplace_back(w.flip());
	}

	std::vector < RotationTarget > newRotTargets;
	for (auto t : m_rotationTargets) {
		newRotTargets.emplace_back(t.getPosition(),
				GeometryUtil::flipFieldRotation(t.getTarget()));
	}

	std::vector < PathPoint > newPoints;
	for (auto p : m_allPoints) {
		newPoints.emplace_back(p.flip());
	}

	GoalEndState newEndState = GoalEndState(m_goalEndState.getVelocity(),
			GeometryUtil::flipFieldRotation(m_goalEndState.getRotation()));

	std::optional < IdealStartingState > newStartState = std::nullopt;
	if (m_idealStartingState.has_value()) {
		newStartState = IdealStartingState(
				m_idealStartingState.value().getVelocity(),
				GeometryUtil::flipFieldRotation(
						m_idealStartingState.value().getRotation()));
	}

	auto path = PathPlannerPath::fromPathPoints(newPoints, m_globalConstraints,
			newEndState);
	path->m_waypoints = newWaypoints;
	path->m_rotationTargets = newRotTargets;
	path->m_constraintZones = m_constraintZones;
	path->m_eventMarkers = m_eventMarkers;
	path->m_idealStartingState = newStartState;
	path->m_reversed = m_reversed;
	path->m_isChoreoPath = m_isChoreoPath;
	path->m_idealTrajectory = flippedTraj;
	path->preventFlipping = preventFlipping;

	return path;
}

frc::Translation2d PathPlannerPath::samplePath(
		double waypointRelativePos) const {
	double pos = std::clamp(waypointRelativePos, 0.0, m_waypoints.size() - 1.0);

	size_t i = static_cast<size_t>(waypointRelativePos);
	if (i == m_waypoints.size() - 1) {
		i--;
	}

	double t = pos - i;

	auto p1 = m_waypoints[i].anchor;
	auto p2 = m_waypoints[i].nextControl.value();
	auto p3 = m_waypoints[i + 1].prevControl.value();
	auto p4 = m_waypoints[i + 1].anchor;
	return GeometryUtil::cubicLerp(p1, p2, p3, p4, t);
}

std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>>& PathPlannerPath::getPathCache() {
	static std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>> *pathCache =
			new std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>>();
	return *pathCache;
}

std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>>& PathPlannerPath::getChoreoPathCache() {
	static std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>> *choreoPathCache =
			new std::unordered_map<std::string, std::shared_ptr<PathPlannerPath>>();
	return *choreoPathCache;
}
