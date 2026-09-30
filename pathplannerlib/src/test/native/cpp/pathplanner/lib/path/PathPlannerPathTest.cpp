#include <gtest/gtest.h>
#include "pathplanner/lib/path/PathPlannerPath.h"

using namespace pathplanner;

TEST(PathPlannerPathTest, InitialHeadingUsesDirectionOfFirstSegment) {
	auto path = PathPlannerPath::fromPathPoints(
			{	PathPoint(wpi::math::Translation2d(0_m, 0_m)), PathPoint(wpi::math::Translation2d(0_m, 1_m))},
			PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq),
			GoalEndState(0_mps, wpi::math::Rotation2d {}));
	EXPECT_NEAR(90.0, path->getInitialHeading().Degrees()(), 1e-9);
}

TEST(PathPlannerPathTest, InitialHeadingIsZeroForCoincidentPoints) {
	auto path = PathPlannerPath::fromPathPoints(
			{	PathPoint(wpi::math::Translation2d(0_m, 0_m)), PathPoint(wpi::math::Translation2d(0_m, 0_m))},
			PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq),
			GoalEndState(0_mps, wpi::math::Rotation2d {}));
	EXPECT_EQ(wpi::math::Rotation2d {}, path->getInitialHeading());
}
