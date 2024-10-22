#pragma once

#include <functional>
#include <vector>
#include <frc/geometry/Pose2d.h>
#include <memory>
#include <optional>
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
class PathPlannerLogging {
public:
	static inline void setLogCurrentPoseCallback(
			std::function<void(const frc::Pose2d&)> logCurrentPose) {
		m_logCurrentPose = logCurrentPose;
	}

	static inline void setLogTargetPoseCallback(
			std::function<void(const frc::Pose2d&)> logTargetPose) {
		m_logTargetPose = logTargetPose;
	}

	static inline void setLogActivePathCallback(
			std::function<void(const std::vector<frc::Pose2d>&)> logActivePath) {
		m_logActivePath = logActivePath;
	}

	static inline void logCurrentPose(const frc::Pose2d &pose) {
		if (m_logCurrentPose) {
			m_logCurrentPose(pose);
		}
	}

	static inline void logTargetPose(const frc::Pose2d &targetPose) {
		if (m_logTargetPose) {
			m_logTargetPose(targetPose);
		}
	}

	static void logActivePath(const PathPlannerPath *path) {
		if (m_logActivePath) {
			std::vector < frc::Pose2d > poses;

			if (path) {
				poses = path->getPathPoses();
			}

			m_logActivePath(poses);
		}
	}

private:
	static std::function<void(const frc::Pose2d&)> m_logCurrentPose;
	static std::function<void(const frc::Pose2d&)> m_logTargetPose;
	static std::function<void(const std::vector<frc::Pose2d>&)> m_logActivePath;
};
}
