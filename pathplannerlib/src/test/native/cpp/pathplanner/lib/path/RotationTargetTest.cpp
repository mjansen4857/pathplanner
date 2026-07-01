#include <gtest/gtest.h>
#include "pathplanner/lib/path/RotationTarget.h"

using namespace pathplanner;

TEST(RotationTargetTest, TestGetters) {
	RotationTarget target(1.5, wpi::math::Rotation2d(90_deg));

	EXPECT_DOUBLE_EQ(1.5, target.getPosition());
	EXPECT_EQ(wpi::math::Rotation2d(90_deg), target.getTarget());
}

TEST(RotationTargetTest, TestFromJson) {
	wpi::util::json json = wpi::util::json::object("waypointRelativePos", 2.1,
			"rotationDegrees", -45);

	EXPECT_EQ(RotationTarget(2.1, wpi::math::Rotation2d(-45_deg)), RotationTarget::fromJson(json));
}
