#pragma once

#include "pathplanner/lib/pathfinding/Pathfinder.h"
#include "pathplanner/lib/path/PathPoint.h"
#include <networktables/NetworkTableInstance.h>
#include <networktables/DoubleArrayTopic.h>
#include <networktables/StringTopic.h>
#include <networktables/NetworkTableListener.h>
#include <vector>
#include <wpi/mutex.h>

namespace pathplanner {
class RemoteADStar: public Pathfinder {
public:
	RemoteADStar();

	~RemoteADStar() {
		nt::NetworkTableInstance::GetDefault().RemoveListener(
				m_pathListenerHandle);
	}

	inline bool isNewPathAvailable() override {
		std::scoped_lock lock { m_mutex };

		return m_newPathAvailable;
	}

	std::shared_ptr<PathPlannerPath> getCurrentPath(PathConstraints constraints,
			GoalEndState goalEndState) override;

	void setStartPosition(const frc::Translation2d &start) override;

	void setGoalPosition(const frc::Translation2d &goal) override;

	void setDynamicObstacles(
			const std::vector<std::pair<frc::Translation2d, frc::Translation2d>> &obs,
			const frc::Translation2d &currentRobotPos) override;

private:
	nt::StringPublisher m_navGridJsonPub;
	nt::DoubleArrayPublisher m_startPosPub;
	nt::DoubleArrayPublisher m_goalPosPub;
	nt::DoubleArrayPublisher m_dynamicObsPub;

	nt::DoubleArraySubscriber m_pathPointsSub;
	NT_Listener m_pathListenerHandle;

	std::vector<PathPoint> m_currentPath;
	bool m_newPathAvailable;

	wpi::mutex m_mutex;
};
}
