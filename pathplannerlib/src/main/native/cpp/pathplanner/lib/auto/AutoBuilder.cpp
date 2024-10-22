#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/commands/PathfindThenFollowPath.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include "pathplanner/lib/util/FlippingUtil.h"
#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include <stdexcept>
#include <frc2/command/Commands.h>
#include <frc/Filesystem.h>
#include <optional>
#include <wpi/MemoryBuffer.h>

using namespace pathplanner;

bool AutoBuilder::m_configured = false;
std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> AutoBuilder::m_pathFollowingCommandBuilder;
std::function<frc::Pose2d()> AutoBuilder::m_poseSupplier;
std::function<void(const frc::Pose2d&)> AutoBuilder::m_resetPose;
std::function<bool()> AutoBuilder::m_shouldFlipPath;
bool AutoBuilder::m_isHolonomic = false;

bool AutoBuilder::m_commandRefsGeneratedForSendable = false;
frc2::CommandPtr AutoBuilder::m_noneCommand = frc2::cmd::None();
std::map<std::filesystem::path, frc2::CommandPtr> AutoBuilder::m_autoCommands;

bool AutoBuilder::m_pathfindingConfigured = false;
std::function<
		frc2::CommandPtr(frc::Pose2d, PathConstraints,
				units::meters_per_second_t)> AutoBuilder::m_pathfindToPoseCommandBuilder;
std::function<
		frc2::CommandPtr(std::shared_ptr<PathPlannerPath>, PathConstraints)> AutoBuilder::m_pathfindThenFollowPathCommandBuilder;

