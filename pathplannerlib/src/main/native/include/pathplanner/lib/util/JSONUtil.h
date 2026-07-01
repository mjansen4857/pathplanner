#pragma once

#include <wpi/util/json.hpp>
#include <wpi/math/geometry/Translation2d.hpp>

namespace pathplanner {

namespace JSONUtil {

/**
 * Create a Translation2d from a json object containing x and y fields
 *
 * @param translationJson The json object representing a translation
 * @return Translation2d from the given json
 */
inline wpi::math::Translation2d translation2dFromJson(
		const wpi::util::json &translationJson) {
	auto x = wpi::units::meter_t { translationJson.at("x").get_number() };
	auto y = wpi::units::meter_t { translationJson.at("y").get_number() };
	return wpi::math::Translation2d(x, y);
}

}

}
