#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include <frc/Filesystem.h>
#include <wpi/MemoryBuffer.h>
#include <hal/FRCUsageReporting.h>

using namespace pathplanner;

int PathPlannerAuto::m_instances = 0;

PathPlannerAuto::PathPlannerAuto(std::string autoName) {
	if (!AutoBuilder::isConfigured()) {
		throw FRC_MakeError(frc::err::CommandIllegalUse,
				"AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
	}

	m_autoCommand = AutoBuilder::buildAuto(autoName).Unwrap();
	m_requirements = m_autoCommand->GetRequirements();
	SetName(autoName);

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerAuto, m_instances);
}

std::vector<std::shared_ptr<PathPlannerPath>> PathPlannerAuto::getPathGroupFromAutoFile(
		std::string autoName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	std::error_code error_code;
	std::unique_ptr < wpi::MemoryBuffer > fileBuffer =
			wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (fileBuffer == nullptr || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	return pathsFromCommandJson(json.at("command"));
}

frc::Pose2d PathPlannerAuto::getStartingPoseFromAutoFile(std::string autoName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	std::error_code error_code;
	std::unique_ptr < wpi::MemoryBuffer > fileBuffer =
			wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (fileBuffer == nullptr || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	return AutoBuilder::getStartingPoseFromJson(json.at("startingPose"));
}

void PathPlannerAuto::Initialize() {
	m_autoCommand->Initialize();
}

void PathPlannerAuto::Execute() {
	m_autoCommand->Execute();
}

bool PathPlannerAuto::IsFinished() {
	return m_autoCommand->IsFinished();
}

void PathPlannerAuto::End(bool interrupted) {
	m_autoCommand->End(interrupted);
}

std::vector<std::shared_ptr<PathPlannerPath>> PathPlannerAuto::pathsFromCommandJson(
		const wpi::json &json) {
	std::vector < std::shared_ptr < PathPlannerPath >> paths;

	std::string type = json.at("type").get<std::string>();
	wpi::json::const_reference data = json.at("data");

	if (type == "path") {
		std::string pathName = data.at("pathName").get<std::string>();
		paths.push_back(PathPlannerPath::fromPathFile(pathName));
	} else if (type == "sequential" || type == "parallel" || type == "race"
			|| type == "deadline") {
		for (wpi::json::const_reference cmdJson : data.at("commands")) {
			auto cmdPaths = pathsFromCommandJson(cmdJson);
			paths.insert(paths.end(), cmdPaths.begin(), cmdPaths.end());
		}
	}

	return paths;
}
