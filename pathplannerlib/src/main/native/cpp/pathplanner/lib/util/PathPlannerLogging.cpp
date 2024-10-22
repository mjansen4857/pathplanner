#include "pathplanner/lib/util/PathPlannerLogging.h"

using namespace pathplanner;

std::function<void(const frc::Pose2d&)> PathPlannerLogging::m_logCurrentPose;
std::function<void(const frc::Pose2d&)> PathPlannerLogging::m_logTargetPose;
std::function<void(const std::vector<frc::Pose2d>&)> PathPlannerLogging::m_logActivePath;
