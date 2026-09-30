#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include "pathplanner/lib/util/GeometryUtil.h"

using namespace pathplanner;

TEST_CASE("GeometryUtilTest/TestUnitLerp", "[GeometryUtilTest]") {
	CHECK_THAT(GeometryUtil::unitLerp(10_s, 20_s, 0.2)(), Catch::Matchers::WithinULP(12.0, 4));
	CHECK_THAT(GeometryUtil::unitLerp(10_mps, 20_mps, 0.2)(), Catch::Matchers::WithinULP(12.0, 4));
	CHECK_THAT(GeometryUtil::unitLerp(10_mps_sq, 20_mps_sq, 0.2)(), Catch::Matchers::WithinULP(12.0, 4));
	CHECK_THAT(GeometryUtil::unitLerp(10_rad_per_s, 20_rad_per_s, 0.2)(), Catch::Matchers::WithinULP(12.0, 4));
	CHECK_THAT(GeometryUtil::unitLerp(10_rad_per_s_sq, 20_rad_per_s_sq, 0.2)(), Catch::Matchers::WithinULP(12.0, 4));
	CHECK_THAT(GeometryUtil::unitLerp(10_m, 20_m, 0.2)(), Catch::Matchers::WithinULP(12.0, 4));
	CHECK_THAT(GeometryUtil::unitLerp(wpi::units::curvature_t {10}, wpi::units::curvature_t {20}, 0.2)(), Catch::Matchers::WithinULP(12.0, 4));
}

TEST_CASE("GeometryUtilTest/TestRotationLerp", "[GeometryUtilTest]") {
	wpi::math::Rotation2d r = GeometryUtil::rotationLerp(wpi::math::Rotation2d(0_deg), wpi::math::Rotation2d(180_deg), 0.5);
	CHECK_THAT(r.Degrees()(), Catch::Matchers::WithinULP(90.0, 4));
	r = GeometryUtil::rotationLerp(wpi::math::Rotation2d(0_deg), wpi::math::Rotation2d(-180_deg), 0.25);
	CHECK_THAT(r.Degrees()(), Catch::Matchers::WithinULP(-45.0, 4));
}

TEST_CASE("GeometryUtilTest/TestTranslationLerp", "[GeometryUtilTest]") {
	wpi::math::Translation2d t = GeometryUtil::translationLerp(wpi::math::Translation2d(2.3_m, 7_m), wpi::math::Translation2d(3.5_m, 2.1_m), 0.2);
	CHECK_THAT(t.X()(), Catch::Matchers::WithinULP(2.54, 4));
	CHECK_THAT(t.Y()(), Catch::Matchers::WithinULP(6.02, 4));

	t = GeometryUtil::translationLerp(wpi::math::Translation2d(-1.5_m, 2_m), wpi::math::Translation2d(1.5_m, -3_m), 0.5);
	CHECK_THAT(t.X()(), Catch::Matchers::WithinULP(0.0, 4));
	CHECK_THAT(t.Y()(), Catch::Matchers::WithinULP(-0.5, 4));
}

TEST_CASE("GeometryUtilTest/TestQuadraticLerp", "[GeometryUtilTest]") {
	wpi::math::Translation2d t = GeometryUtil::quadraticLerp(wpi::math::Translation2d(1_m, 2_m), wpi::math::Translation2d(3_m, 4_m), wpi::math::Translation2d(5_m, 6_m), 0.5);
	CHECK_THAT(t.X()(), Catch::Matchers::WithinULP(3.0, 4));
	CHECK_THAT(t.Y()(), Catch::Matchers::WithinULP(4.0, 4));
}

TEST_CASE("GeometryUtilTest/TestCubicLerp", "[GeometryUtilTest]") {
	wpi::math::Translation2d t = GeometryUtil::cubicLerp(wpi::math::Translation2d(1_m, 2_m), wpi::math::Translation2d(3_m, 4_m), wpi::math::Translation2d(5_m, 6_m), wpi::math::Translation2d(7_m, 8_m), 0.5);
	CHECK_THAT(t.X()(), Catch::Matchers::WithinULP(4.0, 4));
	CHECK_THAT(t.Y()(), Catch::Matchers::WithinULP(5.0, 4));
}

TEST_CASE("GeometryUtilTest/TestModulo", "[GeometryUtilTest]") {
	CHECK_THAT(GeometryUtil::modulo(11_deg, 10_deg)(), Catch::Matchers::WithinULP(1.0, 4));
	CHECK_THAT(GeometryUtil::modulo(10_deg, 2_deg)(), Catch::Matchers::WithinULP(0.0, 4));
	CHECK_THAT(GeometryUtil::modulo(5_deg, 7_deg)(), Catch::Matchers::WithinULP(5.0, 4));
	CHECK_THAT(GeometryUtil::modulo(95_deg, 10_deg)(), Catch::Matchers::WithinULP(5.0, 4));
}

TEST_CASE("GeometryUtilTest/TestCalculateRadius", "[GeometryUtilTest]") {
	CHECK_THAT(GeometryUtil::calculateRadius(wpi::math::Translation2d(1_m, 1_m), wpi::math::Translation2d(1.5_m, 1.5_m), wpi::math::Translation2d(2.0_m, 1_m))(), Catch::Matchers::WithinAbs(-0.5, 0.001));
	CHECK_THAT(GeometryUtil::calculateRadius(wpi::math::Translation2d(1_m, 1_m), wpi::math::Translation2d(1.5_m, 0.5_m), wpi::math::Translation2d(2.0_m, 1_m))(), Catch::Matchers::WithinAbs(0.5, 0.001));
	CHECK_THAT(GeometryUtil::calculateRadius(wpi::math::Translation2d(1_m, 1_m), wpi::math::Translation2d(1.5_m, 1.25_m), wpi::math::Translation2d(2.0_m, 1_m))(), Catch::Matchers::WithinAbs(-0.625, 0.001));
	CHECK_THAT(GeometryUtil::calculateRadius(wpi::math::Translation2d(1_m, 1_m), wpi::math::Translation2d(1.5_m, 0.75_m), wpi::math::Translation2d(2.0_m, 1_m))(), Catch::Matchers::WithinAbs(0.625, 0.001));
}