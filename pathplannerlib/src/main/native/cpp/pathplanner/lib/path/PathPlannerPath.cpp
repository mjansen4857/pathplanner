#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include <frc/Filesystem.h>
#include <frc/MathUtil.h>
#include <wpi/MemoryBuffer.h>
#include <limits>
#include <optional>
#include <hal/FRCUsageReporting.h>

using namespace pathplanner;

int PathPlannerPath::m_instances = 0;

PathPlannerPath::PathPlannerPath(std::vector<frc::Translation2d> bezierPoints,
		std::vector<RotationTarget> rotationTargets,
		std::vector<ConstraintsZone> constraintZones,
		std::vector<EventMarker> eventMarkers,
		PathConstraints globalConstraints, GoalEndState goalEndState,
		bool reversed, frc::Rotation2d previewStartingRotation) : m_bezierPoints(
		bezierPoints), m_rotationTargets(rotationTargets), m_constraintZones(
		constraintZones), m_eventMarkers(eventMarkers), m_globalConstraints(
		globalConstraints), m_goalEndState(goalEndState), m_reversed(reversed), m_previewStartingRotation(
		previewStartingRotation), m_isChoreoPath(false), m_choreoTrajectory() {
	m_allPoints = PathPlannerPath::createPath(m_bezierPoints, m_rotationTargets,
			m_constraintZones);

	precalcValues();

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerPath, m_instances);
}

