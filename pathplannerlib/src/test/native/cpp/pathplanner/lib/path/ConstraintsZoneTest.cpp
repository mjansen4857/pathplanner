#include <gtest/gtest.h>
#include "pathplanner/lib/path/ConstraintsZone.h"

using namespace pathplanner;

TEST(ConstraintsZoneTest, TestGetters) {
	ConstraintsZone zone(1.25, 1.8, PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq));

	EXPECT_DOUBLE_EQ(1.25, zone.getMinWaypointRelativePos());
	EXPECT_DOUBLE_EQ(1.8, zone.getMaxWaypointRelativePos());
	EXPECT_EQ(PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq), zone.getConstraints());
}

TEST(ConstraintsZoneTest, TestWithinZone) {
	ConstraintsZone zone(1.25, 1.8, PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq));

	EXPECT_TRUE(zone.isWithinZone(1.5));
	EXPECT_FALSE(zone.isWithinZone(2.0));
	EXPECT_FALSE(zone.isWithinZone(1.0));
}

TEST(ConstraintsZoneTest, TestOverlapsRange) {
	ConstraintsZone zone(1.25, 1.8, PathConstraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq));

	EXPECT_TRUE(zone.overlapsRange(1.0, 2.0));
	EXPECT_FALSE(zone.overlapsRange(0.0, 1.0));
	EXPECT_FALSE(zone.overlapsRange(2.0, 3.0));
}

TEST(ConstraintsZoneTest, TestFromJson) {
	wpi::json json;
	wpi::json constraintsJson;
	constraintsJson.emplace("maxVelocity", 1.0);
	constraintsJson.emplace("maxAcceleration", 2.0);
	constraintsJson.emplace("maxAngularVelocity", 90.0);
	constraintsJson.emplace("maxAngularAcceleration", 180.0);
	json.emplace("minWaypointRelativePos", 1.5);
	json.emplace("maxWaypointRelativePos", 2.5);
	json.emplace("constraints", constraintsJson);

	ConstraintsZone expected(1.5, 2.5, PathConstraints(1_mps, 2_mps_sq, 90_deg_per_s, 180_deg_per_s_sq));
	EXPECT_EQ(expected, ConstraintsZone::fromJson(json));
}