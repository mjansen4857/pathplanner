#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/auto/CommandUtil.h"
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

	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	std::error_code error_code;
	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (!fileBuffer || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());
	initFromJson(json);

	AddRequirements(m_autoCommand->GetRequirements());
	SetName(autoName);

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerAuto, m_instances);
}

std::vector<std::shared_ptr<PathPlannerPath>> PathPlannerAuto::getPathGroupFromAutoFile(
		std::string autoName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	std::error_code error_code;
	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (!fileBuffer || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());
	bool choreoAuto = json.contains("choreoAuto")
			&& json.at("choreoAuto").get<bool>();

	return pathsFromCommandJson(json.at("command"), choreoAuto);
}

void PathPlannerAuto::initFromJson(const wpi::json &json) {
	bool choreoAuto = json.contains("choreoAuto")
			&& json.at("choreoAuto").get<bool>();
	wpi::json::const_reference commandJson = json.at("command");
	bool resetOdom = json.contains("resetOdom")
			&& json.at("resetOdom").get<bool>();
	auto pathsInAuto = pathsFromCommandJson(commandJson, choreoAuto);
	if (!pathsInAuto.empty()) {
		if (AutoBuilder::isHolonomic()) {
			m_startingPose =
					frc::Pose2d(pathsInAuto[0]->getPoint(0).position,
							pathsInAuto[0]->getIdealStartingState().value().getRotation());
		} else {
			m_startingPose = pathsInAuto[0]->getStartingDifferentialPose();
		}
	} else {
		m_startingPose = frc::Pose2d();
	}

	if (resetOdom) {
		m_autoCommand = frc2::cmd::Sequence(
				AutoBuilder::resetOdom(m_startingPose),
				CommandUtil::commandFromJson(commandJson, choreoAuto)).Unwrap();
	} else {
		m_autoCommand =
				CommandUtil::commandFromJson(commandJson, choreoAuto).Unwrap();
	}
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
		const wpi::json &json, bool choreoPaths) {
	std::vector < std::shared_ptr < PathPlannerPath >> paths;

	std::string type = json.at("type").get<std::string>();
	wpi::json::const_reference data = json.at("data");

	if (type == "path") {
		std::string pathName = data.at("pathName").get<std::string>();
		if (choreoPaths) {
			paths.push_back(PathPlannerPath::fromChoreoTrajectory(pathName));
		} else {
			paths.push_back(PathPlannerPath::fromPathFile(pathName));
		}
	} else if (type == "sequential" || type == "parallel" || type == "race"
			|| type == "deadline") {
		for (wpi::json::const_reference cmdJson : data.at("commands")) {
			auto cmdPaths = pathsFromCommandJson(cmdJson, choreoPaths);
			paths.insert(paths.end(), cmdPaths.begin(), cmdPaths.end());
		}
	}

	return paths;
}
