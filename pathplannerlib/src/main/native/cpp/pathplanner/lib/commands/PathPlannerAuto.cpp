#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include <frc/Filesystem.h>
#include <wpi/raw_istream.h>

using namespace pathplanner;

PathPlannerAuto::PathPlannerAuto(std::string autoName) {
	if (!AutoBuilder::isConfigured()) {
		throw FRC_MakeError(frc::err::CommandIllegalUse,
				"AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
	}

	m_autoCommand = AutoBuilder::buildAuto(autoName).Unwrap();
	m_requirements = m_autoCommand->GetRequirements();
}

std::vector<std::shared_ptr<PathPlannerPath>> PathPlannerAuto::getPathGroupFromAutoFile(
		std::string autoName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	std::error_code error_code;
	wpi::raw_fd_istream input { filePath, error_code };

	if (error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json;
	input >> json;

	return pathsFromCommandJson(json.at("command"));
}

frc::Pose2d PathPlannerAuto::getStartingPoseFromAutoFile(std::string autoName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	std::error_code error_code;
	wpi::raw_fd_istream input { filePath, error_code };

	if (error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json;
	input >> json;

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
