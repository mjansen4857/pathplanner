#include "pathplanner/lib/util/PathPlannerLogging.h"

using namespace pathplanner;

std::function<void(frc::Pose2d)> PathPlannerLogging::m_logCurrentPose;
std::function<void(frc::Translation2d)> PathPlannerLogging::m_logLookahead;
std::function<void(std::vector<frc::Pose2d>&)> PathPlannerLogging::m_logActivePath;
