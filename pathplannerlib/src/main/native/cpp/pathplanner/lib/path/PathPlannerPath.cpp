#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include <frc/Filesystem.h>
#include <frc/MathUtil.h>
#include <wpi/MemoryBuffer.h>
#include <limits>
#include <optional>
#include <utility>
#include <hal/FRCUsageReporting.h>

using namespace pathplanner;

int PathPlannerPath::m_instances = 0;

PathPlannerPath::PathPlannerPath(std::vector<frc::Translation2d> bezierPoints,
		std::vector<RotationTarget> rotationTargets,
		std::vector<ConstraintsZone> constraintZones,
		std::vector<EventMarker> eventMarkers,
		PathConstraints globalConstraints,
		std::optional<IdealStartingState> idealStartingState,
		GoalEndState goalEndState, bool reversed) : m_bezierPoints(
		bezierPoints), m_rotationTargets(rotationTargets), m_constraintZones(
		constraintZones), m_eventMarkers(eventMarkers), m_globalConstraints(
		globalConstraints), m_idealStartingState(idealStartingState), m_goalEndState(
		goalEndState), m_reversed(reversed), m_isChoreoPath(false) {
	std::sort(m_rotationTargets.begin(), m_rotationTargets.end(),
			[](auto &left, auto &right) {
				return left.getPosition() < right.getPosition();
			});
	std::sort(m_eventMarkers.begin(), m_eventMarkers.end(),
			[](auto &left, auto &right) {
				return left.getWaypointRelativePos()
						< right.getWaypointRelativePos();
			});

	createPath();

	precalcValues();

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerPath, m_instances);
}

PathPlannerPath::PathPlannerPath(PathConstraints constraints,
		GoalEndState goalEndState) : m_bezierPoints(), m_rotationTargets(), m_constraintZones(), m_eventMarkers(), m_globalConstraints(
		constraints), m_idealStartingState(std::nullopt), m_goalEndState(
		goalEndState), m_reversed(false), m_isChoreoPath(false) {
	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerPath, m_instances);
}

void PathPlannerPath::hotReload(const wpi::json &json) {
	auto updatedPath = PathPlannerPath::fromJson(json);

	m_bezierPoints = updatedPath->m_bezierPoints;
	m_rotationTargets = updatedPath->m_rotationTargets;
	m_constraintZones = updatedPath->m_constraintZones;
	m_eventMarkers = updatedPath->m_eventMarkers;
	m_globalConstraints = updatedPath->m_globalConstraints;
	m_idealStartingState = updatedPath->m_idealStartingState;
	m_goalEndState = updatedPath->m_goalEndState;
	m_reversed = updatedPath->m_reversed;
	m_allPoints = updatedPath->m_allPoints;
}

