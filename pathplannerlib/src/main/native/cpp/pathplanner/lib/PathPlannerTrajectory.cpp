#include "frc/MathUtil.h"
#include "pathplanner/lib/PathPlannerTrajectory.h"
#include "pathplanner/lib/GeometryUtil.h"
#include "pathplanner/lib/PathPlanner.h"
#include <math.h>
#include <limits>

using namespace pathplanner;

PathPlannerTrajectory::PathPlannerTrajectory(
		std::vector<Waypoint> const &waypoints,
		std::vector<EventMarker> const &markers,
		PathConstraints const constraints, bool const reversed,
		bool const fromGUI) {
	this->states = generatePath(waypoints, constraints.maxVelocity,
			constraints.maxAcceleration, reversed);

	this->markers = markers;
	this->calculateMarkerTimes(waypoints);

	this->startStopEvent = waypoints[0].stopEvent;
	this->endStopEvent = waypoints[waypoints.size() - 1].stopEvent;
	this->fromGUI = fromGUI;
}

std::vector<PathPlannerTrajectory::PathPlannerState> PathPlannerTrajectory::generatePath(
		std::vector<Waypoint> const &pathPoints,
		units::meters_per_second_t const maxVel,
		units::meters_per_second_squared_t const maxAccel,
		bool const reversed) {
	std::vector < std::vector < Waypoint >> splitPaths;
	std::vector < Waypoint > currentPath;

	for (size_t i = 0; i < pathPoints.size(); i++) {
		Waypoint const w = pathPoints[i];

		currentPath.emplace_back(w);

		if ((i != 0 && w.isReversal) || i == pathPoints.size() - 1) {
			splitPaths.emplace_back(currentPath);
			currentPath = std::vector<Waypoint>();
			currentPath.emplace_back(w);
		}
	}

	std::vector < std::vector < PathPlannerState >> splitStates;
	bool shouldReverse = reversed;
	for (size_t i = 0; i < splitPaths.size(); i++) {
		std::vector < PathPlannerState > joined = joinSplines(splitPaths[i],
				maxVel, PathPlanner::resolution);
		calculateMaxVel(joined, maxVel, maxAccel, shouldReverse);
		calculateVelocity(joined, splitPaths[i], maxAccel);
		recalculateValues(joined, shouldReverse);
		splitStates.emplace_back(std::move(joined));
		shouldReverse = !shouldReverse;
	}

	std::vector < PathPlannerState > joinedStates;
	for (size_t i = 0; i < splitStates.size(); i++) {
		if (i != 0) {
			units::second_t const lastEndTime = joinedStates[joinedStates.size()
					- 1].time;
			for (PathPlannerState &state : splitStates[i]) {
				state.time += lastEndTime;
			}
		}

		for (PathPlannerState const &state : splitStates[i]) {
			joinedStates.emplace_back(state);
		}
	}

	return joinedStates;
}

void PathPlannerTrajectory::calculateMarkerTimes(
		std::vector<Waypoint> const &pathPoints) {
	for (EventMarker &marker : this->markers) {
		size_t startIndex = (size_t) marker.waypointRelativePos;
		double t = std::fmod(marker.waypointRelativePos, 1.0);

		if (startIndex == pathPoints.size() - 1) {
			startIndex--;
			t = 1.0;
		}

		Waypoint const startPoint = pathPoints[startIndex];
		Waypoint const endPoint = pathPoints[startIndex + 1];

		marker.position = GeometryUtil::cubicLerp(startPoint.anchorPoint,
				startPoint.nextControl, endPoint.prevControl,
				endPoint.anchorPoint, t);

		int const statesPerWaypoint = (int) (1.0 / PathPlanner::resolution);
		startIndex = (size_t)(
				(statesPerWaypoint * marker.waypointRelativePos)
						- std::floor(marker.waypointRelativePos));
		t = std::fmod(statesPerWaypoint * marker.waypointRelativePos, 1.0);

		if (startIndex == getStates().size() - 1) {
			startIndex--;
			t = 1;
		}

		units::second_t const start = getState(startIndex).time;
		units::second_t const end = getState(startIndex + 1).time;

		marker.time = GeometryUtil::unitLerp(start, end, t);
	}

	// Ensure the markers are sorted by time
	std::sort(this->markers.begin(), this->markers.end(),
			[](EventMarker &a, EventMarker &b) {
				return a.time < b.time;
			});
}

