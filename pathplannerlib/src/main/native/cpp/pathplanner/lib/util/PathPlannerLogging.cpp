#include "pathplanner/lib/util/PathPlannerLogging.h"

using namespace pathplanner;

std::function<void(frc::Pose2d)> PathPlannerLogging::m_logCurrentPose;
std::function<void(frc::Pose2d)> PathPlannerLogging::m_logTargetPose;
std::function<void(std::vector<frc::Pose2d>&)> PathPlannerLogging::m_logActivePath;
