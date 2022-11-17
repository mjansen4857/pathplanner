#include <gtest/gtest.h>
#include "pathplanner/lib/PathPoint.h"

using namespace pathplanner;

#define DELTA 1E-2

TEST(PathPointTest, TestConstructor) {
	PathPoint p(frc::Translation2d(1.2_m, 2.7_m), frc::Rotation2d(25_deg), frc::Rotation2d(67_deg), 2.4_mps);

	EXPECT_EQ(frc::Translation2d(1.2_m, 2.7_m), p.m_position);
	EXPECT_EQ(frc::Rotation2d(25_deg), p.m_heading);
	EXPECT_EQ(frc::Rotation2d(67_deg), p.m_holonomicRotation);
	EXPECT_EQ(2.4_mps, p.m_velocityOverride);
}

TEST(PathPointTest, TestFromCurrentHolonomicState) {
	frc::Pose2d pose(1.7_m, 2.1_m, frc::Rotation2d(45_deg));
	frc::ChassisSpeeds speeds = frc::ChassisSpeeds::FromFieldRelativeSpeeds(1.7_mps, -1.2_mps, 0.8_rad_per_s, 0_deg);
	PathPoint p = PathPoint::fromCurrentHolonomicState(pose, speeds);

	EXPECT_EQ(frc::Translation2d(1.7_m, 2.1_m), p.m_position);
	EXPECT_NEAR(-35.22, p.m_heading.Degrees()(), DELTA);
	EXPECT_NEAR(45.0, p.m_holonomicRotation.Degrees()(), DELTA);
	EXPECT_NEAR(2.08, p.m_velocityOverride(), DELTA);
}

TEST(PathPointTest, TestFromCurrentDifferentialState) {
	frc::Pose2d pose(1.7_m, 2.1_m, frc::Rotation2d(45_deg));
	frc::ChassisSpeeds speeds = frc::ChassisSpeeds::FromFieldRelativeSpeeds(1.7_mps, 0_mps, 0.8_rad_per_s, 0_deg);
	PathPoint p = PathPoint::fromCurrentDifferentialState(pose, speeds);

	EXPECT_EQ(frc::Translation2d(1.7_m, 2.1_m), p.m_position);
	EXPECT_NEAR(45.0, p.m_heading.Degrees()(), DELTA);
	EXPECT_NEAR(0.0, p.m_holonomicRotation.Degrees()(), DELTA);
	EXPECT_NEAR(1.7, p.m_velocityOverride(), DELTA);
}