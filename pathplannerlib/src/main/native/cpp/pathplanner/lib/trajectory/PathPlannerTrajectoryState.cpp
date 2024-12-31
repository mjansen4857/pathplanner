#include "pathplanner/lib/trajectory/PathPlannerTrajectoryState.h"
#include "pathplanner/lib/util/FlippingUtil.h"

using namespace pathplanner;

PathPlannerTrajectoryState PathPlannerTrajectoryState::interpolate(
		const PathPlannerTrajectoryState &endVal, const double t) const {
	PathPlannerTrajectoryState lerpedState;

	lerpedState.time = GeometryUtil::unitLerp(time, endVal.time, t);

	auto deltaT = lerpedState.time - time;
	if (deltaT < 0_s) {
		return endVal.interpolate(*this, 1.0 - t);
	}

	lerpedState.fieldSpeeds = frc::ChassisSpeeds { GeometryUtil::unitLerp(
			fieldSpeeds.vx, endVal.fieldSpeeds.vx, t), GeometryUtil::unitLerp(
			fieldSpeeds.vy, endVal.fieldSpeeds.vy, t), GeometryUtil::unitLerp(
			fieldSpeeds.omega, endVal.fieldSpeeds.omega, t) };

	lerpedState.heading = heading;
	lerpedState.linearVelocity = GeometryUtil::unitLerp(linearVelocity,
			endVal.linearVelocity, t);

	// Integrate the field speeds to get the pose for this interpolated state, since linearly
	// interpolating the pose gives an inaccurate result if the speeds are changing between states
	units::meter_t lerpedXPos = pose.X();
	units::meter_t lerpedYPos = pose.Y();
	units::second_t intTime = time + 0.01_s;
	while (true) {
		double intT = ((intTime - time) / (lerpedState.time - time))();
		units::meters_per_second_t intLinearVel = GeometryUtil::unitLerp(
				linearVelocity, lerpedState.linearVelocity, intT);
		units::meters_per_second_t intVX = intLinearVel
				* lerpedState.heading.Cos();
		units::meters_per_second_t intVY = intLinearVel
				* lerpedState.heading.Sin();

		if (intTime >= lerpedState.time - 0.01_s) {
			units::second_t dt = lerpedState.time - intTime;
			lerpedXPos += intVX * dt;
			lerpedYPos += intVY * dt;
			break;
		}

		lerpedXPos += intVX * 0.01_s;
		lerpedYPos += intVY * 0.01_s;

		intTime += 0.01_s;
	}

	lerpedState.pose = frc::Pose2d(lerpedXPos, lerpedYPos,
			GeometryUtil::rotationLerp(pose.Rotation(), endVal.pose.Rotation(),
					t));
	lerpedState.feedforwards = feedforwards.interpolate(endVal.feedforwards, t);

	return lerpedState;
}

PathPlannerTrajectoryState PathPlannerTrajectoryState::reverse() const {
	PathPlannerTrajectoryState reversed;

	reversed.time = time;
	auto reversedSpeeds = frc::Translation2d(
			units::meter_t { fieldSpeeds.vx() }, units::meter_t {
					fieldSpeeds.vy() }).RotateBy(frc::Rotation2d(180_deg));
	reversed.fieldSpeeds = frc::ChassisSpeeds { units::meters_per_second_t {
			reversedSpeeds.X()() }, units::meters_per_second_t {
			reversedSpeeds.Y()() }, fieldSpeeds.omega };
	reversed.pose = frc::Pose2d(pose.Translation(),
			pose.Rotation() + frc::Rotation2d(180_deg));
	reversed.linearVelocity = -linearVelocity;
	reversed.feedforwards = feedforwards.reverse();
	reversed.heading = heading + frc::Rotation2d(180_deg);

	return reversed;
}

PathPlannerTrajectoryState PathPlannerTrajectoryState::flip() const {
	PathPlannerTrajectoryState flipped;

	flipped.time = time;
	flipped.linearVelocity = linearVelocity;
	flipped.pose = FlippingUtil::flipFieldPose(pose);
	flipped.fieldSpeeds = FlippingUtil::flipFieldSpeeds(fieldSpeeds);
	flipped.feedforwards = feedforwards.flip();
	flipped.heading = FlippingUtil::flipFieldRotation(heading);

	return flipped;
}

PathPlannerTrajectoryState PathPlannerTrajectoryState::copyWithTime(
		units::second_t time) const {
	PathPlannerTrajectoryState copy;
	copy.time = time;
	copy.fieldSpeeds = fieldSpeeds;
	copy.pose = pose;
	copy.linearVelocity = linearVelocity;
	copy.feedforwards = feedforwards;
	copy.heading = heading;
	copy.deltaPos = deltaPos;
	copy.deltaRot = deltaRot;
	copy.moduleStates = moduleStates;
	copy.constraints = constraints;
	copy.waypointRelativePos = waypointRelativePos;

	return copy;
}
