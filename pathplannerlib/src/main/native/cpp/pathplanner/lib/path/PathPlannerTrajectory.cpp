#include "pathplanner/lib/path/PathPlannerTrajectory.h"
#include "pathplanner/lib/path/PathPlannerPath.h"

using namespace pathplanner;

PathPlannerTrajectory::State PathPlannerTrajectory::sample(
		const units::second_t time) {
	if (time <= getInitialState().time)
		return getInitialState();
	if (time >= getTotalTime())
		return getEndState();

	size_t low = 1;
	size_t high = getStates().size() - 1;

	while (low != high) {
		size_t mid = (low + high) / 2;
		if (getState(mid).time < time) {
			low = mid + 1;
		} else {
			high = mid;
		}
	}

	State sample = getState(low);
	State prevSample = getState(low - 1);

	if (units::math::abs(sample.time - prevSample.time) < 1E-3_s)
		return sample;

	return prevSample.interpolate(sample,
			(time() - prevSample.time()) / (sample.time() - prevSample.time()));
}

size_t PathPlannerTrajectory::getNextRotationTargetIdx(
		std::shared_ptr<PathPlannerPath> path, const size_t startingIndex) {
	size_t idx = path->numPoints() - 1;

	for (size_t i = startingIndex; i < path->numPoints() - 1; i++) {
		if (path->getPoint(i).rotationTarget) {
			idx = i;
			break;
		}
	}

	return idx;
}

std::vector<PathPlannerTrajectory::State> PathPlannerTrajectory::generateStates(
		std::shared_ptr<PathPlannerPath> path,
		const frc::ChassisSpeeds &startingSpeeds,
		const frc::Rotation2d &startingRotation) {
	std::vector < State > states;

	units::meters_per_second_t startVel = units::math::hypot(startingSpeeds.vx,
			startingSpeeds.vy);

	units::meter_t prevRotationTargetDist = 0.0_m;
	frc::Rotation2d prevRotationTargetRot = startingRotation;
	size_t nextRotationTargetIdx = getNextRotationTargetIdx(path, 0);
	units::meter_t distanceBetweenTargets = path->getPoint(
			nextRotationTargetIdx).distanceAlongPath;

	// Initial pass. Creates all states and handles linear acceleration
	for (size_t i = 0; i < path->numPoints(); i++) {
		State state;

		PathConstraints constraints = path->getPoint(i).constraints.value();
		state.constraints = constraints;

		if (i > nextRotationTargetIdx) {
			prevRotationTargetDist =
					path->getPoint(nextRotationTargetIdx).distanceAlongPath;
			prevRotationTargetRot =
					path->getPoint(nextRotationTargetIdx).rotationTarget.value().getTarget();
			nextRotationTargetIdx = getNextRotationTargetIdx(path, i);
			distanceBetweenTargets =
					path->getPoint(nextRotationTargetIdx).distanceAlongPath
							- prevRotationTargetDist;
		}

		RotationTarget nextTarget =
				path->getPoint(nextRotationTargetIdx).rotationTarget.value();

		if (nextTarget.shouldRotateFast()) {
			state.targetHolonomicRotation = nextTarget.getTarget();
		} else {
			double t = ((path->getPoint(i).distanceAlongPath
					- prevRotationTargetDist) / distanceBetweenTargets)();
			t = std::min(std::max(0.0, t), 1.0);
			if (!std::isfinite(t)) {
				t = 0.0;
			}

			state.targetHolonomicRotation = (prevRotationTargetRot
					+ (nextTarget.getTarget() - prevRotationTargetRot)) * t;
		}

		state.position = path->getPoint(i).position;
		units::meter_t curveRadius = path->getPoint(i).curveRadius;
		state.curvature = units::curvature_t {
				(GeometryUtil::isFinite(curveRadius) && curveRadius != 0_m) ?
						1.0 / curveRadius() : 0 };

		if (i == path->numPoints() - 1) {
			state.heading = states[states.size() - 1].heading;
			state.deltaPos = path->getPoint(i).distanceAlongPath
					- path->getPoint(i - 1).distanceAlongPath;
			state.velocity = path->getGoalEndState().getVelocity();
		} else if (i == 0) {
			state.heading =
					(path->getPoint(i + 1).position - state.position).Angle();
			state.deltaPos = 0_m;
			state.velocity = startVel;
		} else {
			state.heading =
					(path->getPoint(i + 1).position - state.position).Angle();
			state.deltaPos = path->getPoint(i + 1).distanceAlongPath
					- path->getPoint(i).distanceAlongPath;

			units::meters_per_second_t v0 = states[states.size() - 1].velocity;
			units::meters_per_second_t vMax =
					units::math::sqrt(
							units::math::abs(
									units::math::pow < 2
											> (v0)
													+ (2
															* constraints.getMaxAcceleration()
															* state.deltaPos)));
			state.velocity = units::math::min(vMax, path->getPoint(i).maxV);
		}

		states.push_back(state);
	}

	// Second pass. Handles linear deceleration
	for (size_t i = states.size() - 2; i > 1; i--) {
		PathConstraints constraints = states[i].constraints;

		units::meters_per_second_t v0 = states[i + 1].velocity;
		units::meters_per_second_t vMax = units::math::sqrt(
				units::math::abs(
						units::math::pow < 2
								> (v0)
										+ (2 * constraints.getMaxAcceleration()
												* states[i + 1].deltaPos)));
		states[i].velocity = units::math::min(vMax, states[i].velocity);
	}

	// Final pass. Calculates time, linear acceleration, and angular velocity
	units::second_t time = 0_s;
	states[0].time = 0_s;
	states[0].acceleration = 0_mps_sq;
	states[0].headingAngularVelocity = startingSpeeds.omega;

	for (size_t i = 1; i < states.size(); i++) {
		units::meters_per_second_t v0 = states[i - 1].velocity;
		units::meters_per_second_t v = states[i].velocity;
		units::second_t dt = (2 * states[i].deltaPos) / (v + v0);

		time += dt;
		states[i].time = time;

		units::meters_per_second_t dv = v - v0;
		states[i].acceleration = dv / dt;

		frc::Rotation2d headingDelta = states[i].heading
				- states[i - 1].heading;
		states[i].headingAngularVelocity = headingDelta.Radians() / dt;
	}

	return states;
}
