#pragma once

#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <wpi/json.h>
#include <optional>
#include "pathplanner/lib/util/FlippingUtil.h"

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
	Waypoint flip() const;

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
};
}