PathPlannerPath::PathPlannerPath(PathConstraints constraints,
		GoalEndState goalEndState) : m_bezierPoints(), m_rotationTargets(), m_constraintZones(), m_eventMarkers(), m_globalConstraints(
		constraints), m_goalEndState(goalEndState), m_reversed(false), m_previewStartingRotation(), m_isChoreoPath(
		false), m_choreoTrajectory() {
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
	m_goalEndState = updatedPath->m_goalEndState;
	m_reversed = updatedPath->m_reversed;
	m_allPoints = updatedPath->m_allPoints;
	m_previewStartingRotation = updatedPath->m_previewStartingRotation;
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

	std::error_code error_code;
	std::unique_ptr < wpi::MemoryBuffer > fileBuffer =
			wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (fileBuffer == nullptr || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	std::shared_ptr < PathPlannerPath > path = PathPlannerPath::fromJson(json);
	PPLibTelemetry::registerHotReloadPath(pathName, path);
	return path;
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::fromChoreoTrajectory(
		std::string trajectoryName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/choreo/" + trajectoryName + ".traj";

	std::error_code error_code;
	std::unique_ptr < wpi::MemoryBuffer > fileBuffer =
			wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (fileBuffer == nullptr || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	std::vector < PathPlannerTrajectory::State > trajStates;
	for (wpi::json::const_reference s : json.at("samples")) {
		PathPlannerTrajectory::State state;

		units::second_t time { s.at("timestamp").get<double>() };
		units::meter_t xPos { s.at("x").get<double>() };
		units::meter_t yPos { s.at("y").get<double>() };
		units::radian_t rotationRad { s.at("heading").get<double>() };
		units::meters_per_second_t xVel { s.at("velocityX").get<double>() };
		units::meters_per_second_t yVel { s.at("velocityY").get<double>() };
		units::radians_per_second_t angularVelRps { s.at("angularVelocity").get<
				double>() };

		state.time = time;
		state.velocity = units::math::hypot(xVel, yVel);
		state.acceleration = 0_mps_sq; // Not encoded, not needed anyway
		state.headingAngularVelocity = 0_rad_per_s; // Not encoded, only used for diff drive anyway
		state.position = frc::Translation2d(xPos, yPos);
		state.heading = frc::Rotation2d(xVel(), yVel());
		state.targetHolonomicRotation = frc::Rotation2d(rotationRad);
		state.holonomicAngularVelocityRps = angularVelRps;
		state.curvature = units::curvature_t { 0.0 };
		state.constraints = PathConstraints(units::meters_per_second_t {
				std::numeric_limits<double>::infinity() },
				units::meters_per_second_squared_t {
						std::numeric_limits<double>::infinity() },
				units::radians_per_second_t {
						std::numeric_limits<double>::infinity() },
				units::radians_per_second_squared_t {
						std::numeric_limits<double>::infinity() });

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
					trajStates[trajStates.size() - 1].velocity,
					trajStates[trajStates.size() - 1].targetHolonomicRotation,
					true));

	std::vector < PathPoint > pathPoints;
	for (auto state : trajStates) {
		pathPoints.emplace_back(state.position);
	}

	path->m_allPoints = pathPoints;
	path->m_isChoreoPath = true;
	path->m_choreoTrajectory = PathPlannerTrajectory(trajStates);

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

	frc::Rotation2d previewStartingRotation;
	if (json.contains("previewStartingState")
			&& !json.at("previewStartingState").is_null()) {
		auto jsonStartingState = json.at("previewStartingState");
		previewStartingRotation = frc::Rotation2d(
				units::degree_t(
						jsonStartingState.at("rotation").get<double>()));
	}

	return std::make_shared < PathPlannerPath
			> (bezierPoints, rotationTargets, constraintZones, eventMarkers, globalConstraints, goalEndState, reversed, previewStartingRotation);
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

frc::Pose2d PathPlannerPath::getStartingDifferentialPose() {
	frc::Translation2d startPos = getPoint(0).position;
	frc::Rotation2d heading =
			(getPoint(1).position - getPoint(0).position).Angle();

	if (m_reversed) {
		heading = frc::Rotation2d(
				frc::InputModulus(heading.Degrees() + 180_deg, -180_deg,
						180_deg));
	}

	return frc::Pose2d(startPos, heading);
}

frc::Pose2d PathPlannerPath::getPreviewStartingHolonomicPose() {
	return frc::Pose2d(getPoint(0).position, m_previewStartingRotation);
}

void PathPlannerPath::precalcValues() {
	if (numPoints() > 0) {
		for (size_t i = 0; i < m_allPoints.size(); i++) {
			PathConstraints constraints = m_allPoints[i].constraints.value_or(
					m_globalConstraints);
			if (!m_allPoints[i].constraints) {
				m_allPoints[i].constraints = m_globalConstraints;
			}
			m_allPoints[i].curveRadius = units::math::abs(
					getCurveRadiusAtPoint(i, m_allPoints));

			if (GeometryUtil::isFinite(m_allPoints[i].curveRadius)) {
				m_allPoints[i].maxV = units::math::min(
						units::math::sqrt(
								constraints.getMaxAcceleration()
										* units::math::abs(
												m_allPoints[i].curveRadius)),
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

		m_allPoints[m_allPoints.size() - 1].rotationTarget = RotationTarget(-1,
				m_goalEndState.getRotation(),
				m_goalEndState.shouldRotateFast());
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

std::shared_ptr<PathPlannerPath> PathPlannerPath::replan(
		const frc::Pose2d startingPose,
		const frc::ChassisSpeeds currentSpeeds) {
	if (m_isChoreoPath) {
		// This path is from choreo, cannot be replanned
		return shared_from_this();
	}

	frc::ChassisSpeeds currentFieldRelativeSpeeds =
			frc::ChassisSpeeds::FromFieldRelativeSpeeds(currentSpeeds,
					-startingPose.Rotation());

	std::optional < frc::Translation2d > robotNextControl = std::nullopt;
	units::meters_per_second_t linearVel = units::math::hypot(
			currentFieldRelativeSpeeds.vx, currentFieldRelativeSpeeds.vy);
	if (linearVel > 0.1_mps) {
		units::meter_t stoppingDistance = units::math::pow < 2
				> (linearVel) / (2 * m_globalConstraints.getMaxAcceleration());

		frc::Rotation2d heading(currentFieldRelativeSpeeds.vx(),
				currentFieldRelativeSpeeds.vy());
		robotNextControl = startingPose.Translation()
				+ frc::Translation2d(stoppingDistance, heading);
	}

	size_t closestPointIdx = 0;
	frc::Translation2d comparePoint = robotNextControl.value_or(
			startingPose.Translation());
	units::meter_t closestDist = positionDelta(comparePoint,
			getPoint(closestPointIdx).position);

	for (size_t i = 1; i < numPoints(); i++) {
		units::meter_t d = positionDelta(comparePoint, getPoint(i).position);

		if (d < closestDist) {
			closestPointIdx = i;
			closestDist = d;
		}
	}

	if (closestPointIdx == numPoints() - 1) {
		frc::Rotation2d heading = (getPoint(numPoints() - 1).position
				- comparePoint).Angle();

		if (!robotNextControl) {
			robotNextControl = startingPose.Translation()
					+ frc::Translation2d(closestDist / 3.0, heading);
		}

		frc::Rotation2d endPrevControlHeading =
				(getPoint(numPoints() - 1).position - robotNextControl.value()).Angle();

		frc::Translation2d endPrevControl = getPoint(numPoints() - 1).position
				- frc::Translation2d(closestDist / 3.0, endPrevControlHeading);

		// Throw out rotation targets, event markers, and constraint zones since we are skipping all
		// of the path
		return std::make_shared < PathPlannerPath
				> (std::vector < frc::Translation2d > ( {
							startingPose.Translation(),
							robotNextControl.value(),
							endPrevControl,
							getPoint(numPoints() - 1).position
						}), std::vector<RotationTarget>(), std::vector<
						ConstraintsZone>(), std::vector<EventMarker>(), m_globalConstraints, m_goalEndState, m_reversed);
	} else if ((closestPointIdx == 0 && !robotNextControl)
			|| (units::math::abs(
					closestDist
							- startingPose.Translation().Distance(
									getPoint(0).position)) <= 0.25_m
					&& linearVel < 0.1_mps)) {
		units::meter_t distToStart = startingPose.Translation().Distance(
				getPoint(0).position);

		frc::Rotation2d heading = (getPoint(0).position
				- startingPose.Translation()).Angle();
		robotNextControl = startingPose.Translation()
				+ frc::Translation2d(distToStart / 3.0, heading);

		frc::Rotation2d joinHeading = (m_allPoints[0].position
				- m_allPoints[1].position).Angle();
		frc::Translation2d joinPrevControl = getPoint(0).position
				+ frc::Translation2d(distToStart / 2.0, joinHeading);

		if (m_bezierPoints.empty()) {
			// We don't have any bezier points to reference
			PathSegment joinSegment(startingPose.Translation(),
					robotNextControl.value(), joinPrevControl,
					m_allPoints[0].position, false);
			std::vector < PathPoint > replannedPoints;
			auto joinPoints = joinSegment.getSegmentPoints();
			replannedPoints.insert(replannedPoints.end(), joinPoints.begin(),
					joinPoints.end());
			replannedPoints.insert(replannedPoints.end(), m_allPoints.begin(),
					m_allPoints.end());

			return PathPlannerPath::fromPathPoints(replannedPoints,
					m_globalConstraints, m_goalEndState);
		} else {
			// We can use the bezier points
			std::vector < frc::Translation2d
					> replannedBezier( { startingPose.Translation(),
							robotNextControl.value(), joinPrevControl });
			replannedBezier.insert(replannedBezier.end(),
					m_bezierPoints.begin(), m_bezierPoints.end());

			// keep all rotations, markers, and zones and increment waypoint pos by 1
			std::vector < RotationTarget > targets;
			std::transform(m_rotationTargets.begin(), m_rotationTargets.end(),
					std::back_inserter(targets),
					[](RotationTarget target) {
						return RotationTarget(target.getPosition() + 1,
								target.getTarget(), target.shouldRotateFast());
					});
			std::vector < ConstraintsZone > zones;
			std::transform(m_constraintZones.begin(), m_constraintZones.end(),
					std::back_inserter(zones),
					[](ConstraintsZone zone) {
						return ConstraintsZone(
								zone.getMinWaypointRelativePos() + 1,
								zone.getMaxWaypointRelativePos() + 1,
								zone.getConstraints());
					});
			std::vector < EventMarker > markers;
			std::transform(m_eventMarkers.begin(), m_eventMarkers.end(),
					std::back_inserter(markers),
					[](EventMarker marker) {
						return EventMarker(marker.getWaypointRelativePos() + 1,
								marker.getCommand(),
								marker.getMinimumTriggerDistance());
					});

			return std::make_shared < PathPlannerPath
					> (replannedBezier, targets, zones, markers, m_globalConstraints, m_goalEndState, m_reversed);
		}
	}

	size_t joinAnchorIdx = numPoints() - 1;
	for (size_t i = closestPointIdx; i < numPoints(); i++) {
		if (getPoint(i).distanceAlongPath
				>= getPoint(closestPointIdx).distanceAlongPath + closestDist) {
			joinAnchorIdx = i;
			break;
		}
	}

	frc::Translation2d joinPrevControl = getPoint(closestPointIdx).position;
	frc::Translation2d joinAnchor = getPoint(joinAnchorIdx).position;

	if (!robotNextControl) {
		units::meter_t robotToJoinDelta = startingPose.Translation().Distance(
				joinAnchor);
		frc::Rotation2d heading =
				(joinPrevControl - startingPose.Translation()).Angle();
		robotNextControl = startingPose.Translation()
				+ frc::Translation2d(robotToJoinDelta / 3.0, heading);
	}

	if (joinAnchorIdx == numPoints() - 1) {
		// Throw out rotation targets, event markers, and constraint zones since we are skipping all
		// of the path
		return std::make_shared < PathPlannerPath
				> (std::vector < frc::Translation2d > ( {
							startingPose.Translation(),
							robotNextControl.value(),
							joinPrevControl,
							joinAnchor
						}), std::vector<RotationTarget>(), std::vector<
						ConstraintsZone>(), std::vector<EventMarker>(), m_globalConstraints, m_goalEndState, m_reversed);
	}

	if (m_bezierPoints.empty()) {
		// We don't have any bezier points to reference
		PathSegment joinSegment(startingPose.Translation(),
				robotNextControl.value(), joinPrevControl, joinAnchor, false);
		std::vector < PathPoint > replannedPoints;
		auto joinPoints = joinSegment.getSegmentPoints();
		replannedPoints.insert(replannedPoints.end(), joinPoints.begin(),
				joinPoints.end());
		replannedPoints.insert(replannedPoints.end(),
				m_allPoints.begin() + joinAnchorIdx, m_allPoints.end());

		return PathPlannerPath::fromPathPoints(replannedPoints,
				m_globalConstraints, m_goalEndState);
	}

	// We can reference bezier points
	size_t nextWaypointIdx = static_cast<size_t>(std::ceil(
			(joinAnchorIdx + 1) * PathSegment::RESOLUTION));
	size_t bezierPointIdx = nextWaypointIdx * 3;
	units::meter_t waypointDelta = joinAnchor.Distance(
			m_bezierPoints[bezierPointIdx]);

	frc::Rotation2d joinHeading = (joinAnchor - joinPrevControl).Angle();
	frc::Translation2d joinNextControl = joinAnchor
			+ frc::Translation2d(waypointDelta / 3.0, joinHeading);

	frc::Rotation2d nextWaypointHeading;
	if (bezierPointIdx == m_bezierPoints.size() - 1) {
		nextWaypointHeading = (m_bezierPoints[bezierPointIdx - 1]
				- m_bezierPoints[bezierPointIdx]).Angle();
	} else {
		nextWaypointHeading = (m_bezierPoints[bezierPointIdx]
				- m_bezierPoints[bezierPointIdx + 1]).Angle();
	}

	frc::Translation2d nextWaypointPrevControl = m_bezierPoints[bezierPointIdx]
			+ frc::Translation2d(units::math::max(waypointDelta / 3.0, 0.15_m),
					nextWaypointHeading);

	std::vector < frc::Translation2d
			> replannedBezier(
					{ startingPose.Translation(), robotNextControl.value(),
							joinPrevControl, joinAnchor, joinNextControl,
							nextWaypointPrevControl });
	replannedBezier.insert(replannedBezier.end(),
			m_bezierPoints.begin() + bezierPointIdx, m_bezierPoints.end());

	units::meter_t segment1Length = 0_m;
	frc::Translation2d lastSegment1Pos = startingPose.Translation();
	units::meter_t segment2Length = 0_m;
	frc::Translation2d lastSegment2Pos = joinAnchor;

	for (double t = PathSegment::RESOLUTION; t < 1.0; t +=
			PathSegment::RESOLUTION) {
		frc::Translation2d p1 = GeometryUtil::cubicLerp(
				startingPose.Translation(), robotNextControl.value(),
				joinPrevControl, joinAnchor, t);
		frc::Translation2d p2 = GeometryUtil::cubicLerp(joinAnchor,
				joinNextControl, nextWaypointPrevControl,
				m_bezierPoints[bezierPointIdx], t);

		segment1Length += positionDelta(lastSegment1Pos, p1);
		segment2Length += positionDelta(lastSegment2Pos, p2);

		lastSegment1Pos = p1;
		lastSegment2Pos = p2;
	}

	double segment1Pct = segment1Length()
			/ (segment1Length() + segment2Length());

	std::vector < RotationTarget > mappedTargets;
	std::vector < ConstraintsZone > mappedZones;
	std::vector < EventMarker > mappedMarkers;

	for (RotationTarget t : m_rotationTargets) {
		if (t.getPosition() >= nextWaypointIdx) {
			mappedTargets.emplace_back(t.getPosition() - nextWaypointIdx + 2,
					t.getTarget(), t.shouldRotateFast());
		} else if (t.getPosition() >= nextWaypointIdx - 1) {
			double pct = t.getPosition() - (nextWaypointIdx - 1);
			mappedTargets.emplace_back(mapPct(pct, segment1Pct), t.getTarget(),
					t.shouldRotateFast());
		}
	}

	for (ConstraintsZone z : m_constraintZones) {
		double minPos = 0;
		double maxPos = 0;

		if (z.getMinWaypointRelativePos() >= nextWaypointIdx) {
			minPos = z.getMinWaypointRelativePos() - nextWaypointIdx + 2;
		} else if (z.getMinWaypointRelativePos() >= nextWaypointIdx - 1) {
			double pct = z.getMinWaypointRelativePos() - (nextWaypointIdx - 1);
			minPos = mapPct(pct, segment1Pct);
		}

		if (z.getMaxWaypointRelativePos() >= nextWaypointIdx) {
			maxPos = z.getMaxWaypointRelativePos() - nextWaypointIdx + 2;
		} else if (z.getMaxWaypointRelativePos() >= nextWaypointIdx - 1) {
			double pct = z.getMaxWaypointRelativePos() - (nextWaypointIdx - 1);
			maxPos = mapPct(pct, segment1Pct);
		}

		if (maxPos > 0) {
			mappedZones.emplace_back(minPos, maxPos, z.getConstraints());
		}
	}

	for (EventMarker m : m_eventMarkers) {
		if (m.getWaypointRelativePos() >= nextWaypointIdx) {
			mappedMarkers.emplace_back(
					m.getWaypointRelativePos() - nextWaypointIdx + 2,
					m.getCommand(), m.getMinimumTriggerDistance());
		} else if (m.getWaypointRelativePos() >= nextWaypointIdx - 1) {
			double pct = m.getWaypointRelativePos() - (nextWaypointIdx - 1);
			mappedMarkers.emplace_back(mapPct(pct, segment1Pct), m.getCommand(),
					m.getMinimumTriggerDistance());
		}
	}

	// Throw out everything before nextWaypointIdx - 1, map everything from nextWaypointIdx -
	// 1 to nextWaypointIdx on to the 2 joining segments (waypoint rel pos within old segment = %
	// along distance of both new segments)
	return std::make_shared < PathPlannerPath
			> (replannedBezier, mappedTargets, mappedZones, mappedMarkers, m_globalConstraints, m_goalEndState, m_reversed);
}

std::shared_ptr<PathPlannerPath> PathPlannerPath::flipPath() {
	if (m_isChoreoPath) {
		// Just mirror the choreo traj
		std::vector < PathPlannerTrajectory::State > mirroredStates;
		for (auto state : m_choreoTrajectory.getStates()) {
			PathPlannerTrajectory::State mirrored;

			mirrored.time = state.time;
			mirrored.velocity = state.velocity;
			mirrored.acceleration = state.acceleration;
			mirrored.headingAngularVelocity = -state.headingAngularVelocity;
			mirrored.position = GeometryUtil::flipFieldPosition(state.position);
			mirrored.heading = GeometryUtil::flipFieldRotation(state.heading);
			mirrored.targetHolonomicRotation = GeometryUtil::flipFieldRotation(
					state.targetHolonomicRotation);
			mirrored.holonomicAngularVelocityRps =
					state.holonomicAngularVelocityRps;
			if (mirrored.holonomicAngularVelocityRps) {
				mirrored.holonomicAngularVelocityRps =
						-mirrored.holonomicAngularVelocityRps.value();
			}
			mirrored.curvature = -state.curvature;
			mirrored.constraints = state.constraints;
			mirroredStates.emplace_back(mirrored);
		}

		auto path =
				std::make_shared < PathPlannerPath
						> (PathConstraints(units::meters_per_second_t {
								std::numeric_limits<double>::infinity() },
								units::meters_per_second_squared_t {
										std::numeric_limits<double>::infinity() },
								units::radians_per_second_t {
										std::numeric_limits<double>::infinity() },
								units::radians_per_second_squared_t {
										std::numeric_limits<double>::infinity() }), GoalEndState(
								mirroredStates[mirroredStates.size() - 1].velocity,
								mirroredStates[mirroredStates.size() - 1].targetHolonomicRotation,
								true));

		std::vector < PathPoint > pathPoints;
		for (auto state : mirroredStates) {
			pathPoints.emplace_back(state.position);
		}

		path->m_allPoints = pathPoints;
		path->m_isChoreoPath = true;
		path->m_choreoTrajectory = PathPlannerTrajectory(mirroredStates);

		return path;
	}

	std::vector < frc::Translation2d > newBezier;
	std::vector < RotationTarget > newRotTargets;
	std::vector < EventMarker > newMarkers;
	GoalEndState newEndState = GoalEndState(m_goalEndState.getVelocity(),
			-m_goalEndState.getRotation(), m_goalEndState.shouldRotateFast());
	frc::Rotation2d newPreviewRot = -m_previewStartingRotation;

	for (auto p : m_bezierPoints) {
		newBezier.emplace_back(GeometryUtil::flipFieldPosition(p));
	}

	for (auto t : m_rotationTargets) {
		newRotTargets.emplace_back(t.getPosition(),
				GeometryUtil::flipFieldRotation(t.getTarget()),
				t.shouldRotateFast());
	}

	for (auto e : m_eventMarkers) {
		newMarkers.emplace_back(e.getWaypointRelativePos(), e.getCommand(),
				e.getMinimumTriggerDistance());
	}

	return std::make_shared < PathPlannerPath
			> (newBezier, newRotTargets, m_constraintZones, newMarkers, m_globalConstraints, newEndState, m_reversed, newPreviewRot);
}
