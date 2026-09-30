#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include "pathplanner/lib/path/ConstraintsZone.h"

using namespace pathplanner;

TEST_CASE("ConstraintsZoneTest/TestGetters", "[ConstraintsZoneTest]") {
	ConstraintsZone zone(1.25, 1.8, PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq));

	CHECK_THAT(zone.getMinWaypointRelativePos(), Catch::Matchers::WithinULP(1.25, 4));
	CHECK_THAT(zone.getMaxWaypointRelativePos(), Catch::Matchers::WithinULP(1.8, 4));
	CHECK(zone.getConstraints() == PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq));
}

TEST_CASE("ConstraintsZoneTest/TestFromJson", "[ConstraintsZoneTest]") {
	wpi::util::json constraintsJson = wpi::util::json::object("maxVelocity",
			1.0, "maxAcceleration", 2.0, "maxAngularVelocity", 90.0,
			"maxAngularAcceleration", 180.0, "nominalVoltage", 12.0,
			"unlimited", false);
	wpi::util::json json = wpi::util::json::object("minWaypointRelativePos", 1.5,
			"maxWaypointRelativePos", 2.5, "constraints", constraintsJson);

	ConstraintsZone expected(1.5, 2.5, PathConstraints(1_mps, 2_mps_sq, 90_deg_per_s, 180_deg_per_s_sq, 12_V, false));
	CHECK(ConstraintsZone::fromJson(json) == expected);
}
