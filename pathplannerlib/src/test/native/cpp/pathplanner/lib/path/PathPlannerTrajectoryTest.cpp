#include <gtest/gtest.h>

#include "pathplanner/lib/path/PathPlannerTrajectory.h"

using namespace pathplanner;

TEST(PathPlannerTrajectoryTest, TestReverse) {
	PathPlannerTrajectory::State state;
	state.time = 1.91_s;
	state.velocity = 2.29_mps;
	state.acceleration = 35.04_mps_sq;
	state.headingAngularVelocity = 174_rad_per_s;
	state.position = frc::Translation2d {1.1_m, 2.2_m};
	state.heading = frc::Rotation2d {191_deg};
	state.targetHolonomicRotation = frc::Rotation2d {22.9_deg};
	state.curvature = units::curvature_t {3.504};
	state.constraints = PathConstraints {1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq};
	state.deltaPos = 0.1_m;

	// Round-trip reversal should yield the original state
	state = state.reverse();
	state = state.reverse();

	EXPECT_DOUBLE_EQ(1.91, state.time());
	EXPECT_DOUBLE_EQ(2.29, state.velocity());
	EXPECT_DOUBLE_EQ(35.04, state.acceleration());
	EXPECT_DOUBLE_EQ(174, state.headingAngularVelocity());
	EXPECT_DOUBLE_EQ(1.1, state.position.X()());
	EXPECT_DOUBLE_EQ(2.2, state.position.Y()());
	EXPECT_DOUBLE_EQ(191 - 360, state.heading.Degrees()());
	EXPECT_DOUBLE_EQ(22.9, state.targetHolonomicRotation.Degrees()());
	EXPECT_DOUBLE_EQ(3.504, state.curvature());
	EXPECT_DOUBLE_EQ(1.0, state.constraints.getMaxVelocity()());
	EXPECT_DOUBLE_EQ(2.0, state.constraints.getMaxAcceleration()());
	EXPECT_DOUBLE_EQ(3.0, state.constraints.getMaxAngularVelocity()());
	EXPECT_DOUBLE_EQ(4.0, state.constraints.getMaxAngularAcceleration()());
	EXPECT_DOUBLE_EQ(0.1, state.deltaPos());
}