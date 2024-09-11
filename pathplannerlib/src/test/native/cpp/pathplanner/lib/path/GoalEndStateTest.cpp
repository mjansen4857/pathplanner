#include <gtest/gtest.h>
#include "pathplanner/lib/path/GoalEndState.h"

using namespace pathplanner;

TEST(GoalEndStateTest, TestGetters) {
	GoalEndState endState(2_mps, frc::Rotation2d(35_deg));

	EXPECT_DOUBLE_EQ(2.0, endState.getVelocity()());
	EXPECT_EQ(frc::Rotation2d(35_deg), endState.getRotation());
}

TEST(GoalEndStateTest, TestFromJson) {
	wpi::json json;
	json.emplace("velocity", 1.25);
	json.emplace("rotation", -15.5);

	EXPECT_EQ(GoalEndState(1.25_mps, frc::Rotation2d(-15.5_deg)), GoalEndState::fromJson(json));
}