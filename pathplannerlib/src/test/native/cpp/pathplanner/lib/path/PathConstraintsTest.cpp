#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include "pathplanner/lib/path/PathConstraints.h"

using namespace pathplanner;

TEST_CASE("PathConstraintsTest/TestGetters", "[PathConstraintsTest]") {
	PathConstraints constraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq);

	CHECK_THAT(constraints.getMaxVelocity()(), Catch::Matchers::WithinULP(1.0, 4));
	CHECK_THAT(constraints.getMaxAcceleration()(), Catch::Matchers::WithinULP(2.0, 4));
	CHECK_THAT(constraints.getMaxAngularVelocity()(), Catch::Matchers::WithinULP(3.0, 4));
	CHECK_THAT(constraints.getMaxAngularAcceleration()(), Catch::Matchers::WithinULP(4.0, 4));
}

TEST_CASE("PathConstraintsTest/TestFromJson", "[PathConstraintsTest]") {
	wpi::util::json json = wpi::util::json::object("maxVelocity", 1.0,
			"maxAcceleration", 2.0, "maxAngularVelocity", 90.0,
			"maxAngularAcceleration", 180.0, "nominalVoltage", 12.0,
			"unlimited", false);

	PathConstraints fromJson = PathConstraints::fromJson(json);
	CHECK(fromJson == PathConstraints(1_mps, 2_mps_sq, 90_deg_per_s, 180_deg_per_s_sq, 12_V, false));
}
