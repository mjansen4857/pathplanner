#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include <wpi/system/Filesystem.hpp>
#include <wpi/util/MemoryBuffer.hpp>
#include <wpi/hal/UsageReporting.hpp>
#include <stdexcept>

using namespace pathplanner;

std::string PathPlannerAuto::currentPathName = "";
int PathPlannerAuto::m_instances = 0;

PathPlannerAuto::PathPlannerAuto(std::string autoName) : PathPlannerAuto(
		autoName, false) {

}

PathPlannerAuto::PathPlannerAuto(std::string autoName, bool mirror) {
	if (!AutoBuilder::isConfigured()) {
		throw WPILIB_MakeError(wpi::err::CommandIllegalUse,
				"AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
	}

	const std::string filePath = wpi::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	auto fileBuffer = wpi::util::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	auto charBuffer = fileBuffer.value()->GetCharBuffer();
	wpi::util::json json = wpi::util::json::parse_or_throw(std::string_view {
			charBuffer.data(), charBuffer.size() });

	std::string version = "1.0";
	if (json.at("version").is_string()) {
		version = json.at("version").get_string();
	}

	if (version != "2025.0") {
		throw std::runtime_error(
				"Incompatible file version for '" + autoName
						+ ".auto'. Actual: '" + version
						+ "' Expected: '2025.0'");
	}

	initFromJson(json, mirror);

	AddRequirements(m_autoCommand->GetRequirements());
	SetName(autoName);

	m_autoLoop = std::make_unique<wpi::EventLoop>();

	m_instances++;
	HAL_ReportUsage("PathPlanner/PathPlannerAuto", m_instances, "");
}

PathPlannerAuto::PathPlannerAuto(wpi::cmd::CommandPtr &&autoCommand,
		wpi::math::Pose2d startingPose) : m_autoCommand(
		std::move(autoCommand).Unwrap()), m_startingPose(startingPose) {
	AddRequirements(m_autoCommand->GetRequirements());

	m_autoLoop = std::make_unique<wpi::EventLoop>();

	m_instances++;
	HAL_ReportUsage("PathPlanner/PathPlannerAuto", m_instances, "");
}

wpi::cmd::Trigger PathPlannerAuto::nearFieldPositionAutoFlipped(
		wpi::math::Translation2d blueFieldPosition,
		wpi::units::meter_t tolerance) {
	wpi::math::Translation2d redFieldPosition = FlippingUtil::flipFieldPosition(
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

wpi::cmd::Trigger PathPlannerAuto::inFieldArea(
		wpi::math::Translation2d boundingBoxMin,
		wpi::math::Translation2d boundingBoxMax) {
	if (boundingBoxMin.X() >= boundingBoxMax.X()
			|| boundingBoxMin.Y() >= boundingBoxMax.Y()) {
		throw std::invalid_argument(
				"Minimum bounding box position must have X and Y coordinates less than the maximum bounding box position");
	}

	return condition(
			[boundingBoxMin, boundingBoxMax]() {
				wpi::math::Pose2d currentPose = AutoBuilder::getCurrentPose();
				return currentPose.X() >= boundingBoxMin.X()
						&& currentPose.Y() >= boundingBoxMin.Y()
						&& currentPose.X() <= boundingBoxMax.X()
						&& currentPose.Y() <= boundingBoxMax.Y();
			});
}

wpi::cmd::Trigger PathPlannerAuto::inFieldAreaAutoFlipped(
		wpi::math::Translation2d blueBoundingBoxMin,
		wpi::math::Translation2d blueBoundingBoxMax) {
	if (blueBoundingBoxMin.X() >= blueBoundingBoxMax.X()
			|| blueBoundingBoxMin.Y() >= blueBoundingBoxMax.Y()) {
		throw std::invalid_argument(
				"Minimum bounding box position must have X and Y coordinates less than the maximum bounding box position");
	}

	wpi::math::Translation2d redBoundingBoxMin =
			FlippingUtil::flipFieldPosition(blueBoundingBoxMin);
	wpi::math::Translation2d redBoundingBoxMax =
			FlippingUtil::flipFieldPosition(blueBoundingBoxMax);

	return condition(
			[blueBoundingBoxMin, blueBoundingBoxMax, redBoundingBoxMin,
					redBoundingBoxMax]() {
				wpi::math::Pose2d currentPose = AutoBuilder::getCurrentPose();
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
	const std::string filePath = wpi::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	auto fileBuffer = wpi::util::MemoryBuffer::GetFile(filePath);

	if (!fileBuffer) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	auto charBuffer = fileBuffer.value()->GetCharBuffer();
	wpi::util::json json = wpi::util::json::parse_or_throw(std::string_view {
			charBuffer.data(), charBuffer.size() });
	bool choreoAuto = json.contains("choreoAuto")
			&& json.at("choreoAuto").get_bool();

	return pathsFromCommandJson(json.at("command"), choreoAuto);
}

void PathPlannerAuto::initFromJson(const wpi::util::json &json, bool mirror) {
	bool choreoAuto = json.contains("choreoAuto")
			&& json.at("choreoAuto").get_bool();
	const auto &commandJson = json.at("command");
	bool resetOdom = json.contains("resetOdom")
			&& json.at("resetOdom").get_bool();
	auto pathsInAuto = pathsFromCommandJson(commandJson, choreoAuto);
	if (!pathsInAuto.empty()) {
		std::shared_ptr < PathPlannerPath > path0 = pathsInAuto[0];
		if (mirror) {
			path0 = path0->mirrorPath();
		}
		if (AutoBuilder::isHolonomic()) {
			m_startingPose = wpi::math::Pose2d(path0->getPoint(0).position,
					path0->getIdealStartingState().value().getRotation());
		} else {
			m_startingPose = path0->getStartingDifferentialPose();
		}
	} else {
		m_startingPose = wpi::math::Pose2d();
	}

	if (resetOdom) {
		m_autoCommand =
				wpi::cmd::Sequence(AutoBuilder::resetOdom(m_startingPose),
						CommandUtil::commandFromJson(commandJson, choreoAuto,
								mirror)).Unwrap();
	} else {
		m_autoCommand = CommandUtil::commandFromJson(commandJson, choreoAuto,
				mirror).Unwrap();
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
		const wpi::util::json &json, bool choreoPaths) {
	std::vector < std::shared_ptr < PathPlannerPath >> paths;

	std::string type = json.at("type").get_string();
	const auto &data = json.at("data");

	if (type == "path") {
		std::string pathName = data.at("pathName").get_string();
		if (choreoPaths) {
			paths.push_back(PathPlannerPath::fromChoreoTrajectory(pathName));
		} else {
			paths.push_back(PathPlannerPath::fromPathFile(pathName));
		}
	} else if (type == "sequential" || type == "parallel" || type == "race"
			|| type == "deadline") {
		const auto &commands = data.at("commands").get_array();
		for (size_t i = 0; i < commands.size(); i++) {
			auto cmdPaths = pathsFromCommandJson(commands[i], choreoPaths);
			paths.insert(paths.end(), cmdPaths.begin(), cmdPaths.end());
		}
	}

	return paths;
}
