#pragma once

#include <functional>
#include <vector>
#include <frc/geometry/Pose2d.h>
#include <frc/geometry/Translation2d.h>
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
class PathPlannerLogging {
public:
	static inline void setLogCurrentPoseCallback(
			std::function<void(frc::Pose2d)> logCurrentPose) {
		m_logCurrentPose = logCurrentPose;
	}

	static inline void setLogLookaheadCallback(
			std::function<void(frc::Translation2d)> logLookahead) {
		m_logLookahead = logLookahead;
	}

	static inline void setLogActivePathCallback(
			std::function<void(std::vector<frc::Pose2d>)> logActivePath) {
		m_logActivePath = logActivePath;
	}

	static inline void logCurrentPose(frc::Pose2d pose) {
		if (m_logCurrentPose) {
			m_logCurrentPose(pose);
		}
	}

	static inline void logLookahead(frc::Translation2d lookahead) {
		if (m_logLookahead) {
			m_logLookahead(lookahead);
		}
	}

	static void logActivePath(const PathPlannerPath &path) {
		if (m_logActivePath) {
			std::vector < frc::Pose2d > poses;
			for (const PathPoint &point : path.getAllPathPoints()) {
				poses.push_back(frc::Pose2d(point.position, frc::Rotation2d()));
			}
			m_logActivePath(poses);
		}
	}

private:
	static std::function<void(frc::Pose2d)> m_logCurrentPose;
	static std::function<void(frc::Translation2d)> m_logLookahead;
	static std::function<void(std::vector<frc::Pose2d>&)> m_logActivePath;
};
}
