#include "pathplanner/lib/trajectory/PathPlannerTrajectoryState.h"

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
	for (size_t m = 0; m < driveMotorTorqueCurrent.size(); m++) {
		lerpedState.driveMotorTorqueCurrent.emplace_back(
				GeometryUtil::unitLerp(driveMotorTorqueCurrent[m],
						endVal.driveMotorTorqueCurrent[m], t));
	}

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
	for (auto torqueCurrent : driveMotorTorqueCurrent) {
		reversed.driveMotorTorqueCurrent.emplace_back(-torqueCurrent);
	}

	return reversed;
}

PathPlannerTrajectoryState PathPlannerTrajectoryState::flip() const {
	PathPlannerTrajectoryState mirrored;

	mirrored.time = time;
	mirrored.linearVelocity = linearVelocity;
	mirrored.pose = GeometryUtil::flipFieldPose(pose);
	mirrored.fieldSpeeds = frc::ChassisSpeeds { -fieldSpeeds.vx, fieldSpeeds.vy,
			-fieldSpeeds.omega };
	if (driveMotorTorqueCurrent.size() == 4) {
		mirrored.driveMotorTorqueCurrent.emplace_back(
				driveMotorTorqueCurrent[1]);
		mirrored.driveMotorTorqueCurrent.emplace_back(
				driveMotorTorqueCurrent[0]);
		mirrored.driveMotorTorqueCurrent.emplace_back(
				driveMotorTorqueCurrent[3]);
		mirrored.driveMotorTorqueCurrent.emplace_back(
				driveMotorTorqueCurrent[2]);
	} else if (driveMotorTorqueCurrent.size() == 2) {
		mirrored.driveMotorTorqueCurrent.emplace_back(
				driveMotorTorqueCurrent[1]);
		mirrored.driveMotorTorqueCurrent.emplace_back(
				driveMotorTorqueCurrent[0]);
	}

	return mirrored;
}
