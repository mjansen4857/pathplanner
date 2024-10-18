#pragma once

#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <vector>

namespace pathplanner {
class FlippingUtil {
public:
	enum FieldSymmetry {
		kRotational, kMirrored
	};

	static FieldSymmetry symmetryType;
	static units::meter_t fieldSizeX;
	static units::meter_t fieldSizeY;

	/**
	 * Flip a field position to the other side of the field, maintaining a blue alliance origin
	 *
	 * @param pos The position to flip
	 * @return The flipped position
	 */
	static inline frc::Translation2d flipFieldPosition(
			const frc::Translation2d &pos) {
		switch (symmetryType) {
		case kRotational:
			return frc::Translation2d(fieldSizeX - pos.X(),
					fieldSizeY - pos.Y());
		case kMirrored:
		default:
			return frc::Translation2d(fieldSizeX - pos.X(), pos.Y());
		}
	}

	/**
	 * Flip a field rotation to the other side of the field, maintaining a blue alliance origin
	 *
	 * @param rotation The rotation to flip
	 * @return The flipped rotation
	 */
	static inline frc::Rotation2d flipFieldRotation(
			const frc::Rotation2d &rotation) {
		switch (symmetryType) {
		case kMirrored:
		case kRotational:
		default:
			return frc::Rotation2d(180_deg) - rotation;
		}
	}

	/**
	 * Flip a field pose to the other side of the field, maintaining a blue alliance origin
	 *
	 * @param pose The pose to flip
	 * @return The flipped pose
	 */
	static inline frc::Pose2d flipFieldPose(const frc::Pose2d &pose) {
		return frc::Pose2d(flipFieldPosition(pose.Translation()),
				flipFieldRotation(pose.Rotation()));
	}

	/**
	 * Flip field relative chassis speeds for the other side of the field, maintaining a blue alliance
	 * origin
	 *
	 * @param fieldSpeeds Field relative chassis speeds
	 * @return Flipped speeds
	 */
	static inline frc::ChassisSpeeds flipFieldSpeeds(
			const frc::ChassisSpeeds &fieldSpeeds) {
		switch (symmetryType) {
		case kRotational:
			return frc::ChassisSpeeds { -fieldSpeeds.vx, -fieldSpeeds.vy,
					fieldSpeeds.omega };
		case kMirrored:
		default:
			return frc::ChassisSpeeds { -fieldSpeeds.vx, fieldSpeeds.vy,
					-fieldSpeeds.omega };
		}
	}

	template<class UnitType, class = std::enable_if_t<
			units::traits::is_unit_t<UnitType>::value>>
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
};
}
