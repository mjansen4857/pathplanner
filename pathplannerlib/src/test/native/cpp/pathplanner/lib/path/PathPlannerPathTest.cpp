#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include "pathplanner/lib/path/PathPlannerPath.h"

using namespace pathplanner;

TEST_CASE("PathPlannerPathTest/InitialHeadingUsesDirectionOfFirstSegment", "[PathPlannerPathTest]") {
	auto path = PathPlannerPath::fromPathPoints(
			{	PathPoint(wpi::math::Translation2d(0_m, 0_m)), PathPoint(wpi::math::Translation2d(0_m, 1_m))},
			PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq),
			GoalEndState(0_mps, wpi::math::Rotation2d {}));
	CHECK_THAT(path->getInitialHeading().Degrees()(), Catch::Matchers::WithinAbs(90.0, 1e-9));
}

TEST_CASE("PathPlannerPathTest/InitialHeadingIsZeroForCoincidentPoints", "[PathPlannerPathTest]") {
	auto path = PathPlannerPath::fromPathPoints(
			{	PathPoint(wpi::math::Translation2d(0_m, 0_m)), PathPoint(wpi::math::Translation2d(0_m, 0_m))},
			PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq),
			GoalEndState(0_mps, wpi::math::Rotation2d {}));
	CHECK(path->getInitialHeading() == wpi::math::Rotation2d {});
}
