#include <gtest/gtest.h>
#include "pathplanner/lib/path/PathConstraints.h"

using namespace pathplanner;

TEST(PathConstraintsTest, TestGetters) {
	PathConstraints constraints(1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq);

	EXPECT_DOUBLE_EQ(1.0, constraints.getMaxVelocity()());
	EXPECT_DOUBLE_EQ(2.0, constraints.getMaxAcceleration()());
	EXPECT_DOUBLE_EQ(3.0, constraints.getMaxAngularVelocity()());
	EXPECT_DOUBLE_EQ(4.0, constraints.getMaxAngularAcceleration()());
}

TEST(PathConstraintsTest, TestFromJson) {
	wpi::json json;
	json.emplace("maxVelocity", 1.0);
	json.emplace("maxAcceleration", 2.0);
	json.emplace("maxAngularVelocity", 90.0);
	json.emplace("maxAngularAcceleration", 180.0);
	json.emplace("nominalVoltage", 12.0);
	json.emplace("unlimited", false);

	PathConstraints fromJson = PathConstraints::fromJson(json);
	EXPECT_EQ(PathConstraints(1_mps, 2_mps_sq, 90_deg_per_s, 180_deg_per_s_sq, 12_V, false), fromJson);
}