#include <gtest/gtest.h>
#include "pathplanner/lib/path/RotationTarget.h"

using namespace pathplanner;

TEST(RotationTargetTest, TestGetters) {
	RotationTarget target(1.5, frc::Rotation2d(90_deg), false);

	EXPECT_DOUBLE_EQ(1.5, target.getPosition());
	EXPECT_EQ(frc::Rotation2d(90_deg), target.getTarget());
}

TEST(RotationTargetTest, TestForSegmentIndex) {
	RotationTarget target(1.5, frc::Rotation2d(90_deg), false);
	RotationTarget forSegment = target.forSegmentIndex(1);

	EXPECT_DOUBLE_EQ(0.5, forSegment.getPosition());
	EXPECT_EQ(frc::Rotation2d(90_deg), forSegment.getTarget());
}

TEST(RotationTargetTest, TestFromJson) {
	wpi::json json;
	json.emplace("waypointRelativePos", 2.1);
	json.emplace("rotationDegrees", -45);
	json.emplace("rotateFast", true);

	EXPECT_EQ(RotationTarget(2.1, frc::Rotation2d(-45_deg), true), RotationTarget::fromJson(json));
}