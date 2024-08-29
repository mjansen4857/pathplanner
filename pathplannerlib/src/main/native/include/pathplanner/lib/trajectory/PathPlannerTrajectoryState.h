#pragma once

#include <units/velocity.h>
#include <units/length.h>
#include <units/time.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/geometry/Pose2d.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <vector>
#include "pathplanner/lib/trajectory/SwerveModuleTrajectoryState.h"
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/util/GeometryUtil.h"

namespace pathplanner {
class PathPlannerTrajectoryState {
public:
	units::second_t time = 0_s;
	frc::ChassisSpeeds fieldSpeeds;
	frc::Pose2d pose;
	units::meters_per_second_t linearVelocity = 0_mps;

	frc::Rotation2d heading;
	units::meter_t deltaPos = 0_m;
	frc::Rotation2d deltaRot;
	std::vector<SwerveModuleTrajectoryState> moduleStates;
	PathConstraints constraints;

	constexpr PathPlannerTrajectoryState() : constraints(0_mps, 0_mps_sq,
			0_rad_per_s, 0_rad_per_s_sq) {
	}

	constexpr PathPlannerTrajectoryState interpolate(
			const PathPlannerTrajectoryState &endVal, const double t) const {
		PathPlannerTrajectoryState lerpedState;

		lerpedState.time = GeometryUtil::unitLerp(time, endVal.time, t);

		auto deltaT = lerpedState.time - time;
		if (deltaT < 0_s) {
			return endVal.interpolate(*this, 1.0 - t);
		}

		lerpedState.fieldSpeeds = frc::ChassisSpeeds(
				GeometryUtil::unitLerp(fieldSpeeds.vx, endVal.fieldSpeeds.vx,
						t),
				GeometryUtil::unitLerp(fieldSpeeds.vy, endVal.fieldSpeeds.vy,
						t),
				GeometryUtil::unitLerp(fieldSpeeds.omega,
						endVal.fieldSpeeds.omega, t));
		lerpedState.pose = frc::Pose2d(
				GeometryUtil::translationLerp(pose.Translation(),
						endVal.pose.Translation(), t),
				GeometryUtil::rotationLerp(pose.Rotation(),
						endVal.pose.Rotation(), t));
		lerpedState.linearVelocity = GeometryUtil::unitLerp(linearVelocity,
				endVal.linearVelocity, t);

		return lerpedState;
	}

	constexpr PathPlannerTrajectoryState reverse() const {
		PathPlannerTrajectoryState reversed;

		reversed.time = time;
		auto reversedSpeeds =
				frc::Translation2d(fieldSpeeds.vx, fieldSpeeds.vy).RotateBy(
						frc::Rotation2d(180_deg));
		reversed.fieldSpeeds = frc::ChassisSpeeds(units::meters_per_second_t {
				reversedSpeeds.X()() }, units::meters_per_second_t {
				reversedSpeeds.Y()() }, fieldSpeeds.omega);
		reversed.pose = frc::Pose2d(pose.Translation(),
				pose.Rotation() + frc::Rotation2d(180_deg));
		reversed.linearVelocity = -linearVelocity;

		return reversed;
	}
};
}
