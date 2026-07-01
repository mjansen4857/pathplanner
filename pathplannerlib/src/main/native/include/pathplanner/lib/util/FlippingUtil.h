#pragma once

#include <wpi/math/geometry/Translation2d.hpp>
#include <wpi/math/geometry/Rotation2d.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/math/kinematics/ChassisVelocities.hpp>
#include <vector>

namespace pathplanner {
class FlippingUtil {
public:
	enum FieldSymmetry {
		kRotational, kMirrored
	};

	static FieldSymmetry symmetryType;
	static wpi::units::meter_t fieldSizeX;
	static wpi::units::meter_t fieldSizeY;

	/**
	 * Flip a field position to the other side of the field, maintaining a blue alliance origin
	 *
	 * @param pos The position to flip
	 * @return The flipped position
	 */
	static inline wpi::math::Translation2d flipFieldPosition(
			const wpi::math::Translation2d &pos) {
		switch (symmetryType) {
		case kRotational:
			return wpi::math::Translation2d(fieldSizeX - pos.X(),
					fieldSizeY - pos.Y());
		case kMirrored:
		default:
			return wpi::math::Translation2d(fieldSizeX - pos.X(), pos.Y());
		}
	}

	/**
	 * Flip a field rotation to the other side of the field, maintaining a blue alliance origin
	 *
	 * @param rotation The rotation to flip
	 * @return The flipped rotation
	 */
	static inline wpi::math::Rotation2d flipFieldRotation(
			const wpi::math::Rotation2d &rotation) {
		switch (symmetryType) {
		case kRotational:
			return rotation - wpi::math::Rotation2d(180_deg);
		case kMirrored:
		default:
			return wpi::math::Rotation2d(180_deg) - rotation;
		}
	}

	/**
	 * Flip a field pose to the other side of the field, maintaining a blue alliance origin
	 *
	 * @param pose The pose to flip
	 * @return The flipped pose
	 */
	static inline wpi::math::Pose2d flipFieldPose(
			const wpi::math::Pose2d &pose) {
		return wpi::math::Pose2d(flipFieldPosition(pose.Translation()),
				flipFieldRotation(pose.Rotation()));
	}

	/**
	 * Flip field relative chassis speeds for the other side of the field, maintaining a blue alliance
	 * origin
	 *
	 * @param fieldSpeeds Field relative chassis speeds
	 * @return Flipped speeds
	 */
	static inline wpi::math::ChassisVelocities flipFieldSpeeds(
			const wpi::math::ChassisVelocities &fieldSpeeds) {
		switch (symmetryType) {
		case kRotational:
			return wpi::math::ChassisVelocities { -fieldSpeeds.vx,
					-fieldSpeeds.vy, fieldSpeeds.omega };
		case kMirrored:
		default:
			return wpi::math::ChassisVelocities { -fieldSpeeds.vx,
					fieldSpeeds.vy, -fieldSpeeds.omega };
		}
	}

	/**
	 * Flip an array of drive feedforwards for the other side of the field. Only does anything if
	 * mirrored symmetry is used
	 *
	 * @param feedforwards Array of drive feedforwards
	 * @return The flipped feedforwards
	 */
	template<class UnitType, class = std::enable_if_t<
			wpi::units::traits::is_unit_t<UnitType>::value>>
	static inline std::vector<UnitType> flipFeedforwards(
			const std::vector<UnitType> &feedforwards) {
		switch (symmetryType) {
		case kRotational:
			return feedforwards;
		case kMirrored:
		default:
			if (feedforwards.size() == 4) {
				return std::vector<UnitType> { feedforwards[1], feedforwards[0],
						feedforwards[3], feedforwards[2] };
			} else if (feedforwards.size() == 2) {
				return std::vector<UnitType> { feedforwards[1], feedforwards[0] };
			}
			return feedforwards; // idk
		}
	}

	/**
	 * Flip an array of drive feedforward X components for the other side of the field. Only does
	 * anything if mirrored symmetry is used
	 *
	 * @param feedforwardXs Array of drive feedforward X components
	 * @return The flipped feedforward X components
	 */
	template<class UnitType, class = std::enable_if_t<
			wpi::units::traits::is_unit_t<UnitType>::value>>
	static inline std::vector<UnitType> flipFeedforwardXs(
			const std::vector<UnitType> &feedforwardXs) {
		return flipFeedforwards(feedforwardXs);
	}

	/**
	 * Flip an array of drive feedforward Y components for the other side of the field. Only does
	 * anything if mirrored symmetry is used
	 *
	 * @param feedforwardYs Array of drive feedforward Y components
	 * @return The flipped feedforward Y components
	 */
	template<class UnitType, class = std::enable_if_t<
			wpi::units::traits::is_unit_t<UnitType>::value>>
	static inline std::vector<UnitType> flipFeedforwardYs(
			const std::vector<UnitType> &feedforwardYs) {
		auto flippedFeedforwardYs = flipFeedforwards(feedforwardYs);
		switch (symmetryType) {
		case kRotational:
			return flippedFeedforwardYs;
		case kMirrored:
		default:
			// Y directions also need to be inverted
			for (auto &feedforwardY : flippedFeedforwardYs) {
				feedforwardY *= -1;
			}
			return flippedFeedforwardYs;
		}
	}
};
}
