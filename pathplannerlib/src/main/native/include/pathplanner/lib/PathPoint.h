#pragma once

#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <units/velocity.h>
#include <units/length.h>
#include <frc/Errors.h>

namespace pathplanner {
class PathPoint {
public:
	frc::Translation2d m_position;
	frc::Rotation2d m_heading;
	frc::Rotation2d m_holonomicRotation;
	units::meters_per_second_t m_velocityOverride;

	units::meter_t m_prevControlLength = -1_m;
	units::meter_t m_nextControlLength = -1_m;

	constexpr PathPoint(frc::Translation2d const position,
			frc::Rotation2d const heading, frc::Rotation2d holonomicRotation,
			units::meters_per_second_t velocityOverride) : m_position(position), m_heading(
			heading), m_holonomicRotation(holonomicRotation), m_velocityOverride(
			velocityOverride) {
	}

	constexpr PathPoint(frc::Translation2d const position,
			frc::Rotation2d const heading, frc::Rotation2d holonomicRotation) : PathPoint(
			position, heading, holonomicRotation, -1_mps) {
	}

	constexpr PathPoint(frc::Translation2d const position,
			frc::Rotation2d const heading,
			units::meters_per_second_t const velocityOverride) : PathPoint(
			position, heading, frc::Rotation2d(), velocityOverride) {
	}

	constexpr PathPoint(frc::Translation2d const position,
			frc::Rotation2d const heading) : PathPoint(position, heading,
			frc::Rotation2d(), -1_mps) {
	}

	constexpr PathPoint withPrevControlLength(units::meter_t const length) {
		if (length <= 0_m) {
			throw FRC_MakeError(frc::err::InvalidParameter,
					"Control point lengths must be > 0");
		}

		m_prevControlLength = length;
		return *this;
	}

	constexpr PathPoint withNextControlLength(units::meter_t const length) {
		if (length <= 0_m) {
			throw FRC_MakeError(frc::err::InvalidParameter,
					"Control point lengths must be > 0");
		}

		m_nextControlLength = length;
		return *this;
	}

	constexpr PathPoint withControlLengths(units::meter_t const prevLength,
			units::meter_t const nextLength) {
		if (prevLength <= 0_m || nextLength <= 0_m) {
			throw FRC_MakeError(frc::err::InvalidParameter,
					"Control point lengths must be > 0");
		}

		m_prevControlLength = prevLength;
		m_nextControlLength = nextLength;
		return *this;
	}

	static PathPoint fromCurrentHolonomicState(frc::Pose2d const currentPose,
			frc::ChassisSpeeds const currentSpeeds) {
		units::meters_per_second_t const linearVel = units::math::sqrt(
				(currentSpeeds.vx * currentSpeeds.vx)
						+ (currentSpeeds.vy * currentSpeeds.vy));
		frc::Rotation2d const heading(
				units::math::atan2(currentSpeeds.vy, currentSpeeds.vx));
		return PathPoint(currentPose.Translation(), heading,
				currentPose.Rotation(), linearVel);
	}

	constexpr static PathPoint fromCurrentDifferentialState(
			frc::Pose2d const currentPose,
			frc::ChassisSpeeds const currentSpeeds) {
		return PathPoint(currentPose.Translation(), currentPose.Rotation(),
				currentSpeeds.vx);
	}
};
}
