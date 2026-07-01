#include "pathplanner/lib/util/PPLibTelemetry.h"
#include <wpi/driverstation/DriverStation.hpp>
#include <wpi/framework/RobotBase.hpp>
#include <wpi/util/json.hpp>
#include <wpi/system/Filesystem.hpp>
#include <wpi/util/raw_ostream.hpp>
#include <wpi/nt/StringTopic.hpp>

using namespace pathplanner;

bool PPLibTelemetry::m_compMode = false;
nt::DoubleArrayPublisher PPLibTelemetry::m_velPub =
		nt::NetworkTableInstance::GetDefault().GetDoubleArrayTopic(
				"/PathPlanner/vel").Publish();
nt::StructPublisher<wpi::math::Pose2d> PPLibTelemetry::m_posePub =
		nt::NetworkTableInstance::GetDefault().GetStructTopic
				< wpi::math::Pose2d > ("/PathPlanner/currentPose").Publish();
nt::StructArrayPublisher<wpi::math::Pose2d> PPLibTelemetry::m_pathPub =
		nt::NetworkTableInstance::GetDefault().GetStructArrayTopic
				< wpi::math::Pose2d > ("/PathPlanner/activePath").Publish();
nt::StructPublisher<wpi::math::Pose2d> PPLibTelemetry::m_targetPosePub =
		nt::NetworkTableInstance::GetDefault().GetStructTopic
				< wpi::math::Pose2d > ("/PathPlanner/targetPose").Publish();

std::unordered_map<std::string, std::vector<std::shared_ptr<PathPlannerPath>>> PPLibTelemetry::m_hotReloadPaths =
		std::unordered_map<std::string,
				std::vector<std::shared_ptr<PathPlannerPath>>>();

std::optional<NT_Listener> PPLibTelemetry::m_hotReloadPathListener =
		std::nullopt;

void PPLibTelemetry::ensureHotReloadListenersInitialized() {
	if (!m_hotReloadPathListener) {
		nt::NetworkTableInstance inst = nt::NetworkTableInstance::GetDefault();
		inst.AddListener(
				inst.GetStringTopic("/PathPlanner/HotReload/hotReloadPath"),
				nt::EventFlags::VALUE_REMOTE, [](const nt::Event &event) {
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
		if (wpi::RobotBase::IsEnabled()) {
			WPILIB_ReportError(wpi::warn::Warning,
					"Ignoring path hot reload, robot is enabled");
			return;
		}

		try {
			std::string_view jsonString =
					event.GetValueEventData()->value.GetString();

			wpi::util::json json = wpi::util::json::parse_or_throw(jsonString);

			std::string pathName = json.at("name").get_string();
			const auto &pathJson = json.at("path");

			if (m_hotReloadPaths.find(pathName) != m_hotReloadPaths.end()) {
				for (std::shared_ptr<PathPlannerPath> path : m_hotReloadPaths.at(
						pathName)) {
					path->hotReload(pathJson);
				}
			}

			if (wpi::RobotBase::IsReal()) {
				const std::string filePath =
						wpi::filesystem::GetDeployDirectory()
								+ "/pathplanner/paths/" + pathName + ".path";

				std::error_code error_code;
				wpi::util::raw_fd_ostream output { filePath, error_code };

				if (error_code) {
					throw std::runtime_error(
							"Cannot save to file: " + filePath);
				}

				output << pathJson;
			}
		} catch (...) {
			WPILIB_ReportError(wpi::warn::Warning,
					"Failed to hot reload path, please redeploy code");
		}
	}
}
