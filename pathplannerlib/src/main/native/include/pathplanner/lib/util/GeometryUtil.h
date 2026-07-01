#pragma once

#include <wpi/math/geometry/Rotation2d.hpp>
#include <wpi/math/geometry/Translation2d.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/units/time.hpp>
#include <wpi/units/velocity.hpp>
#include <wpi/units/acceleration.hpp>
#include <wpi/units/length.hpp>
#include <wpi/units/angle.hpp>
#include <wpi/units/angular_velocity.hpp>
#include <wpi/units/angular_acceleration.hpp>
#include <wpi/units/math.hpp>
#include <wpi/units/curvature.hpp>
#include <math.h>
#include <type_traits>

#define PI 3.14159265358979323846

namespace pathplanner {
namespace GeometryUtil {
template<class UnitType, class = std::enable_if_t<
		wpi::units::traits::is_unit_t<UnitType>::value>>
constexpr UnitType unitLerp(UnitType const startVal, UnitType const endVal,
		double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr double doubleLerp(const double startVal, const double endVal,
		const double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr wpi::math::Rotation2d rotationLerp(
		wpi::math::Rotation2d const startVal,
		wpi::math::Rotation2d const endVal, double const t) {
	return startVal + ((endVal - startVal) * t);
}

constexpr wpi::math::Translation2d translationLerp(
		wpi::math::Translation2d const startVal,
		wpi::math::Translation2d const endVal, double const t) {
	return startVal + ((endVal - startVal) * t);
}

constexpr wpi::math::Translation2d quadraticLerp(
		wpi::math::Translation2d const a, wpi::math::Translation2d const b,
		wpi::math::Translation2d const c, double const t) {
	wpi::math::Translation2d const p0 = translationLerp(a, b, t);
	wpi::math::Translation2d const p1 = translationLerp(b, c, t);
	return translationLerp(p0, p1, t);
}

constexpr wpi::math::Translation2d cubicLerp(wpi::math::Translation2d const a,
		wpi::math::Translation2d const b, wpi::math::Translation2d const c,
		wpi::math::Translation2d const d, double const t) {
	wpi::math::Translation2d const p0 = quadraticLerp(a, b, c, t);
	wpi::math::Translation2d const p1 = quadraticLerp(b, c, d, t);
	return translationLerp(p0, p1, t);
}

constexpr wpi::math::Rotation2d cosineInterpolate(
		wpi::math::Rotation2d const y1, wpi::math::Rotation2d const y2,
		double const mu) {
	double const mu2 = (1
			- wpi::math::Rotation2d(wpi::units::radian_t { mu * PI }).Cos())
			/ 2;
	return wpi::math::Rotation2d(y1.Radians() * (1 - mu2) + y2.Radians() * mu2);
}

wpi::units::meter_t calculateRadius(const wpi::math::Translation2d a,
		const wpi::math::Translation2d b, const wpi::math::Translation2d c);

template<class UnitType, class = std::enable_if_t<
		wpi::units::traits::is_unit_t<UnitType>::value>>
inline UnitType modulo(UnitType const a, UnitType const b) {
	return a - (b * wpi::units::math::floor(a / b));
}

template<class UnitType, class = std::enable_if_t<
		wpi::units::traits::is_unit_t<UnitType>::value>>
inline bool isFinite(UnitType const u) {
	return std::isfinite(u());
}

template<class UnitType, class = std::enable_if_t<
		wpi::units::traits::is_unit_t<UnitType>::value>>
inline bool isNaN(UnitType const u) {
	return std::isnan(u());
}
}
}
