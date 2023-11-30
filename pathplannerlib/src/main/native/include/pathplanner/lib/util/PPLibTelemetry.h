#pragma once

#include <networktables/NetworkTableInstance.h>
#include <networktables/DoubleArrayTopic.h>
#include <networktables/DoubleTopic.h>
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
#include "pathplanner/lib/commands/PathPlannerAuto.h"

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
		m_velPub.Set(std::span<const double>( { actualVel(), commandedVel(),
				actualAngVel(), commandedAngVel() }));
	}

	static inline void setPathInaccuracy(units::meter_t inaccuracy) {
		m_inaccuracyPub.Set(inaccuracy());
	}

	static inline void setCurrentPose(frc::Pose2d pose) {
		m_posePub.Set(
				std::span<const double>( { pose.X()(), pose.Y()(),
						pose.Rotation().Radians()() }));
	}

	static void setCurrentPath(std::shared_ptr<PathPlannerPath> path);

	static inline void setTargetPose(frc::Pose2d targetPose) {
		m_targetPosePub.Set(std::span<const double>( { targetPose.X()(),
				targetPose.Y()(), targetPose.Rotation().Radians()() }));
	}

	static void registerHotReloadPath(std::string pathName,
			std::shared_ptr<PathPlannerPath> path);

private:
	static void ensureHotReloadListenersInitialized();

	static void handlePathHotReloadEvent(const nt::Event &event);

	static bool m_compMode;

	static nt::DoubleArrayPublisher m_velPub;
	static nt::DoublePublisher m_inaccuracyPub;
	static nt::DoubleArrayPublisher m_posePub;
	static nt::DoubleArrayPublisher m_pathPub;
	static nt::DoubleArrayPublisher m_targetPosePub;

	static std::unordered_map<std::string,
			std::vector<std::shared_ptr<PathPlannerPath>>> m_hotReloadPaths;

	static std::optional<NT_Listener> m_hotReloadPathListener;
};
}
