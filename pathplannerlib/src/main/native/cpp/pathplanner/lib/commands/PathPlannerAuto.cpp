#include "pathplanner/lib/commands/PathPlannerAuto.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"

using namespace pathplanner;

PathPlannerAuto::PathPlannerAuto(std::string autoName) {
	if (!AutoBuilder::isConfigured()) {
		throw FRC_MakeError(frc::err::CommandIllegalUse,
				"AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
	}

	m_autoCommand = AutoBuilder::buildAuto(autoName).Unwrap();
	m_requirements = m_autoCommand->GetRequirements();
	PPLibTelemetry::registerHotReloadAuto(autoName,
			std::shared_ptr < PathPlannerAuto > (this));
}

void PathPlannerAuto::hotReload(const wpi::json &json) {
	m_autoCommand = AutoBuilder::getAutoCommandFromJson(json).Unwrap();
	m_requirements = m_autoCommand->GetRequirements();
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
