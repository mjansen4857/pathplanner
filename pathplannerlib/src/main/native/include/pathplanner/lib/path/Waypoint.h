#pragma once

#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <wpi/json.h>
#include <optional>
#include "pathplanner/lib/util/GeometryUtil.h"

namespace pathplanner {

#define AUTO_CONTROL_DISTANCE_FACTOR 1.0 / 3.0

class Waypoint {
public:
	std::optional<frc::Translation2d> prevControl;
	frc::Translation2d anchor;
	std::optional<frc::Translation2d> nextControl;

	/**
	 * Create a waypoint from its anchor point and control points
	 *
	 * @param prevControl The previous control point position
	 * @param anchor The anchor position
	 * @param nextControl The next control point position
	 */
	constexpr Waypoint(std::optional<frc::Translation2d> prevControl,
			frc::Translation2d anchor,
			std::optional<frc::Translation2d> nextControl) : prevControl(
			prevControl), anchor(anchor), nextControl(nextControl) {
	}

	/**
	 * Flip this waypoint to the other side of the field, maintaining a blue alliance origin
	 *
	 * @return The flipped waypoint
	 */
	constexpr Waypoint flip() const {
		std::optional < frc::Translation2d > flippedPrevControl = std::nullopt;
		frc::Translation2d flippedAnchor = GeometryUtil::flipFieldPosition(
				anchor);
		std::optional < frc::Translation2d > flippedNextControl = std::nullopt;

		if (prevControl.has_value()) {
			flippedPrevControl = GeometryUtil::flipFieldPosition(
					prevControl.value());
		}
		if (nextControl.has_value()) {
			flippedNextControl = GeometryUtil::flipFieldPosition(
					nextControl.value());
		}

		return Waypoint(flippedPrevControl, flippedAnchor, flippedNextControl);
	}

	/**
	 * Create a waypoint with auto calculated control points based on the positions of adjacent
	 * waypoints. This is used internally, and you probably shouldn't use this.
	 *
	 * @param anchor The anchor point of the waypoint to create
	 * @param heading The heading of this waypoint
	 * @param prevAnchor The position of the previous anchor point. This can be nullopt for the start point
	 * @param nextAnchor The position of the next anchor point. This can be nullopt for the end point
	 * @return Waypoint with auto calculated control points
	 */
	static Waypoint autoControlPoints(frc::Translation2d anchor,
			frc::Rotation2d heading,
			std::optional<frc::Translation2d> prevAnchor,
			std::optional<frc::Translation2d> nextAnchor);

	/**
	 * Create a waypoint from JSON
	 *
	 * @param waypointJson JSON object representing a waypoint
	 * @return The waypoint created from JSON
	 */
	static Waypoint fromJson(const wpi::json &waypointJson);

private:
	inline static frc::Translation2d translationFromJson(
			const wpi::json &json) {
		auto x = units::meter_t { json.at("x").get<double>() };
		auto y = units::meter_t { json.at("y").get<double>() };
		return frc::Translation2d(x, y);
	}
};
}
