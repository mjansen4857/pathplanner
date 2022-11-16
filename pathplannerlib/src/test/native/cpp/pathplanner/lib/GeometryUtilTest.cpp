#include <gtest/gtest.h>
#include "pathplanner/lib/GeometryUtil.h"

using namespace pathplanner;

TEST(GeometryUtilTest, TestUnitLerp) {
	EXPECT_DOUBLE_EQ(12, GeometryUtil::unitLerp(10_s, 20_s, 0.2)());
	EXPECT_DOUBLE_EQ(12, GeometryUtil::unitLerp(10_mps, 20_mps, 0.2)());
	EXPECT_DOUBLE_EQ(12, GeometryUtil::unitLerp(10_mps_sq, 20_mps_sq, 0.2)());
	EXPECT_DOUBLE_EQ(12, GeometryUtil::unitLerp(10_rad_per_s, 20_rad_per_s, 0.2)());
	EXPECT_DOUBLE_EQ(12, GeometryUtil::unitLerp(10_rad_per_s_sq, 20_rad_per_s_sq, 0.2)());
	EXPECT_DOUBLE_EQ(12, GeometryUtil::unitLerp(10_m, 20_m, 0.2)());
	EXPECT_DOUBLE_EQ(12, GeometryUtil::unitLerp(units::curvature_t {10}, units::curvature_t {20}, 0.2)());
}

TEST(GeometryUtilTest, TestRotationLerp) {
	frc::Rotation2d r = GeometryUtil::rotationLerp(frc::Rotation2d(0_deg), frc::Rotation2d(180_deg), 0.5);
	EXPECT_DOUBLE_EQ(90, r.Degrees()());
	r = GeometryUtil::rotationLerp(frc::Rotation2d(0_deg), frc::Rotation2d(-180_deg), 0.25);
	EXPECT_DOUBLE_EQ(-45, r.Degrees()());
}

TEST(GeometryUtilTest, TestTranslationLerp) {
	frc::Translation2d t = GeometryUtil::translationLerp(frc::Translation2d(2.3_m, 7_m), frc::Translation2d(3.5_m, 2.1_m), 0.2);
	EXPECT_DOUBLE_EQ(2.54, t.X()());
	EXPECT_DOUBLE_EQ(6.02, t.Y()());

	t = GeometryUtil::translationLerp(frc::Translation2d(-1.5_m, 2_m), frc::Translation2d(1.5_m, -3_m), 0.5);
	EXPECT_DOUBLE_EQ(0, t.X()());
	EXPECT_DOUBLE_EQ(-0.5, t.Y()());
}

TEST(GeometryUtilTest, TestQuadraticLerp) {
	frc::Translation2d t = GeometryUtil::quadraticLerp(frc::Translation2d(1_m, 2_m), frc::Translation2d(3_m, 4_m), frc::Translation2d(5_m, 6_m), 0.5);
	EXPECT_DOUBLE_EQ(3, t.X()());
	EXPECT_DOUBLE_EQ(4, t.Y()());
}

TEST(GeometryUtilTest, TestCubicLerp) {
	frc::Translation2d t = GeometryUtil::cubicLerp(frc::Translation2d(1_m, 2_m), frc::Translation2d(3_m, 4_m), frc::Translation2d(5_m, 6_m), frc::Translation2d(7_m, 8_m), 0.5);
	EXPECT_DOUBLE_EQ(4, t.X()());
	EXPECT_DOUBLE_EQ(5, t.Y()());
}

TEST(GeometryUtilTest, TestModulo) {
	EXPECT_DOUBLE_EQ(1, GeometryUtil::modulo(11_deg, 10_deg)());
	EXPECT_DOUBLE_EQ(0, GeometryUtil::modulo(10_deg, 2_deg)());
	EXPECT_DOUBLE_EQ(5, GeometryUtil::modulo(5_deg, 7_deg)());
	EXPECT_DOUBLE_EQ(5, GeometryUtil::modulo(95_deg, 10_deg)());
}