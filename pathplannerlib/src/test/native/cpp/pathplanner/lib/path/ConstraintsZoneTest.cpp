#include <gtest/gtest.h>
#include "pathplanner/lib/path/ConstraintsZone.h"

using namespace pathplanner;

TEST(ConstraintsZoneTest, TestGetters) {
	ConstraintsZone zone(1.25, 1.8, PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq));

	EXPECT_DOUBLE_EQ(1.25, zone.getMinWaypointRelativePos());
	EXPECT_DOUBLE_EQ(1.8, zone.getMaxWaypointRelativePos());
	EXPECT_EQ(PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq), zone.getConstraints());
}

TEST(ConstraintsZoneTest, TestFromJson) {
	wpi::util::json constraintsJson = wpi::util::json::object("maxVelocity",
			1.0, "maxAcceleration", 2.0, "maxAngularVelocity", 90.0,
			"maxAngularAcceleration", 180.0, "nominalVoltage", 12.0,
			"unlimited", false);
	wpi::util::json json = wpi::util::json::object("minWaypointRelativePos", 1.5,
			"maxWaypointRelativePos", 2.5, "constraints", constraintsJson);

	ConstraintsZone expected(1.5, 2.5, PathConstraints(1_mps, 2_mps_sq, 90_deg_per_s, 180_deg_per_s_sq, 12_V, false));
	EXPECT_EQ(expected, ConstraintsZone::fromJson(json));
}
