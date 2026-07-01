#pragma once

#include <wpi/units/velocity.hpp>
#include <wpi/units/length.hpp>
#include <wpi/units/time.hpp>
#include <wpi/math/kinematics/ChassisVelocities.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/math/geometry/Translation2d.hpp>
#include <wpi/math/geometry/Rotation2d.hpp>
#include <vector>
#include "pathplanner/lib/trajectory/SwerveModuleTrajectoryState.h"
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/util/DriveFeedforwards.h"

namespace pathplanner {
class PathPlannerTrajectoryState {
public:
	wpi::units::second_t time = 0_s;
	wpi::math::ChassisVelocities fieldSpeeds;
	wpi::math::Pose2d pose;
	wpi::units::meters_per_second_t linearVelocity = 0_mps;
	DriveFeedforwards feedforwards;

	wpi::math::Rotation2d heading;
	wpi::units::meter_t deltaPos = 0_m;
	wpi::math::Rotation2d deltaRot;
	std::vector<SwerveModuleTrajectoryState> moduleStates;
	PathConstraints constraints;
	double waypointRelativePos = 0.0;

	PathPlannerTrajectoryState() : constraints(0_mps, 0_mps_sq, 0_rad_per_s,
			0_rad_per_s_sq) {
	}

	/**
	 * Interpolate between this state and the given state
	 *
	 * @param endVal State to interpolate with
	 * @param t Interpolation factor (0.0-1.0)
	 * @return Interpolated state
	 */
	PathPlannerTrajectoryState interpolate(
			const PathPlannerTrajectoryState &endVal, const double t) const;

	/**
	 * Get the state reversed, used for following a trajectory reversed with a differential drivetrain
	 *
	 * @return The reversed state
	 */
	PathPlannerTrajectoryState reverse() const;

	/**
	 * Flip this trajectory state for the other side of the field, maintaining a blue alliance origin
	 *
	 * @return This trajectory state flipped to the other side of the field
	 */
	PathPlannerTrajectoryState flip() const;

	/**
	 * Copy this state and change the timestamp
	 *
	 * @param time The new time to use
	 * @return Copied state with the given time
	 */
	PathPlannerTrajectoryState copyWithTime(wpi::units::second_t time) const;
};
}
