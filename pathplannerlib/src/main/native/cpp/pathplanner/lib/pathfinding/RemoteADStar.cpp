#include "pathplanner/lib/pathfinding/RemoteADStar.h"
#include <frc/Filesystem.h>
#include <wpi/MemoryBuffer.h>
#include <wpi/json.h>
#include <frc/Errors.h>

using namespace pathplanner;

RemoteADStar::RemoteADStar() {
	auto nt = nt::NetworkTableInstance::GetDefault();

	m_navGridJsonPub = nt.GetStringTopic(
			"/PPLibCoprocessor/RemoteADStar/navGrid").Publish();
	m_startPosPub = nt.GetDoubleArrayTopic(
			"/PPLibCoprocessor/RemoteADStar/startPos").Publish();
	m_goalPosPub = nt.GetDoubleArrayTopic(
			"/PPLibCoprocessor/RemoteADStar/goalPos").Publish();
	m_dynamicObsPub = nt.GetDoubleArrayTopic(
			"/PPLibCoprocessor/RemoteADStar/dynamicObstacles").Publish();

	auto options = nt::PubSubOptions();
	options.keepDuplicates = true;
	options.sendAll = true;
	m_pathPointsSub = nt.GetDoubleArrayTopic(
			"/PPLibCoprocessor/RemoteADStar/pathPoints").Subscribe(
			std::vector<double>(), options);

	m_pathListenerHandle = nt.AddListener(m_pathPointsSub,
			nt::EventFlags::kValueAll, [this](const nt::Event &event) {
				std::scoped_lock lock { m_mutex };

				auto pathPointsArr = event.GetValueEventData()->value.GetDoubleArray();

				m_currentPath.clear();
				for (size_t i = 0; i <= pathPointsArr.size() - 2; i += 2) {
					units::meter_t x { pathPointsArr[i] };
					units::meter_t y { pathPointsArr[i + 1] };

					m_currentPath.emplace_back(frc::Translation2d(x, y),
							std::nullopt, std::nullopt);
				}

				m_newPathAvailable = true;
			}
			);

	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/navgrid.json";

	std::error_code error_code;
	std::unique_ptr < wpi::MemoryBuffer > fileBuffer =
			wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (error_code) {
		FRC_ReportError(frc::err::Error,
				"RemoteADStar failed to load navgrid. Pathfinding will not be functional.");
	} else {
		auto charBuffer = fileBuffer->GetCharBuffer();
		m_navGridJsonPub.Set(std::string(charBuffer.begin(), charBuffer.end()));
	}

	m_newPathAvailable = false;
}

std::shared_ptr<PathPlannerPath> RemoteADStar::getCurrentPath(
		PathConstraints constraints, GoalEndState goalEndState) {
	std::vector < PathPoint > pathPointsCopy;

	{
		std::scoped_lock lock { m_mutex };
		pathPointsCopy.insert(pathPointsCopy.begin(), m_currentPath.begin(),
				m_currentPath.end());
		m_newPathAvailable = false;
	}

	if (pathPointsCopy.size() < 2) {
		return nullptr;
	}

	return PathPlannerPath::fromPathPoints(pathPointsCopy, constraints,
			goalEndState);
}

void RemoteADStar::setStartPosition(const frc::Translation2d &start) {
	m_startPosPub.Set(std::vector<double> { start.X()(), start.Y()() });
}

void RemoteADStar::setGoalPosition(const frc::Translation2d &goal) {
	m_goalPosPub.Set(std::vector<double> { goal.X()(), goal.Y()() });
}

void RemoteADStar::setDynamicObstacles(
		const std::vector<std::pair<frc::Translation2d, frc::Translation2d>> &obs,
		const frc::Translation2d &currentRobotPos) {
	std::vector<double> obsArr;

	// First two doubles represent current robot pos
	obsArr.emplace_back(currentRobotPos.X()());
	obsArr.emplace_back(currentRobotPos.Y()());

	for (auto box : obs) {
		obsArr.emplace_back(box.first.X()());
		obsArr.emplace_back(box.first.Y()());
		obsArr.emplace_back(box.second.X()());
		obsArr.emplace_back(box.second.Y()());
	}

	m_dynamicObsPub.Set(obsArr);
}
