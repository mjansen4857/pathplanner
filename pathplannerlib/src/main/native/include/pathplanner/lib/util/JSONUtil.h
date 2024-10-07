#pragma once

#include <wpi/json.h>
#include <frc/geometry/Translation2d.h>

namespace pathplanner {

namespace JSONUtil {

/**
 * Create a Translation2d from a json object containing x and y fields
 *
 * @param translationJson The json object representing a translation
 * @return Translation2d from the given json
 */
inline frc::Translation2d translation2dFromJson(
		wpi::json::const_reference translationJson) {
	auto x = units::meter_t { translationJson.at("x").get<double>() };
	auto y = units::meter_t { translationJson.at("y").get<double>() };
	return frc::Translation2d(x, y);
}

}

}
