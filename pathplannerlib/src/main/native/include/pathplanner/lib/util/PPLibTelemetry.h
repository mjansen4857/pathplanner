#pragma once

#include <wpi/nt/NetworkTableInstance.hpp>
#include <wpi/nt/DoubleArrayTopic.hpp>
#include <wpi/nt/DoubleTopic.hpp>
#include <wpi/nt/StructTopic.hpp>
#include <wpi/nt/StructArrayTopic.hpp>
#include <wpi/nt/NetworkTableListener.hpp>
#include <string>
#include <unordered_map>
#include <vector>
#include <memory>
#include <optional>
#include <wpi/units/velocity.hpp>
#include <wpi/units/angular_velocity.hpp>
#include <wpi/units/length.hpp>
#include <span>
#include <wpi/math/geometry/Pose2d.hpp>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/commands/PathPlannerAuto.h"

namespace nt = wpi::nt;

namespace pathplanner {
class PPLibTelemetry {
public:
	static inline void enableCompetitionMode() {
		m_compMode = true;
	}

	static inline void setVelocities(wpi::units::meters_per_second_t actualVel,
			wpi::units::meters_per_second_t commandedVel,
			wpi::units::degrees_per_second_t actualAngVel,
			wpi::units::degrees_per_second_t commandedAngVel) {
		if (!m_compMode) {
			m_velPub.Set(std::span<const double>( { actualVel(), commandedVel(),
					actualAngVel(), commandedAngVel() }));
		}
	}

	static inline void setCurrentPose(wpi::math::Pose2d pose) {
		if (!m_compMode) {
			m_posePub.Set(pose);
		}
	}

	static inline void setCurrentPath(std::shared_ptr<PathPlannerPath> path) {
		if (!m_compMode) {
			auto poses = path->getPathPoses();
			m_pathPub.Set(std::span { poses.data(), poses.size() });
		}
	}

	static inline void setTargetPose(wpi::math::Pose2d targetPose) {
		if (!m_compMode) {
			m_targetPosePub.Set(targetPose);
		}
	}

	static void registerHotReloadPath(std::string pathName,
			std::shared_ptr<PathPlannerPath> path);

private:
	static void ensureHotReloadListenersInitialized();

	static void handlePathHotReloadEvent(const nt::Event &event);

	static bool m_compMode;

	static nt::DoubleArrayPublisher m_velPub;
	static nt::StructPublisher<wpi::math::Pose2d> m_posePub;
	static nt::StructArrayPublisher<wpi::math::Pose2d> m_pathPub;
	static nt::StructPublisher<wpi::math::Pose2d> m_targetPosePub;

	static std::unordered_map<std::string,
			std::vector<std::shared_ptr<PathPlannerPath>>> m_hotReloadPaths;

	static std::optional<NT_Listener> m_hotReloadPathListener;
};
}
