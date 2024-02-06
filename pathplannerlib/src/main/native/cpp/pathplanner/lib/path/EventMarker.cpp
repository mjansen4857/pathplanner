#include "pathplanner/lib/path/EventMarker.h"
#include "pathplanner/lib/auto/CommandUtil.h"

using namespace pathplanner;

EventMarker EventMarker::fromJson(const wpi::json &json) {
	double pos = json.at("waypointRelativePos").get<double>();
	return EventMarker(pos,
			CommandUtil::commandFromJson(json.at("command"), false));
}
