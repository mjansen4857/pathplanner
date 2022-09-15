#pragma once

#include <string>
#include <frc/geometry/Pose2d.h>
#include "pathplanner/lib/PathPlannerTrajectory.h"

namespace pathplanner{
    class PathPlannerServer{
        public:
            static void startServer(int serverPort);
            static void sendActivePath(std::vector<PathPlannerTrajectory::PathPlannerState> states);
            static void sendPathFollowingData(frc::Pose2d targetPose, frc::Pose2d actualPose);

        private:
            static void sendToClients(std::string message);
            static void handleMessage(std::string message);

            static volatile bool isRunning;
            static std::vector<> clients;
    };
}