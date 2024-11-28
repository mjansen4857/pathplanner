#include "pathplanner/lib/path/Waypoint.h"
#include "pathplanner/lib/util/JSONUtil.h"

using namespace pathplanner;

Waypoint Waypoint::autoControlPoints(frc::Translation2d anchor,
		frc::Rotation2d heading, std::optional<frc::Translation2d> prevAnchor,
		std::optional<frc::Translation2d> nextAnchor) {
	std::optional < frc::Translation2d > prevControl = std::nullopt;
	std::optional < frc::Translation2d > nextControl = std::nullopt;

	if (prevAnchor.has_value()) {
		auto d = anchor.Distance(prevAnchor.value())
				* AUTO_CONTROL_DISTANCE_FACTOR;
		prevControl = anchor - frc::Translation2d(d, heading);
	}
	if (nextAnchor.has_value()) {
		auto d = anchor.Distance(nextAnchor.value())
				* AUTO_CONTROL_DISTANCE_FACTOR;
		nextControl = anchor + frc::Translation2d(d, heading);
	}

	return Waypoint(prevControl, anchor, nextControl);
}

Waypoint Waypoint::fromJson(const wpi::json &waypointJson) {
	auto anchor = JSONUtil::translation2dFromJson(waypointJson.at("anchor"));
	std::optional < frc::Translation2d > prevControl = std::nullopt;
	std::optional < frc::Translation2d > nextControl = std::nullopt;

	if (!waypointJson.at("prevControl").is_null()) {
		prevControl = JSONUtil::translation2dFromJson(
				waypointJson.at("prevControl"));
	}
	if (!waypointJson.at("nextControl").is_null()) {
		nextControl = JSONUtil::translation2dFromJson(
				waypointJson.at("nextControl"));
	}

	return Waypoint(prevControl, anchor, nextControl);
}

Waypoint Waypoint::flip() const {
	std::optional < frc::Translation2d > flippedPrevControl = std::nullopt;
	frc::Translation2d flippedAnchor = FlippingUtil::flipFieldPosition(anchor);
	std::optional < frc::Translation2d > flippedNextControl = std::nullopt;

	if (prevControl.has_value()) {
		flippedPrevControl = FlippingUtil::flipFieldPosition(
				prevControl.value());
	}
	if (nextControl.has_value()) {
		flippedNextControl = FlippingUtil::flipFieldPosition(
				nextControl.value());
	}

	return Waypoint(flippedPrevControl, flippedAnchor, flippedNextControl);
}
