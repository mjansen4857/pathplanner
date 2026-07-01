#pragma once

#include <functional>
#include <vector>
#include <wpi/math/geometry/Pose2d.hpp>
#include <memory>
#include <optional>
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
class PathPlannerLogging {
public:
	static inline void setLogCurrentPoseCallback(
			std::function<void(const wpi::math::Pose2d&)> logCurrentPose) {
		m_logCurrentPose = logCurrentPose;
	}

	static inline void setLogTargetPoseCallback(
			std::function<void(const wpi::math::Pose2d&)> logTargetPose) {
		m_logTargetPose = logTargetPose;
	}

	static inline void setLogActivePathCallback(
			std::function<void(const std::vector<wpi::math::Pose2d>&)> logActivePath) {
		m_logActivePath = logActivePath;
	}

	static inline void logCurrentPose(const wpi::math::Pose2d &pose) {
		if (m_logCurrentPose) {
			m_logCurrentPose(pose);
		}
	}

	static inline void logTargetPose(const wpi::math::Pose2d &targetPose) {
		if (m_logTargetPose) {
			m_logTargetPose(targetPose);
		}
	}

	static void logActivePath(const PathPlannerPath *path) {
		if (m_logActivePath) {
			std::vector < wpi::math::Pose2d > poses;

			if (path) {
				poses = path->getPathPoses();
			}

			m_logActivePath(poses);
		}
	}

private:
	static std::function<void(const wpi::math::Pose2d&)> m_logCurrentPose;
	static std::function<void(const wpi::math::Pose2d&)> m_logTargetPose;
	static std::function<void(const std::vector<wpi::math::Pose2d>&)> m_logActivePath;
};
}
