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
	lerpedState.pose = frc::Pose2d(
			GeometryUtil::translationLerp(pose.Translation(),
					endVal.pose.Translation(), t),
			GeometryUtil::rotationLerp(pose.Rotation(), endVal.pose.Rotation(),
					t));
	lerpedState.linearVelocity = GeometryUtil::unitLerp(linearVelocity,
			endVal.linearVelocity, t);
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

	return reversed;
}

PathPlannerTrajectoryState PathPlannerTrajectoryState::flip() const {
	PathPlannerTrajectoryState flipped;

	flipped.time = time;
	flipped.linearVelocity = linearVelocity;
	flipped.pose = FlippingUtil::flipFieldPose(pose);
	flipped.fieldSpeeds = FlippingUtil::flipFieldSpeeds(fieldSpeeds);
	flipped.feedforwards = feedforwards.flip();

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
