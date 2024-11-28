#pragma once

#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Pose2d.h>
#include <units/time.h>
#include <units/velocity.h>
#include <units/acceleration.h>
#include <units/length.h>
#include <units/angle.h>
#include <units/angular_velocity.h>
#include <units/angular_acceleration.h>
#include <units/math.h>
#include <units/curvature.h>
#include <math.h>
#include <type_traits>

#define PI 3.14159265358979323846

namespace pathplanner {
namespace GeometryUtil {
template<class UnitType, class = std::enable_if_t<
		units::traits::is_unit_t<UnitType>::value>>
constexpr UnitType unitLerp(UnitType const startVal, UnitType const endVal,
		double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr double doubleLerp(const double startVal, const double endVal,
		const double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr frc::Rotation2d rotationLerp(frc::Rotation2d const startVal,
		frc::Rotation2d const endVal, double const t) {
	return startVal + ((endVal - startVal) * t);
}

constexpr frc::Translation2d translationLerp(frc::Translation2d const startVal,
		frc::Translation2d const endVal, double const t) {
	return startVal + ((endVal - startVal) * t);
}

constexpr frc::Translation2d quadraticLerp(frc::Translation2d const a,
		frc::Translation2d const b, frc::Translation2d const c,
		double const t) {
	frc::Translation2d const p0 = translationLerp(a, b, t);
	frc::Translation2d const p1 = translationLerp(b, c, t);
	return translationLerp(p0, p1, t);
}

constexpr frc::Translation2d cubicLerp(frc::Translation2d const a,
		frc::Translation2d const b, frc::Translation2d const c,
		frc::Translation2d const d, double const t) {
	frc::Translation2d const p0 = quadraticLerp(a, b, c, t);
	frc::Translation2d const p1 = quadraticLerp(b, c, d, t);
	return translationLerp(p0, p1, t);
}

constexpr frc::Rotation2d cosineInterpolate(frc::Rotation2d const y1,
		frc::Rotation2d const y2, double const mu) {
	double const mu2 = (1 - frc::Rotation2d(units::radian_t { mu * PI }).Cos())
			/ 2;
	return frc::Rotation2d(y1.Radians() * (1 - mu2) + y2.Radians() * mu2);
}

units::meter_t calculateRadius(const frc::Translation2d a,
		const frc::Translation2d b, const frc::Translation2d c);

template<class UnitType, class = std::enable_if_t<
		units::traits::is_unit_t<UnitType>::value>>
inline UnitType modulo(UnitType const a, UnitType const b) {
	return a - (b * units::math::floor(a / b));
}

template<class UnitType, class = std::enable_if_t<
		units::traits::is_unit_t<UnitType>::value>>
inline bool isFinite(UnitType const u) {
	return std::isfinite(u());
}

template<class UnitType, class = std::enable_if_t<
		units::traits::is_unit_t<UnitType>::value>>
inline bool isNaN(UnitType const u) {
	return std::isnan(u());
}
}
}