void AutoBuilder::configure(std::function<frc::Pose2d()> poseSupplier,
		std::function<void(const frc::Pose2d&)> resetPose,
		std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
		std::function<void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
		std::shared_ptr<PathFollowingController> controller,
		RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
		frc2::Subsystem *driveSubsystem) {
	if (m_configured) {
		FRC_ReportError(frc::err::Error,
				"Auto builder has already been configured. This is likely in error.");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, output, controller, robotConfig,
			shouldFlipPath, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path) {
		return FollowPathCommand(path, poseSupplier,
				robotRelativeSpeedsSupplier, output, controller, robotConfig,
				shouldFlipPath, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_poseSupplier = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;
	AutoBuilder::m_shouldFlipPath = shouldFlipPath;
	AutoBuilder::m_isHolonomic = robotConfig.isHolonomic;

	AutoBuilder::m_pathfindToPoseCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, output, controller, robotConfig,
			driveSubsystem](frc::Pose2d pose, PathConstraints constraints,
			units::meters_per_second_t goalEndVel) {
		return PathfindingCommand(pose, constraints, goalEndVel, poseSupplier,
				robotRelativeSpeedsSupplier, output, controller, robotConfig, {
						driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindThenFollowPathCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, output, controller, robotConfig,
			shouldFlipPath, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path,
			PathConstraints constraints) {
		return PathfindThenFollowPath(path, constraints, poseSupplier,
				robotRelativeSpeedsSupplier, output, controller, robotConfig,
				shouldFlipPath, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindingConfigured = true;
}

void AutoBuilder::configureCustom(std::function<frc::Pose2d()> poseSupplier,
		std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> pathFollowingCommandBuilder,
		std::function<void(const frc::Pose2d&)> resetPose, bool isHolonomic,
		std::function<bool()> shouldFlipPose) {
	if (m_configured) {
		FRC_ReportError(frc::err::Error,
				"Auto builder has already been configured. This is likely in error.");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = pathFollowingCommandBuilder;
	AutoBuilder::m_poseSupplier = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;
	AutoBuilder::m_shouldFlipPath = shouldFlipPose;
	AutoBuilder::m_isHolonomic = isHolonomic;

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
	return PathPlannerAuto(autoName).ToPtr();
}

frc2::CommandPtr AutoBuilder::resetOdom(frc::Pose2d bluePose) {
	if (!m_configured) {
		throw std::runtime_error(
				"Auto builder was used to build a command before being configured");
	}

	return frc2::cmd::RunOnce([bluePose]() {
		if (m_shouldFlipPath()) {
			m_resetPose(FlippingUtil::flipFieldPose(bluePose));
		} else {
			m_resetPose(bluePose);
		}
	});
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

void AutoBuilder::regenerateSendableReferences() {
	std::vector < std::filesystem::path > autoPathFilepaths = getAllAutoPaths();

	for (std::filesystem::path path : autoPathFilepaths) {
		// A command which is an auto that come from a path
		m_autoCommands.insert_or_assign(path,
				buildAuto(path.replace_extension("").string()));
	}
}

frc::SendableChooser<frc2::Command*> AutoBuilder::buildAutoChooser(
		std::string defaultAutoName) {
	return buildAutoChooserFilterPath(
			[](const PathPlannerAuto &autoCommand,
					std::filesystem::path autoPath) {
				return true;
			},defaultAutoName);
}

frc::SendableChooser<frc2::Command*> AutoBuilder::buildAutoChooserFilter(
		std::function<bool(const PathPlannerAuto&)> filter,
		std::string defaultAutoName) {
	return buildAutoChooserFilterPath(
			[&filter](const PathPlannerAuto &autoCommand,
					std::filesystem::path autoPath) {
				return filter(autoCommand);
			},defaultAutoName);
}

frc::SendableChooser<frc2::Command*> AutoBuilder::buildAutoChooserFilterPath(
		std::function<bool(const PathPlannerAuto&, std::filesystem::path)> filter,
		std::string defaultAutoName) {
	if (!m_configured) {
		throw std::runtime_error(
				"AutoBuilder was not configured before attempting to build an auto chooser");
	}

	if (!m_commandRefsGeneratedForSendable) {
		regenerateSendableReferences();
		m_commandRefsGeneratedForSendable = true;
	}

	frc::SendableChooser<frc2::Command*> sendableChooser;
	bool defaultSelected = false;

	for (const std::pair<const std::filesystem::path, frc2::CommandPtr> &entry : m_autoCommands) {
		std::string autoName = entry.first.stem().string();

		// Found the default for sendableChooser
		if (defaultAutoName == autoName) {
			sendableChooser.SetDefaultOption(autoName, entry.second.get());
			defaultSelected = true;
		} else if (filter(*static_cast<PathPlannerAuto*>(entry.second.get()),
				entry.first)) {
			sendableChooser.AddOption(autoName, entry.second.get());
		}
	}

	// None is the default
	if (!defaultSelected || defaultAutoName == "") {
		sendableChooser.SetDefaultOption("None", m_noneCommand.get());
	}
	// None is just there, extra precaution for programmers
	else {
		sendableChooser.AddOption("None", m_noneCommand.get());
	}

	return sendableChooser;
}

std::vector<std::string> AutoBuilder::getAllAutoNames() {
	std::vector < std::string > autoNames;

	for (const std::filesystem::path &path : getAllAutoPaths()) {
		autoNames.push_back(path.stem().string());
	}

	return autoNames;
}

std::vector<std::filesystem::path> AutoBuilder::getAllAutoPaths() {
	std::filesystem::path deployPath = frc::filesystem::GetDeployDirectory();
	std::filesystem::path autosPath = deployPath / "pathplanner/autos";

	if (!std::filesystem::directory_entry { autosPath }.exists()) {
		FRC_ReportError(frc::err::Error,
				"AutoBuilder could not locate the pathplanner autos directory");

		return {};
	}

	std::vector < std::filesystem::path > autoPathNames;

	for (std::filesystem::directory_entry const &entry : std::filesystem::recursive_directory_iterator {
			autosPath,
			std::filesystem::directory_options::skip_permission_denied }) {
		if (!entry.is_regular_file()
				|| entry.path().extension().string() != ".auto") {
			continue;
		}
		autoPathNames.emplace_back(entry.path().lexically_relative(autosPath));
	}

	return autoPathNames;
}
