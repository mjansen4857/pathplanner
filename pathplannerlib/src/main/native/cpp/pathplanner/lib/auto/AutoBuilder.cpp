#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/commands/FollowPathHolonomic.h"
#include "pathplanner/lib/commands/FollowPathRamsete.h"
#include "pathplanner/lib/commands/FollowPathLTV.h"
#include "pathplanner/lib/commands/FollowPathWithEvents.h"
#include "pathplanner/lib/commands/PathfindHolonomic.h"
#include "pathplanner/lib/commands/PathfindThenFollowPathHolonomic.h"
#include "pathplanner/lib/commands/PathfindRamsete.h"
#include "pathplanner/lib/commands/PathfindThenFollowPathRamsete.h"
#include "pathplanner/lib/commands/PathfindLTV.h"
#include "pathplanner/lib/commands/PathfindThenFollowPathLTV.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include <stdexcept>
#include <frc2/command/Commands.h>
#include <frc/Filesystem.h>
#include <wpi/MemoryBuffer.h>

using namespace pathplanner;

bool AutoBuilder::m_configured = false;
std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> AutoBuilder::m_pathFollowingCommandBuilder;
std::function<frc::Pose2d()> AutoBuilder::m_getPose;
std::function<void(frc::Pose2d)> AutoBuilder::m_resetPose;

bool AutoBuilder::m_pathfindingConfigured = false;
std::function<
		frc2::CommandPtr(frc::Pose2d, PathConstraints,
				units::meters_per_second_t, units::meter_t)> AutoBuilder::m_pathfindToPoseCommandBuilder;
std::function<
		frc2::CommandPtr(std::shared_ptr<PathPlannerPath>, PathConstraints,
				units::meter_t)> AutoBuilder::m_pathfindThenFollowPathCommandBuilder;