std::vector<frc::Translation2d> PathPlannerPath::bezierFromPoses(
		std::vector<frc::Pose2d> poses) {
	if (poses.size() < 2) {
		throw FRC_MakeError(frc::err::InvalidParameter,
				"Not enough poses provided to bezierFromPoses");
	}

	std::vector < frc::Translation2d > bezierPoints;

	// First pose
	bezierPoints.emplace_back(poses[0].Translation());
	bezierPoints.emplace_back(
			poses[0].Translation()
					+ frc::Translation2d(
							poses[0].Translation().Distance(
									poses[1].Translation()) / 3.0,
							poses[0].Rotation()));

	// Middle poses
	for (size_t i = 1; i < poses.size() - 1; i++) {
		frc::Translation2d anchor = poses[i].Translation();

		// Prev control
		bezierPoints.emplace_back(
				anchor
						+ frc::Translation2d(
								anchor.Distance(poses[i - 1].Translation())
										/ 3.0,
								poses[i].Rotation()
										+ frc::Rotation2d(180_deg)));
		// Anchor
		bezierPoints.emplace_back(anchor);
		// Next control
		bezierPoints.emplace_back(
				anchor
						+ frc::Translation2d(
								anchor.Distance(poses[i + 1].Translation())
										/ 3.0, poses[i].Rotation()));
	}

	// Last pose
	bezierPoints.emplace_back(
			poses[poses.size() - 1].Translation()
					+ frc::Translation2d(
							poses[poses.size() - 1].Translation().Distance(
									poses[poses.size() - 2].Translation())
									/ 3.0,
							poses[poses.size() - 1].Rotation()
									+ frc::Rotation2d(180_deg)));
	bezierPoints.emplace_back(poses[poses.size() - 1].Translation());

	return bezierPoints;
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromPathFile(
		std::string pathName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/paths/" + pathName + ".path";

	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer.value()->GetCharBuffer());

	std::shared_ptr < PathPlannerPath > path = PathPlannerPath::fromJson(json);
	PPLibTelemetry::registerHotReloadPath(pathName, path);
	return path;
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromChoreoTrajectory(
		std::string trajectoryName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/choreo/" + trajectoryName + ".traj";

	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer.value()->GetCharBuffer());

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

	std::vector < std::pair<units::second_t, std::shared_ptr<frc2::Command>>
			> eventCommands;
	if (json.contains("eventMarkers")) {
		for (wpi::json::const_reference m : json.at("eventMarkers")) {
			units::second_t timestamp { m.at("timestamp").get<double>() };

			EventMarker eventMarker = EventMarker(timestamp(),
					CommandUtil::commandFromJson(m.at("command"), false));

			path->m_eventMarkers.emplace_back(eventMarker);
			eventCommands.emplace_back(timestamp, eventMarker.getCommand());
		}
	}

	std::sort(eventCommands.begin(), eventCommands.end(),
			[](auto &left, auto &right) {
				return left.first < right.first;
			});

	path->m_idealTrajectory = PathPlannerTrajectory(trajStates, eventCommands);

	return path;
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromJson(
		const wpi::json &json) {
	std::vector < frc::Translation2d > bezierPoints =
			PathPlannerPath::bezierPointsFromWaypointsJson(
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
			> (bezierPoints, rotationTargets, constraintZones, eventMarkers, globalConstraints, idealStartingState, goalEndState, reversed);
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
	auto x = units::meter_t(json.at("x").get<double>());
	auto y = units::meter_t(json.at("y").get<double>());

	return frc::Translation2d(x, y);
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
	if (m_bezierPoints.size() < 4 || (m_bezierPoints.size() - 1) % 3 != 0) {
		throw std::runtime_error("Invalid number of bezier points");
	}

	size_t numSegments = (m_bezierPoints.size() - 1) / 3;

	std::vector < PathPoint > points;

	for (size_t s = 0; s < numSegments; s++) {
		size_t iOffset = s * 3;
		frc::Translation2d p1 = m_bezierPoints[iOffset];
		frc::Translation2d p2 = m_bezierPoints[iOffset + 1];
		frc::Translation2d p3 = m_bezierPoints[iOffset + 2];
		frc::Translation2d p4 = m_bezierPoints[iOffset + 3];
		PathSegment segment(p1, p2, p3, p4);

		segment.generatePathPoints(points, s, m_constraintZones,
				m_rotationTargets, m_globalConstraints);
	}

	// Add the final path point
	PathConstraints endConstraints = m_globalConstraints;
	for (const ConstraintsZone &z : m_constraintZones) {
		if (numSegments >= z.getMinWaypointRelativePos()
				&& numSegments <= z.getMaxWaypointRelativePos()) {
			endConstraints = z.getConstraints();
			break;
		}
	}
	points.emplace_back(m_bezierPoints[m_bezierPoints.size() - 1],
			RotationTarget(numSegments, m_goalEndState.getRotation()),
			endConstraints);
	points[points.size() - 1].waypointRelativePos = numSegments;

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
		std::vector < PathPlannerTrajectoryState > mirroredStates;
		for (auto state : m_idealTrajectory.value().getStates()) {
			PathPlannerTrajectoryState mirrored;

			mirrored.time = state.time;
			mirrored.linearVelocity = state.linearVelocity;
			mirrored.pose = GeometryUtil::flipFieldPose(state.pose);
			mirrored.fieldSpeeds = frc::ChassisSpeeds { -state.fieldSpeeds.vx,
					state.fieldSpeeds.vy, -state.fieldSpeeds.omega };
			mirroredStates.emplace_back(mirrored);
		}
		flippedTraj = PathPlannerTrajectory(mirroredStates,
				m_idealTrajectory.value().getEventCommands());
	}

	std::vector < frc::Translation2d > newBezier;
	for (auto p : m_bezierPoints) {
		newBezier.emplace_back(GeometryUtil::flipFieldPosition(p));
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
	path->m_bezierPoints = newBezier;
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
