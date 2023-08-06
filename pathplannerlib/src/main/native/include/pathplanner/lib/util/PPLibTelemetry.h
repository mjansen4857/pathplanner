#pragma once

#include <networktables/NetworkTableInstance.h>
#include <networktables/DoubleArrayTopic.h>
#include <networktables/DoubleTopic.h>
#include <networktables/DoubleArrayTopic.h>
#include <networktables/NetworkTableListener.h>
#include <string>
#include <unordered_map>
#include <vector>
#include <memory>
#include <optional>
#include <units/velocity.h>
#include <units/angular_velocity.h>
#include <units/length.h>
#include <span>
#include <frc/geometry/Pose2d.h>
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
class PPLibTelemetry {
public:
	static inline void enableCompetitionMode() {
		m_compMode = true;
	}

	static inline void setVelocities(units::meters_per_second_t actualVel,
			units::meters_per_second_t commandedVel,
			units::degrees_per_second_t actualAngVel,
			units::degrees_per_second_t commandedAngVel) {
		if (!m_compMode) {
			m_velPub.Set(std::span<const double>( { actualVel(), commandedVel(),
					actualAngVel(), commandedAngVel() }));
		}
	}

	static inline void setPathInaccuracy(units::meter_t inaccuracy) {
		if (!m_compMode) {
			m_inaccuracyPub.Set(inaccuracy());
		}
	}

	static inline void setCurrentPose(frc::Pose2d pose) {
		if (!m_compMode) {
			m_posePub.Set(std::span<const double>( { pose.X()(), pose.Y()(),
					pose.Rotation().Degrees()() }));
		}
	}

	static void setCurrentPath(std::shared_ptr<PathPlannerPath> path);

	static inline void setLookahead(
			std::optional<frc::Translation2d> lookahead) {
		if (!m_compMode && lookahead) {
			m_lookaheadPub.Set(std::span<const double>( {
					lookahead.value().X()(), lookahead.value().Y()() }));
		}
	}

	static void registerHotReloadPath(std::string pathName,
			std::shared_ptr<PathPlannerPath> path);

	// static void registerHotReloadAuto(std::string autoName, std::shared_ptr<PathPlannerAuto> ppAuto);

private:
	static void ensureHotReloadListenersInitialized();

	static void handlePathHotReloadEvent(const nt::Event &event);

	// static void handleAutoHotReloadEvent(const nt::Event& event);

	static bool m_compMode;

	static nt::DoubleArrayPublisher m_velPub;
	static nt::DoublePublisher m_inaccuracyPub;
	static nt::DoubleArrayPublisher m_posePub;
	static nt::DoubleArrayPublisher m_pathPub;
	static nt::DoubleArrayPublisher m_lookaheadPub;

	static std::unordered_map<std::string,
			std::vector<std::shared_ptr<PathPlannerPath>>> m_hotReloadPaths;
	// static std::unordered_map<std::string,
	// 		std::vector<std::shared_ptr<PathPlannerAuto>>> m_hotReloadAutos;

	static std::optional<NT_Listener> m_hotReloadPathListener;
	static std::optional<NT_Listener> m_hotReloadAutoListener;
};
}
