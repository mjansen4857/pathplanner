#include "pathplanner/lib/path/EventMarker.h"
#include "pathplanner/lib/auto/CommandUtil.h"

using namespace pathplanner;

EventMarker EventMarker::fromJson(const wpi::json &json) {
	double pos = json.at("waypointRelativePos").get<double>();
	return EventMarker(pos,
			CommandUtil::commandFromJson(json.at("command"), false));
}

bool EventMarker::shouldTrigger(frc::Pose2d robotPose) {
	if (m_lastRobotPos == frc::Translation2d()
			|| m_markerPos == frc::Translation2d()) {
		m_lastRobotPos = robotPose.Translation();
		return false;
	}

	auto distanceToMarker = robotPose.Translation().Distance(m_markerPos);
	bool trigger = distanceToMarker <= m_minTriggerDistance
			&& m_lastRobotPos.Distance(m_markerPos) < distanceToMarker;
	m_lastRobotPos = robotPose.Translation();
	return trigger;
}
