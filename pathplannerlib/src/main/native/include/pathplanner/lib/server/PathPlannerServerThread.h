#pragma once

#include <string>
#include <thread>
#include <pthread.h>

namespace pathplanner{
    class PathPlannerServerThread {
        private:
            const int socketFd;
            volatile bool isAlive;
            void (*onMessageReceived)(std::string);

            PathPlannerServerThread(int socket, void (*onMsgReceived)(std::string));

            void sendMessage(std::string message);

            friend class PathPlannerServer;
    };
}