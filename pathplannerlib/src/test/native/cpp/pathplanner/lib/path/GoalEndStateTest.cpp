#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include "pathplanner/lib/path/GoalEndState.h"

using namespace pathplanner;

TEST_CASE("GoalEndStateTest/TestGetters", "[GoalEndStateTest]") {
	GoalEndState endState(2_mps, wpi::math::Rotation2d(35_deg));

	CHECK_THAT(endState.getVelocity()(), Catch::Matchers::WithinULP(2.0, 4));
	CHECK(endState.getRotation() == wpi::math::Rotation2d(35_deg));
}

TEST_CASE("GoalEndStateTest/TestFromJson", "[GoalEndStateTest]") {
	wpi::util::json json = wpi::util::json::object("velocity", 1.25,
			"rotation", -15.5);

	CHECK(GoalEndState::fromJson(json) == GoalEndState(1.25_mps, wpi::math::Rotation2d(-15.5_deg)));
}
