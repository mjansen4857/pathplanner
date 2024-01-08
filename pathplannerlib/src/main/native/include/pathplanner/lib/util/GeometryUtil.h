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

#define PI 3.14159265358979323846
#define FIELD_LENGTH 16.54_m

namespace pathplanner {
namespace GeometryUtil {
constexpr frc::Translation2d flipFieldPosition(const frc::Translation2d &pos) {
	return frc::Translation2d(FIELD_LENGTH - pos.X(), pos.Y());
}

constexpr frc::Rotation2d flipFieldRotation(const frc::Rotation2d &rotation) {
	return frc::Rotation2d(180_deg) - rotation;
}

constexpr frc::Pose2d flipFieldPose(const frc::Pose2d &pose) {
	return frc::Pose2d(flipFieldPosition(pose.Translation()),
			flipFieldRotation(pose.Rotation()));
}

constexpr units::second_t unitLerp(units::second_t const startVal,
		units::second_t const endVal, double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::meters_per_second_t unitLerp(
		units::meters_per_second_t const startVal,
		units::meters_per_second_t const endVal, double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::meters_per_second_squared_t unitLerp(
		units::meters_per_second_squared_t const startVal,
		units::meters_per_second_squared_t const endVal, double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::radians_per_second_t unitLerp(
		units::radians_per_second_t const startVal,
		units::radians_per_second_t const endVal, double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::radians_per_second_squared_t unitLerp(
		units::radians_per_second_squared_t const startVal,
		units::radians_per_second_squared_t const endVal, double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::meter_t unitLerp(units::meter_t const startVal,
		units::meter_t const endVal, double const t) {
	return startVal + (endVal - startVal) * t;
}

constexpr units::curvature_t unitLerp(units::curvature_t const startVal,
		units::curvature_t const endVal, double const t) {
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

inline units::degree_t modulo(units::degree_t const a,
		units::degree_t const b) {
	return a - (b * units::math::floor(a / b));
}

inline bool isFinite(units::meter_t const u) {
	return std::isfinite(u());
}

inline bool isNaN(units::meter_t const u) {
	return std::isnan(u());
}
}
}
