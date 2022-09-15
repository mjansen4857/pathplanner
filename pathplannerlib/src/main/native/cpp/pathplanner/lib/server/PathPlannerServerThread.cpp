#include "pathplanner/lib/server/PathPlannerServerThread.h"

#include <sys/socket.h>

using namespace pathplanner;

PathPlannerServerThread::PathPlannerServerThread(int socket, void (*onMsgReceived)(std::string)) :
                socketFd(socket),
                isAlive(true),
                onMessageReceived(onMsgReceived) {}

void PathPlannerServerThread::sendMessage(std::string message) {
    if(message.back() != '\n'){
        message += "\n";
    }
    send(socketFd, message.c_str(), message.length(), 0);
}