void AutoBuilder::configureHolonomic(std::function<frc::Pose2d()> poseSupplier,
		std::function<void(frc::Pose2d)> resetPose,
		std::function<frc::ChassisSpeeds()> robotRelativeSpeedsSupplier,
		std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
		HolonomicPathFollowerConfig config, frc2::Subsystem *driveSubsystem) {
	if (m_configured) {
		throw std::runtime_error(
				"Auto builder has already been configured. Please only configure auto builder once");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, robotRelativeOutput, config,
			driveSubsystem](std::shared_ptr<PathPlannerPath> path) {
		return FollowPathHolonomic(path, poseSupplier,
				robotRelativeSpeedsSupplier, robotRelativeOutput, config, {
						driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_getPose = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;

	AutoBuilder::m_pathfindToPoseCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, robotRelativeOutput, config,
			driveSubsystem](frc::Pose2d pose, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			units::meter_t rotationDelayDistance) {
		return PathfindHolonomic(pose, constraints, goalEndVel, poseSupplier,
				robotRelativeSpeedsSupplier, robotRelativeOutput, config, {
						driveSubsystem }, rotationDelayDistance).ToPtr();
	};
	AutoBuilder::m_pathfindThenFollowPathCommandBuilder = [poseSupplier,
			robotRelativeSpeedsSupplier, robotRelativeOutput, config,
			driveSubsystem](std::shared_ptr<PathPlannerPath> path,
			PathConstraints constraints, units::meter_t rotationDelayDistance) {
		return PathfindThenFollowPathHolonomic(path, constraints, poseSupplier,
				robotRelativeSpeedsSupplier, robotRelativeOutput, config, {
						driveSubsystem }, rotationDelayDistance).ToPtr();
	};
	AutoBuilder::m_pathfindingConfigured = true;
}

void AutoBuilder::configureRamsete(std::function<frc::Pose2d()> poseSupplier,
		std::function<void(frc::Pose2d)> resetPose,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		ReplanningConfig replanningConfig, frc2::Subsystem *driveSubsystem) {
	if (m_configured) {
		throw std::runtime_error(
				"Auto builder has already been configured. Please only configure auto builder once");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = [poseSupplier, speedsSupplier,
			output, replanningConfig, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path) {
		return FollowPathRamsete(path, poseSupplier, speedsSupplier, output,
				replanningConfig, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_getPose = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;

	AutoBuilder::m_pathfindToPoseCommandBuilder = [poseSupplier, speedsSupplier,
			output, replanningConfig, driveSubsystem](frc::Pose2d pose,
			PathConstraints constraints, units::meters_per_second_t goalEndVel,
			units::meter_t rotationDelayDistance) {
		return PathfindRamsete(pose.Translation(), constraints, goalEndVel,
				poseSupplier, speedsSupplier, output, replanningConfig, {
						driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindThenFollowPathCommandBuilder =
			[poseSupplier, speedsSupplier, output, replanningConfig,
					driveSubsystem](std::shared_ptr<PathPlannerPath> path,
					PathConstraints constraints,
					units::meter_t rotationDelayDistance) {
				return PathfindThenFollowPathRamsete(path, constraints,
						poseSupplier, speedsSupplier, output, replanningConfig,
						{ driveSubsystem }).ToPtr();
			};
	AutoBuilder::m_pathfindingConfigured = true;
}

void AutoBuilder::configureRamsete(std::function<frc::Pose2d()> poseSupplier,
		std::function<void(frc::Pose2d)> resetPose,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		units::unit_t<frc::RamseteController::b_unit> b,
		units::unit_t<frc::RamseteController::zeta_unit> zeta,
		ReplanningConfig replanningConfig, frc2::Subsystem *driveSubsystem) {
	if (m_configured) {
		throw std::runtime_error(
				"Auto builder has already been configured. Please only configure auto builder once");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = [poseSupplier, speedsSupplier,
			output, b, zeta, replanningConfig, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path) {
		return FollowPathRamsete(path, poseSupplier, speedsSupplier, output, b,
				zeta, replanningConfig, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_getPose = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;

	AutoBuilder::m_pathfindToPoseCommandBuilder = [poseSupplier, speedsSupplier,
			output, b, zeta, replanningConfig, driveSubsystem](frc::Pose2d pose,
			PathConstraints constraints, units::meters_per_second_t goalEndVel,
			units::meter_t rotationDelayDistance) {
		return PathfindRamsete(pose.Translation(), constraints, goalEndVel,
				poseSupplier, speedsSupplier, output, b, zeta, replanningConfig,
				{ driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindThenFollowPathCommandBuilder = [poseSupplier,
			speedsSupplier, output, b, zeta, replanningConfig, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path, PathConstraints constraints,
			units::meter_t rotationDelayDistance) {
		return PathfindThenFollowPathRamsete(path, constraints, poseSupplier,
				speedsSupplier, output, b, zeta, replanningConfig, {
						driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindingConfigured = true;
}

void AutoBuilder::configureLTV(std::function<frc::Pose2d()> poseSupplier,
		std::function<void(frc::Pose2d)> resetPose,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		const wpi::array<double, 3> &Qelms, const wpi::array<double, 2> &Relms,
		units::second_t dt, ReplanningConfig replanningConfig,
		frc2::Subsystem *driveSubsystem) {
	if (m_configured) {
		throw std::runtime_error(
				"Auto builder has already been configured. Please only configure auto builder once");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = [poseSupplier, speedsSupplier,
			output, Qelms, Relms, dt, replanningConfig, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path) {
		return FollowPathLTV(path, poseSupplier, speedsSupplier, output, Qelms,
				Relms, dt, replanningConfig, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_getPose = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;

	AutoBuilder::m_pathfindToPoseCommandBuilder = [poseSupplier, speedsSupplier,
			output, Qelms, Relms, dt, replanningConfig, driveSubsystem](
			frc::Pose2d pose, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			units::meter_t rotationDelayDistance) {
		return PathfindLTV(pose.Translation(), constraints, goalEndVel,
				poseSupplier, speedsSupplier, output, Qelms, Relms, dt,
				replanningConfig, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindThenFollowPathCommandBuilder = [poseSupplier,
			speedsSupplier, output, Qelms, Relms, dt, replanningConfig,
			driveSubsystem](std::shared_ptr<PathPlannerPath> path,
			PathConstraints constraints, units::meter_t rotationDelayDistance) {
		return PathfindThenFollowPathLTV(path, constraints, poseSupplier,
				speedsSupplier, output, Qelms, Relms, dt, replanningConfig, {
						driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindingConfigured = true;
}

void AutoBuilder::configureLTV(std::function<frc::Pose2d()> poseSupplier,
		std::function<void(frc::Pose2d)> resetPose,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
		ReplanningConfig replanningConfig, frc2::Subsystem *driveSubsystem) {
	if (m_configured) {
		throw std::runtime_error(
				"Auto builder has already been configured. Please only configure auto builder once");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = [poseSupplier, speedsSupplier,
			output, dt, replanningConfig, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path) {
		return FollowPathLTV(path, poseSupplier, speedsSupplier, output, dt,
				replanningConfig, { driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_getPose = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;

	AutoBuilder::m_pathfindToPoseCommandBuilder = [poseSupplier, speedsSupplier,
			output, dt, replanningConfig, driveSubsystem](frc::Pose2d pose,
			PathConstraints constraints, units::meters_per_second_t goalEndVel,
			units::meter_t rotationDelayDistance) {
		return PathfindLTV(pose.Translation(), constraints, goalEndVel,
				poseSupplier, speedsSupplier, output, dt, replanningConfig, {
						driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindThenFollowPathCommandBuilder = [poseSupplier,
			speedsSupplier, output, dt, replanningConfig, driveSubsystem](
			std::shared_ptr<PathPlannerPath> path, PathConstraints constraints,
			units::meter_t rotationDelayDistance) {
		return PathfindThenFollowPathLTV(path, constraints, poseSupplier,
				speedsSupplier, output, dt, replanningConfig,
				{ driveSubsystem }).ToPtr();
	};
	AutoBuilder::m_pathfindingConfigured = true;
}

void AutoBuilder::configureCustom(
		std::function<frc2::CommandPtr(std::shared_ptr<PathPlannerPath>)> pathFollowingCommandBuilder,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<void(frc::Pose2d)> resetPose) {
	if (m_configured) {
		throw std::runtime_error(
				"Auto builder has already been configured. Please only configure auto builder once");
	}

	AutoBuilder::m_pathFollowingCommandBuilder = pathFollowingCommandBuilder;
	AutoBuilder::m_getPose = poseSupplier;
	AutoBuilder::m_resetPose = resetPose;
	AutoBuilder::m_configured = true;

	AutoBuilder::m_pathfindingConfigured = false;
}

frc2::CommandPtr AutoBuilder::followPathWithEvents(
		std::shared_ptr<PathPlannerPath> path) {
	if (!m_configured) {
		throw std::runtime_error(
				"Auto builder was used to build a path following command before being configured");
	}

	return FollowPathWithEvents(m_pathFollowingCommandBuilder(path).Unwrap(),
			path, m_getPose).ToPtr();
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

	// Workaround to trim trailing \0 bytes
	std::span<const uint8_t> buffer = fileBuffer->GetBuffer();
	size_t trimSize = buffer.size();
	for (size_t i = trimSize - 1; i != 0; i--) {
		if (buffer[i] == 0) {
			trimSize = i;
		} else {
			break;
		}
	}
	std::span<const uint8_t> trimmed = buffer.first(trimSize);

	wpi::json json = wpi::json::parse(trimmed.begin(), trimmed.end());

	return getAutoCommandFromJson(json);
}

frc2::CommandPtr AutoBuilder::getAutoCommandFromJson(const wpi::json &json) {
	wpi::json::const_reference commandJson = json.at("command");

	frc2::CommandPtr autoCommand = CommandUtil::commandFromJson(commandJson);
	if (!json.at("startingPose").is_null()) {
		frc::Pose2d startPose = getStartingPoseFromJson(
				json.at("startingPose"));
		return frc2::cmd::Sequence(frc2::cmd::RunOnce([startPose]() {
			m_resetPose(startPose);
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
		PathConstraints constraints, units::meters_per_second_t goalEndVel,
		units::meter_t rotationDelayDistance) {
	if (!m_pathfindingConfigured) {
		throw std::runtime_error(
				"Auto builder was used to build a pathfinding command before being configured");
	}

	return m_pathfindToPoseCommandBuilder(pose, constraints, goalEndVel,
			rotationDelayDistance);
}

frc2::CommandPtr AutoBuilder::pathfindThenFollowPath(
		std::shared_ptr<PathPlannerPath> goalPath,
		PathConstraints pathfindingConstraints,
		units::meter_t rotationDelayDistance) {
	if (!m_pathfindingConfigured) {
		throw std::runtime_error(
				"Auto builder was used to build a pathfinding command before being configured");
	}

	return m_pathfindThenFollowPathCommandBuilder(goalPath,
			pathfindingConstraints, rotationDelayDistance);
}
