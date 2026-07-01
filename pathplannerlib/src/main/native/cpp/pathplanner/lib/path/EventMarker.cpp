#include "pathplanner/lib/path/EventMarker.h"
#include "pathplanner/lib/auto/CommandUtil.h"

using namespace pathplanner;

EventMarker EventMarker::fromJson(const wpi::util::json &json) {
	std::string name = json.at("name").get_string();
	double pos = json.at("waypointRelativePos").get_number();
	double endPos = -1.0;
	if (json.contains("endWaypointRelativePos")
			&& !json.at("endWaypointRelativePos").is_null()) {
		endPos = json.at("endWaypointRelativePos").get_number();
	}

	if (!json.at("command").is_null()) {
		return EventMarker(name, pos, endPos,
				CommandUtil::commandFromJson(json.at("command"), false, false));
	}

	return EventMarker(name, pos, endPos, wpi::cmd::None());
}