std::vector<PathPlannerTrajectory::PathPlannerState> PathPlannerTrajectory::joinSplines(
		std::vector<Waypoint> const &pathPoints,
		units::meters_per_second_t const maxVel, double const step) {
	std::vector < PathPlannerState > states;
	int const numSplines = pathPoints.size() - 1;

	for (int i = 0; i < numSplines; i++) {
		Waypoint const startPoint = pathPoints[i];
		Waypoint const endPoint = pathPoints[i + 1];

		double endStep = (i == numSplines - 1) ? 1.0 : 1.0 - step;
		for (double t = 0; t <= endStep; t += step) {
			frc::Translation2d const p = GeometryUtil::cubicLerp(
					startPoint.anchorPoint, startPoint.nextControl,
					endPoint.prevControl, endPoint.anchorPoint, t);

			PathPlannerState state { };
			state.pose = frc::Pose2d(p, state.pose.Rotation());

			frc::Rotation2d startRot = startPoint.holonomicRotation;
			frc::Rotation2d endRot = endPoint.holonomicRotation;

			int startSearchOffset = 0;
			int endSearchOffset = 0;

			while (startRot.Radians() == 999_rad || endRot.Radians() == 999_rad) {
				if (startRot.Radians() == 999_rad) {
					startSearchOffset++;
					startRot =
							pathPoints[i - startSearchOffset].holonomicRotation;
				}
				if (endRot.Radians() == 999_rad) {
					endSearchOffset++;
					endRot =
							pathPoints[i + 1 + endSearchOffset].holonomicRotation;
				}
			}

			units::degree_t deltaRot = (endRot - startRot).Degrees();
			deltaRot = frc::InputModulus(deltaRot, -180_deg, 180_deg);

			int const startRotIndex = i - startSearchOffset;
			int const endRotIndex = i + 1 + endSearchOffset;
			int const rotRange = endRotIndex - startRotIndex;

			units::degree_t const holonomicRot =
					GeometryUtil::cosineInterpolate(startRot,
							frc::Rotation2d(startRot.Degrees() + deltaRot),
							((i + t) - startRotIndex) / rotRange).Degrees();
			state.holonomicRotation = frc::Rotation2d(
					frc::InputModulus(holonomicRot, -180_deg, 180_deg));

			if (i > 0 || t > 0) {
				PathPlannerState const &s1 = states[states.size() - 1];
				PathPlannerState const &s2 = state;
				units::meter_t const hypot = s1.pose.Translation().Distance(
						s2.pose.Translation());
				state.deltaPos = hypot;

				units::radian_t const heading = units::math::atan2(
						s1.pose.Y() - s2.pose.Y(), s1.pose.X() - s2.pose.X())
						+ units::radian_t { PI };

				units::radian_t const wrapped_heading = frc::InputModulus(
						heading, (units::radian_t) - PI, (units::radian_t) PI);
				state.pose = frc::Pose2d(state.pose.Translation(),
						frc::Rotation2d(wrapped_heading));

				if (i == 0 && t == step) {
					states[states.size() - 1].pose = frc::Pose2d(
							states[states.size() - 1].pose.Translation(),
							frc::Rotation2d(heading));
				}
			}

			if (t == 0.0) {
				state.velocity = startPoint.velocityOverride;
			} else if (t >= 1.0) {
				state.velocity = endPoint.velocityOverride;
			} else {
				state.velocity = maxVel;
			}

			if (state.velocity == -1_mps) {
				state.velocity = maxVel;
			}

			states.emplace_back(state);
		}
	}
	return states;
}

void PathPlannerTrajectory::calculateMaxVel(
		std::vector<PathPlannerState> &states,
		units::meters_per_second_t const maxVel,
		units::meters_per_second_squared_t const maxAccel,
		bool const reversed) {
	for (size_t i = 0; i < states.size(); i++) {
		units::meter_t radius;
		if (i == states.size() - 1) {
			radius = calculateRadius(states[i - 2], states[i - 1], states[i]);
		} else if (i == 0) {
			radius = calculateRadius(states[i], states[i + 1], states[i + 2]);
		} else {
			radius = calculateRadius(states[i - 1], states[i], states[i + 1]);
		}

		if (reversed) {
			radius *= -1;
		}

		if (!GeometryUtil::isFinite(radius) || GeometryUtil::isNaN(radius)) {
			states[i].velocity = units::math::min(maxVel, states[i].velocity);
		} else {
			states[i].curveRadius = radius;

			units::meters_per_second_t const maxVCurve = units::math::sqrt(
					maxAccel * units::math::abs(radius));

			states[i].velocity = units::math::min(maxVCurve,
					states[i].velocity);
		}
	}
}

