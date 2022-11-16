#pragma once

#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Translation2d.h>
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

#define PI 3.14159265358979323846

namespace pathplanner {
namespace GeometryUtil {
constexpr units::second_t unitLerp(units::second_t startVal,
		units::second_t endVal, double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::meters_per_second_t unitLerp(
		units::meters_per_second_t startVal, units::meters_per_second_t endVal,
		double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::meters_per_second_squared_t unitLerp(
		units::meters_per_second_squared_t startVal,
		units::meters_per_second_squared_t endVal, double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::radians_per_second_t unitLerp(
		units::radians_per_second_t startVal,
		units::radians_per_second_t endVal, double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::radians_per_second_squared_t unitLerp(
		units::radians_per_second_squared_t startVal,
		units::radians_per_second_squared_t endVal, double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::meter_t unitLerp(units::meter_t startVal,
		units::meter_t endVal, double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::curvature_t unitLerp(units::curvature_t startVal,
		units::curvature_t endVal, double t) {
	return startVal + (endVal - startVal) * t;
}

constexpr frc::Rotation2d rotationLerp(const frc::Rotation2d startVal,
		const frc::Rotation2d endVal, double t) {
	return startVal + ((endVal - startVal) * t);
}

constexpr frc::Translation2d translationLerp(const frc::Translation2d startVal,
		const frc::Translation2d endVal, double t) {
	return startVal + ((endVal - startVal) * t);
}

constexpr frc::Translation2d quadraticLerp(const frc::Translation2d a,
		const frc::Translation2d b, const frc::Translation2d c, double t) {
	frc::Translation2d p0 = translationLerp(a, b, t);
	frc::Translation2d p1 = translationLerp(b, c, t);
	return translationLerp(p0, p1, t);
}

constexpr frc::Translation2d cubicLerp(const frc::Translation2d a,
		const frc::Translation2d b, const frc::Translation2d c,
		const frc::Translation2d d, double t) {
	frc::Translation2d p0 = quadraticLerp(a, b, c, t);
	frc::Translation2d p1 = quadraticLerp(b, c, d, t);
	return translationLerp(p0, p1, t);
}

constexpr frc::Rotation2d cosineInterpolate(const frc::Rotation2d y1,
		const frc::Rotation2d y2, double mu) {
	double mu2 = (1 - frc::Rotation2d(units::radian_t { mu * PI }).Cos()) / 2;
	return frc::Rotation2d(y1.Radians() * (1 - mu2) + y2.Radians() * mu2);
}

inline units::degree_t modulo(units::degree_t a, units::degree_t b) {
	return a - (b * units::math::floor(a / b));
}

inline bool isFinite(units::meter_t u) {
	return std::isfinite(u());
}

inline bool isNaN(units::meter_t u) {
	return std::isnan(u());
}

}
}
