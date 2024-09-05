#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/commands/PathfindThenFollowPath.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include <stdexcept>
#include <frc2/command/Commands.h>
#include <frc/Filesystem.h>
#include <filesystem>
#include <optional>
#include <wpi/MemoryBuffer.h>

using namespace pathplanner;

bool AutoBuilder::m_configured = false;
std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> AutoBuilder::m_pathFollowingCommandBuilder;
std::function<void(frc::Pose2d)> AutoBuilder::m_resetPose;
std::function<bool()> AutoBuilder::m_shouldFlipPath;

std::vector<frc2::CommandPtr> AutoBuilder::m_autoCommands;

bool AutoBuilder::m_pathfindingConfigured = false;
std::function<
		frc2::CommandPtr(frc::Pose2d, PathConstraints,
				units::meters_per_second_t)> AutoBuilder::m_pathfindToPoseCommandBuilder;
std::function<
		frc2::CommandPtr(std::shared_ptr<PathPlannerPath>, PathConstraints)> AutoBuilder::m_pathfindThenFollowPathCommandBuilder;

void AutoBuilder::configure(std::function<frc::Pose2d()> poseSupplier,
		std::function<void(frc::Pose2d)> resetPose,
		std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
		std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
		std::shared_ptr<PathFollowingController> controller,
		RobotConfig robotConfig, ReplanningConfig replanningConfig,
		std::function<bool()> shouldFlipPath, frc2::Subsystem *driveSubsystem) {
	if (m_configured) {
		FRC_ReportError(frc::err::Error,
				"Auto builder has already been configured. This is likely in error.");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, robotRelativeOutput, controller,
			robotConfig, replanningConfig, shouldFlipPath, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path) {
		return FollowPathCommand(path, poseSupplier,
				robotRelativeSpeedsSupplier, robotRelativeOutput, controller,
				robotConfig, replanningConfig, shouldFlipPath,
				{ driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;
	AutoBuilder::m_shouldFlipPath = shouldFlipPath;

	AutoBuilder::m_pathfindToPoseCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, robotRelativeOutput, controller,
			robotConfig, replanningConfig, driveSubsystem](frc::Pose2d pose,
			PathConstraints constraints,
			units::meters_per_second_t goalEndVel) {
		return PathfindingCommand(pose, constraints, goalEndVel, poseSupplier,
				robotRelativeSpeedsSupplier, robotRelativeOutput, controller,
				robotConfig, replanningConfig, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindThenFollowPathCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, robotRelativeOutput, controller,
			robotConfig, replanningConfig, shouldFlipPath, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path,
			PathConstraints constraints) {
		return PathfindThenFollowPath(path, constraints, poseSupplier,
				robotRelativeSpeedsSupplier, robotRelativeOutput, controller,
				robotConfig, replanningConfig, shouldFlipPath,
				{ driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindingConfigured = true;
}

void AutoBuilder::configureCustom(
		std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> pathFollowingCommandBuilder,
		std::function<void(frc::Pose2d)> resetPose,
		std::function<bool()> shouldFlipPose) {
	if (m_configured) {
		FRC_ReportError(frc::err::Error,
				"Auto builder has already been configured. This is likely in error.");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = pathFollowingCommandBuilder;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;
	AutoBuilder::m_shouldFlipPath = shouldFlipPose;

	AutoBuilder::m_pathfindingConfigured = false;
}

frc2::CommandPtr AutoBuilder::followPath(
		std::shared_ptr<PathPlannerPath> path) {
	if (!m_configured) {
		throw std::runtime_error(
				"Auto builder was used to build a path following command before being configured");
	}

	return m_pathFollowingCommandBuilder(path);
}

frc2::CommandPtr AutoBuilder::buildAuto(std::string autoName) {
	const std::string filePath = frc::filesystem::GetDeployDirectory()
			+ "/pathplanner/autos/" + autoName + ".auto";

	std::error_code error_code;
	std::unique_ptr < wpi::MemoryBuffer > fileBuffer =
			wpi::MemoryBuffer::GetFile(filePath, error_code);

	if (fileBuffer == nullptr || error_code) {
		throw std::runtime_error("Cannot open file: " + filePath);
	}

	wpi::json json = wpi::json::parse(fileBuffer->GetCharBuffer());

	return getAutoCommandFromJson(json);
}

frc2::CommandPtr AutoBuilder::getAutoCommandFromJson(const wpi::json &json) {
	wpi::json::const_reference commandJson = json.at("command");
	bool choreoAuto = json.contains("choreoAuto")
			&& json.at("choreoAuto").get<bool>();

	frc2::CommandPtr autoCommand = CommandUtil::commandFromJson(commandJson,
			choreoAuto);
	if (!json.at("startingPose").is_null()) {
		frc::Pose2d startPose = getStartingPoseFromJson(
				json.at("startingPose"));
		return frc2::cmd::Sequence(frc2::cmd::RunOnce([startPose]() {
			if (m_shouldFlipPath()) {
				m_resetPose(GeometryUtil::flipFieldPose(startPose));
			} else {
				m_resetPose(startPose);
			}
		}), std::move(autoCommand));
	} else {
		return autoCommand;
	}
}

frc::Pose2d AutoBuilder::getStartingPoseFromJson(const wpi::json &json) {
	wpi::json::const_reference pos = json.at("position");
	units::meter_t x = units::meter_t { pos.at("x").get<double>() };
	units::meter_t y = units::meter_t { pos.at("y").get<double>() };
	units::degree_t deg = units::degree_t { json.at("rotation").get<double>() };

	return frc::Pose2d(x, y, frc::Rotation2d(deg));
}

frc2::CommandPtr AutoBuilder::pathfindToPose(frc::Pose2d pose,
		PathConstraints constraints, units::meters_per_second_t goalEndVel) {
	if (!m_pathfindingConfigured) {
		throw std::runtime_error(
				"Auto builder was used to build a pathfinding command before being configured");
	}

	return m_pathfindToPoseCommandBuilder(pose, constraints, goalEndVel);
}

frc2::CommandPtr AutoBuilder::pathfindThenFollowPath(
		std::shared_ptr<PathPlannerPath> goalPath,
		PathConstraints pathfindingConstraints) {
	if (!m_pathfindingConfigured) {
		throw std::runtime_error(
				"Auto builder was used to build a pathfinding command before being configured");
	}

	return m_pathfindThenFollowPathCommandBuilder(goalPath,
			pathfindingConstraints);
}

frc::SendableChooser<frc2::Command*> AutoBuilder::buildAutoChooser(
		std::string defaultAutoName) {
	if (!m_configured) {
		throw std::runtime_error(
				"AutoBuilder was not configured before attempting to build an auto chooser");
	}

	frc::SendableChooser<frc2::Command*> chooser;
	bool foundDefaultOption = false;

	for (std::string const &entry : getAllAutoNames()) {
		AutoBuilder::m_autoCommands.emplace_back(
				pathplanner::PathPlannerAuto(entry).ToPtr());
		if (defaultAutoName != "" && entry == defaultAutoName) {
			foundDefaultOption = true;
			chooser.SetDefaultOption(entry, m_autoCommands.back().get());
		} else {
			chooser.AddOption(entry, m_autoCommands.back().get());
		}
	}

	if (!foundDefaultOption) {
		AutoBuilder::m_autoCommands.emplace_back(frc2::cmd::None());
		chooser.SetDefaultOption("None", m_autoCommands.back().get());
	}

	return chooser;
}

std::vector<std::string> AutoBuilder::getAllAutoNames() {
	std::filesystem::path deployPath = frc::filesystem::GetDeployDirectory();
	std::filesystem::path autosPath = deployPath / "pathplanner/autos";

	if (!std::filesystem::directory_entry { autosPath }.exists()) {
		FRC_ReportError(frc::err::Error,
				"AutoBuilder could not locate the pathplanner autos directory");

		return {};
	}

	std::vector < std::string > autoPathNames;

	for (std::filesystem::directory_entry const &entry : std::filesystem::directory_iterator {
			autosPath }) {
		if (!entry.is_regular_file()) {
			continue;
		}
		if (entry.path().extension().string() != ".auto") {
			continue;
		}
		autoPathNames.emplace_back(entry.path().stem().string());
	}

	return autoPathNames;
}
