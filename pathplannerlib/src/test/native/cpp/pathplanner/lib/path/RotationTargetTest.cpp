#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include "pathplanner/lib/path/RotationTarget.h"

using namespace pathplanner;

TEST_CASE("RotationTargetTest/TestGetters", "[RotationTargetTest]") {
	RotationTarget target(1.5, wpi::math::Rotation2d(90_deg));

	CHECK_THAT(target.getPosition(), Catch::Matchers::WithinULP(1.5, 4));
	CHECK(target.getTarget() == wpi::math::Rotation2d(90_deg));
}

TEST_CASE("RotationTargetTest/TestFromJson", "[RotationTargetTest]") {
	wpi::util::json json = wpi::util::json::object("waypointRelativePos", 2.1,
			"rotationDegrees", -45);

	CHECK(RotationTarget::fromJson(json) == RotationTarget(2.1, wpi::math::Rotation2d(-45_deg)));
}
