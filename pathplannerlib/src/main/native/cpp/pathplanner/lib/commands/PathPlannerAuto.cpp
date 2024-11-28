#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include <frc/Filesystem.h>
#include <wpi/MemoryBuffer.h>
#include <hal/FRCUsageReporting.h>
#include <stdexcept>

using namespace pathplanner;

std::string PathPlannerAuto::currentPathName = "";
int PathPlannerAuto::m_instances = 0;

PathPlannerAuto::PathPlannerAuto(std::string autoName) {
	if (!AutoBuilder::isConfigured()) {
		throw FRC_MakeError(frc::err::CommandIllegalUse,
				"AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
	}

	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer.value()->GetCharBuffer());

	std::string version = "1.0";
	if (json.at("version").is_string()) {
		version = json.at("version").get<std::string>();
	}

	if (version != "2025.0") {
		throw std::runtime_error(
				"Incompatible file version for '" + autoName
						+ ".auto'. Actual: '" + version
						+ "' Expected: '2025.0'");
	}

	initFromJson(json);

	AddRequirements(m_autoCommand->GetRequirements());
	SetName(autoName);

	m_autoLoop = std::make_unique<frc::EventLoop>();

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerAuto, m_instances);
}

PathPlannerAuto::PathPlannerAuto(frc2::CommandPtr &&autoCommand,
		frc::Pose2d startingPose) : m_autoCommand(
		std::move(autoCommand).Unwrap()), m_startingPose(startingPose) {
	AddRequirements(m_autoCommand->GetRequirements());

	m_autoLoop = std::make_unique<frc::EventLoop>();

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathPlannerAuto, m_instances);
}

frc2::Trigger PathPlannerAuto::nearFieldPositionAutoFlipped(
		frc::Translation2d blueFieldPosition, units::meter_t tolerance) {
	frc::Translation2d redFieldPosition = FlippingUtil::flipFieldPosition(
			blueFieldPosition);

	return condition(
			[blueFieldPosition, redFieldPosition, tolerance]() {
				if (AutoBuilder::shouldFlip()) {
					return AutoBuilder::getCurrentPose().Translation().Distance(
							redFieldPosition) <= tolerance;
				} else {
					return AutoBuilder::getCurrentPose().Translation().Distance(
							blueFieldPosition) <= tolerance;
				}
			});
}

frc2::Trigger PathPlannerAuto::inFieldArea(frc::Translation2d boundingBoxMin,
		frc::Translation2d boundingBoxMax) {
	if (boundingBoxMin.X() >= boundingBoxMax.X()
			|| boundingBoxMin.Y() >= boundingBoxMax.Y()) {
		throw std::invalid_argument(
				"Minimum bounding box position must have X and Y coordinates less than the maximum bounding box position");
	}

	return condition(
			[boundingBoxMin, boundingBoxMax]() {
				frc::Pose2d currentPose = AutoBuilder::getCurrentPose();
				return currentPose.X() >= boundingBoxMin.X()
						&& currentPose.Y() >= boundingBoxMin.Y()
						&& currentPose.X() <= boundingBoxMax.X()
						&& currentPose.Y() <= boundingBoxMax.Y();
			});
}

frc2::Trigger PathPlannerAuto::inFieldAreaAutoFlipped(
		frc::Translation2d blueBoundingBoxMin,
		frc::Translation2d blueBoundingBoxMax) {
	if (blueBoundingBoxMin.X() >= blueBoundingBoxMax.X()
			|| blueBoundingBoxMin.Y() >= blueBoundingBoxMax.Y()) {
		throw std::invalid_argument(
				"Minimum bounding box position must have X and Y coordinates less than the maximum bounding box position");
	}

	frc::Translation2d redBoundingBoxMin = FlippingUtil::flipFieldPosition(
			blueBoundingBoxMin);
	frc::Translation2d redBoundingBoxMax = FlippingUtil::flipFieldPosition(
			blueBoundingBoxMax);

	return condition(
			[blueBoundingBoxMin, blueBoundingBoxMax, redBoundingBoxMin,
					redBoundingBoxMax]() {
				frc::Pose2d currentPose = AutoBuilder::getCurrentPose();
				if (AutoBuilder::shouldFlip()) {
					return currentPose.X() >= blueBoundingBoxMin.X()
							&& currentPose.Y() >= blueBoundingBoxMin.Y()
							&& currentPose.X() <= blueBoundingBoxMax.X()
							&& currentPose.Y() <= blueBoundingBoxMax.Y();
				} else {
					return currentPose.X() >= redBoundingBoxMin.X()
							&& currentPose.Y() >= redBoundingBoxMin.Y()
							&& currentPose.X() <= redBoundingBoxMax.X()
							&& currentPose.Y() <= redBoundingBoxMax.Y();
				}
			});
}

std::vector<std::shared_ptr<PathPlannerPath>> PathPlannerAuto::getPathGroupFromAutoFile(
		std::string autoName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	auto fileBuffer = wpi::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer.value()->GetCharBuffer());
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
	m_timer.Restart();

	m_isRunning = true;
	m_autoLoop->Poll();
}

void PathPlannerAuto::Execute() {
	m_autoCommand->Execute();

	m_autoLoop->Poll();
}

bool PathPlannerAuto::IsFinished() {
	return m_autoCommand->IsFinished();
}

void PathPlannerAuto::End(bool interrupted) {
	m_autoCommand->End(interrupted);
	m_timer.Stop();

	m_isRunning = false;
	m_autoLoop->Poll();
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