void PathPlannerTrajectory::calculateVelocity(
		std::vector<PathPlannerState> &states, std::vector<Waypoint> pathPoints,
		units::meters_per_second_squared_t const maxAccel) {
	if (pathPoints[0].velocityOverride == -1_mps) {
		states[0].velocity = 0_mps;
	}

	for (size_t i = 1; i < states.size(); i++) {
		units::meters_per_second_t const v0 = states[i - 1].velocity;
		units::meter_t const deltaPos = states[i].deltaPos;

		if (deltaPos > 0_m) {
			units::meters_per_second_t const vMax = units::math::sqrt(
					units::math::abs((v0 * v0) + (2 * maxAccel * deltaPos)));
			states[i].velocity = units::math::min(vMax, states[i].velocity);
		} else {
			states[i].velocity = states[i - 1].velocity;
		}
	}

	Waypoint const anchor = pathPoints[pathPoints.size() - 1];
	if (anchor.velocityOverride == -1_mps) {
		states[states.size() - 1].velocity = 0_mps;
	}
	for (size_t i = states.size() - 2; i > 1; i--) {
		units::meters_per_second_t const v0 = states[i + 1].velocity;
		units::meter_t const deltaPos = states[i + 1].deltaPos;

		units::meters_per_second_t const vMax = units::math::sqrt(
				units::math::abs((v0 * v0) + (2 * maxAccel * deltaPos)));
		states[i].velocity = units::math::min(vMax, states[i].velocity);
	}

	units::second_t time = 0_s;
	for (size_t i = 1; i < states.size(); i++) {
		units::meters_per_second_t const v = states[i].velocity;
		units::meter_t const deltaPos = states[i].deltaPos;
		units::meters_per_second_t const v0 = states[i - 1].velocity;

		time += (2 * deltaPos) / (v + v0);
		states[i].time = time;

		units::meters_per_second_t const dv = v - v0;
		units::second_t const dt = time - states[i - 1].time;

		if (dt == 0_s) {
			states[i].acceleration = 0_mps_sq;
		} else {
			states[i].acceleration = dv / dt;
		}
	}
}

void PathPlannerTrajectory::recalculateValues(
		std::vector<PathPlannerState> &states, bool const reversed) {
	for (int i = states.size() - 1; i >= 0; i--) {
		PathPlannerState &now = states[i];

		if (i != static_cast<int>(states.size() - 1)) {
			PathPlannerState const &next = states[i + 1];

			units::second_t dt = next.time - now.time;
			now.angularVelocity = frc::InputModulus(
					next.pose.Rotation().Radians()
							- now.pose.Rotation().Radians(),
					(units::radian_t) - PI, (units::radian_t) PI) / dt;
			now.holonomicAngularVelocity = frc::InputModulus(
					next.holonomicRotation.Radians()
							- now.holonomicRotation.Radians(),
					(units::radian_t) - PI, (units::radian_t) PI) / dt;
		}

		if (!GeometryUtil::isFinite(now.curveRadius)
				|| GeometryUtil::isNaN(now.curveRadius)
				|| now.curveRadius() == 0) {
			now.curvature = units::curvature_t { 0 };
		} else {
			now.curvature = units::curvature_t { 1 / now.curveRadius() };
		}

		if (reversed) {
			now.velocity *= -1;
			now.acceleration *= -1;

			units::degree_t const h = now.pose.Rotation().Degrees() + 180_deg;
			units::degree_t const wrapped_h = frc::InputModulus(h, -180_deg,
					180_deg);
			now.pose = frc::Pose2d(now.pose.Translation(),
					frc::Rotation2d(wrapped_h));
		}
	}
}

units::meter_t PathPlannerTrajectory::calculateRadius(
		PathPlannerState const &s0, PathPlannerState const &s1,
		PathPlannerState const &s2) {
	frc::Translation2d const &a = s0.pose.Translation();
	frc::Translation2d const &b = s1.pose.Translation();
	frc::Translation2d const &c = s2.pose.Translation();

	frc::Translation2d const vba = a - b;
	frc::Translation2d const vbc = c - b;
	double const cross_z = (double) (vba.X() * vbc.Y())
			- (double) (vba.Y() * vbc.X());
	double const sign = (cross_z < 0.0) ? 1.0 : -1.0;

	units::meter_t const ab = a.Distance(b);
	units::meter_t const bc = b.Distance(c);
	units::meter_t const ac = a.Distance(c);

	units::meter_t const p = (ab + bc + ac) / 2;
	units::square_meter_t const area = units::math::sqrt(
			units::math::abs(p * (p - ab) * (p - bc) * (p - ac)));
	return sign * (ab * bc * ac) / (4 * area);
}

