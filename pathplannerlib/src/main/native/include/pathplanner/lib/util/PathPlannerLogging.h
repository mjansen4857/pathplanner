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
			std::function<void(frc::Pose2d)> logCurrentPose) {
		m_logCurrentPose = logCurrentPose;
	}

	static inline void setLogTargetPoseCallback(
			std::function<void(frc::Pose2d)> logTargetPose) {
		m_logTargetPose = logTargetPose;
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

	static inline void logTargetPose(frc::Pose2d targetPose) {
		if (m_logTargetPose) {
			m_logTargetPose(targetPose);
		}
	}

	static void logActivePath(std::shared_ptr<PathPlannerPath> path) {
		if (m_logActivePath) {
			std::vector < frc::Pose2d > poses;

			if (path) {
				for (const PathPoint &point : path->getAllPathPoints()) {
					poses.push_back(
							frc::Pose2d(point.position, frc::Rotation2d()));
				}
			}

			m_logActivePath(poses);
		}
	}

private:
	static std::function<void(frc::Pose2d)> m_logCurrentPose;
	static std::function<void(frc::Pose2d)> m_logTargetPose;
	static std::function<void(std::vector<frc::Pose2d>&)> m_logActivePath;
};
}
