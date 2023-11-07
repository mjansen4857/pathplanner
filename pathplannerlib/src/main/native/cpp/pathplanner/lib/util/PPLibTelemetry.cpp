#include "pathplanner/lib/util/PPLibTelemetry.h"
#include <frc/DriverStation.h>
#include <frc/RobotBase.h>
#include <wpi/json.h>
#include <frc/Filesystem.h>
#include <wpi/raw_ostream.h>
#include <networktables/StringTopic.h>

using namespace pathplanner;

bool PPLibTelemetry::m_compMode = false;
nt::DoubleArrayPublisher PPLibTelemetry::m_velPub =
		nt::NetworkTableInstance::GetDefault().GetDoubleArrayTopic(
				"/PathPlanner/vel").Publish();
nt::DoublePublisher PPLibTelemetry::m_inaccuracyPub =
		nt::NetworkTableInstance::GetDefault().GetDoubleTopic(
				"/PathPlanner/inaccuracy").Publish();
nt::DoubleArrayPublisher PPLibTelemetry::m_posePub =
		nt::NetworkTableInstance::GetDefault().GetDoubleArrayTopic(
				"/PathPlanner/currentPose").Publish();
nt::DoubleArrayPublisher PPLibTelemetry::m_pathPub =
		nt::NetworkTableInstance::GetDefault().GetDoubleArrayTopic(
				"/PathPlanner/activePath").Publish();
nt::DoubleArrayPublisher PPLibTelemetry::m_targetPosePub =
		nt::NetworkTableInstance::GetDefault().GetDoubleArrayTopic(
				"/PathPlanner/targetPose").Publish();

std::unordered_map<std::string, std::vector<std::shared_ptr<PathPlannerPath>>> PPLibTelemetry::m_hotReloadPaths =
		std::unordered_map<std::string,
				std::vector<std::shared_ptr<PathPlannerPath>>>();

std::optional<NT_Listener> PPLibTelemetry::m_hotReloadPathListener =
		std::nullopt;

void PPLibTelemetry::setCurrentPath(std::shared_ptr<PathPlannerPath> path) {
	std::vector<double> arr;

	for (const PathPoint &p : path->getAllPathPoints()) {
		frc::Translation2d pos = p.position;
		arr.push_back(pos.X()());
		arr.push_back(pos.Y()());
		// Just add 0 as a heading since it's not needed for displaying a path
		arr.push_back(0.0);
	}

	m_pathPub.Set(std::span { arr.data(), arr.size() });
}

void PPLibTelemetry::ensureHotReloadListenersInitialized() {
	if (!m_hotReloadPathListener) {
		nt::NetworkTableInstance inst = nt::NetworkTableInstance::GetDefault();
		inst.AddListener(
				inst.GetStringTopic("/PathPlanner/HotReload/hotReloadPath"),
				nt::EventFlags::kValueRemote, [](const nt::Event &event) {
					PPLibTelemetry::handlePathHotReloadEvent(event);
				}
		);
	}
}

void PPLibTelemetry::registerHotReloadPath(std::string pathName,
		std::shared_ptr<PathPlannerPath> path) {
	if (!m_compMode) {
		PPLibTelemetry::ensureHotReloadListenersInitialized();

		if (m_hotReloadPaths.find(pathName) == m_hotReloadPaths.end()) {
			m_hotReloadPaths.emplace(pathName,
					std::vector<std::shared_ptr<PathPlannerPath>>());
		}

		m_hotReloadPaths.at(pathName).push_back(path);
	}
}

void PPLibTelemetry::handlePathHotReloadEvent(const nt::Event &event) {
	if (!m_compMode) {
		if (frc::DriverStation::IsEnabled()) {
			FRC_ReportError(frc::warn::Warning,
					"Ignoring path hot reload, robot is enabled");
			return;
		}

		try {
			std::string_view jsonString =
					event.GetValueEventData()->value.GetString();

			wpi::json json = wpi::json::parse(jsonString);

			std::string pathName = json.at("name").get<std::string>();
			wpi::json::const_reference pathJson = json.at("path");

			if (m_hotReloadPaths.find(pathName) != m_hotReloadPaths.end()) {
				for (std::shared_ptr<PathPlannerPath> path : m_hotReloadPaths.at(
						pathName)) {
					path->hotReload(pathJson);
				}
			}

			if (frc::RobotBase::IsReal()) {
				const std::string filePath =
						frc::filesystem::GetDeployDirectory()
								+ "/pathplanner/paths/" + pathName + ".path";

				std::error_code error_code;
				wpi::raw_fd_ostream output { filePath, error_code };

				if (error_code) {
					throw std::runtime_error(
							"Cannot save to file: " + filePath);
				}

				output << pathJson;
			}
		} catch (...) {
			FRC_ReportError(frc::warn::Warning,
					"Failed to hot reload path, please redeploy code");
		}
	}
}