PathPlannerTrajectory::PathPlannerState PathPlannerTrajectory::sample(
		units::second_t const time) const {
	if (time <= getInitialState().time) {
		return getInitialState();
	}
	if (time >= getTotalTime()) {
		return getEndState();
	}

	int low = 1;
	int high = numStates() - 1;

	while (low != high) {
		int mid = (low + high) / 2;
		if (getState(mid).time < time) {
			low = mid + 1;
		} else {
			high = mid;
		}
	}

	PathPlannerState const &sample = getState(low);
	PathPlannerState const &prevSample = getState(low - 1);

	if (units::math::abs(sample.time - prevSample.time) < 0.001_s) {
		return sample;
	}

	return prevSample.interpolate(sample,
			(time - prevSample.time) / (sample.time - prevSample.time));
}

PathPlannerTrajectory::PathPlannerState PathPlannerTrajectory::transformStateForAlliance(
		PathPlannerState const &state,
		frc::DriverStation::Alliance const alliance) {
	if (alliance == frc::DriverStation::Alliance::kRed) {
		// Create a new state so that we don't overwrite the original
		PathPlannerTrajectory::PathPlannerState transformedState;

		frc::Translation2d transformedTranslation(state.pose.X(),
				FIELD_WIDTH - state.pose.Y());
		frc::Rotation2d transformedHeading = state.pose.Rotation() * -1;
		frc::Rotation2d transformedHolonomicRotation = state.holonomicRotation
				* -1;

		transformedState.time = state.time;
		transformedState.velocity = state.velocity;
		transformedState.acceleration = state.acceleration;
		transformedState.pose = frc::Pose2d(transformedTranslation,
				transformedHeading);
		transformedState.angularVelocity = -state.angularVelocity;
		transformedState.holonomicRotation = transformedHolonomicRotation;
		transformedState.holonomicAngularVelocity =
				-state.holonomicAngularVelocity;
		transformedState.curveRadius = -state.curveRadius;
		transformedState.curvature = -state.curvature;
		transformedState.deltaPos = state.deltaPos;

		return transformedState;
	} else {
		return state;
	}
}

PathPlannerTrajectory PathPlannerTrajectory::transformTrajectoryForAlliance(
		PathPlannerTrajectory const &trajectory,
		frc::DriverStation::Alliance const alliance) {
	if (alliance == frc::DriverStation::Alliance::kRed) {
		std::vector < PathPlannerState > transformedStates;

		for (PathPlannerState state : trajectory.getStates()) {
			transformedStates.push_back(
					transformStateForAlliance(state, alliance));
		}

		return PathPlannerTrajectory(transformedStates, trajectory.markers,
				trajectory.startStopEvent, trajectory.endStopEvent,
				trajectory.fromGUI);
	} else {
		return trajectory;
	}
}

PathPlannerTrajectory::PathPlannerState PathPlannerTrajectory::PathPlannerState::interpolate(
		PathPlannerState const &endVal, double const t) const {
	PathPlannerState lerpedState { };

	lerpedState.time = GeometryUtil::unitLerp(time, endVal.time, t);
	units::second_t deltaT = lerpedState.time - time;

	if (deltaT < 0_s) {
		return endVal.interpolate(*this, 1 - t);
	}

	lerpedState.velocity = GeometryUtil::unitLerp(velocity, endVal.velocity, t);
	lerpedState.acceleration = GeometryUtil::unitLerp(acceleration,
			endVal.acceleration, t);
	frc::Translation2d newTrans = GeometryUtil::translationLerp(
			pose.Translation(), endVal.pose.Translation(), t);
	frc::Rotation2d newHeading = GeometryUtil::rotationLerp(pose.Rotation(),
			endVal.pose.Rotation(), t);
	lerpedState.pose = frc::Pose2d(newTrans, newHeading);
	lerpedState.angularVelocity = GeometryUtil::unitLerp(angularVelocity,
			endVal.angularVelocity, t);
	lerpedState.holonomicRotation = GeometryUtil::rotationLerp(
			holonomicRotation, endVal.holonomicRotation, t);
	lerpedState.holonomicAngularVelocity = GeometryUtil::unitLerp(
			holonomicAngularVelocity, endVal.holonomicAngularVelocity, t);
	lerpedState.curveRadius = GeometryUtil::unitLerp(curveRadius,
			endVal.curveRadius, t);
	lerpedState.curvature = GeometryUtil::unitLerp(curvature, endVal.curvature,
			t);

	return lerpedState;
}

frc::Trajectory PathPlannerTrajectory::asWPILibTrajectory() const {
	std::vector < frc::Trajectory::State > wpiStates;

	for (size_t i = 0; i < this->states.size(); i++) {
		PathPlannerState const &ppState = this->states[i];

		wpiStates.emplace_back(ppState.asWPILibState());
	}

	return frc::Trajectory(wpiStates);
}
