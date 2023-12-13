// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

#include "subsystems/SwerveSubsystem.h"
#include <frc/smartdashboard/SmartDashboard.h>
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <pathplanner/lib/util/PathPlannerLogging.h>

using namespace pathplanner;

SwerveSubsystem::SwerveSubsystem() : flModule(), frModule(), blModule(), brModule(), odometry(
    kinematics, gyro.getRotation2d(), 
    {flModule.getPosition(), frModule.getPosition(), blModule.getPosition(), brModule.getPosition()},
    frc::Pose2d()), field() {
    // Configure AutoBuilder
    AutoBuilder::configureHolonomic(
        [this]() {return this->getPose();},
        [this](frc::Pose2d pose) {this->resetPose(pose);},
        [this]() {return this->getSpeeds();},
        [this](frc::ChassisSpeeds robotRelativeSpeeds) {this->driveRobotRelative(robotRelativeSpeeds);},
        SwerveConstants::pathFollowerConfig,
        this
    );

    // Set up custom logging to add the current path to a field 2d widget
    PathPlannerLogging::setLogActivePathCallback([this](auto poses) {
        this->field.GetObject("path")->SetPoses(poses);
    });

    frc::SmartDashboard::PutData("Field", &field);
}

// This method will be called once per scheduler run
void SwerveSubsystem::Periodic() {
    // Update the simulated gyro, not needed in a real project
    gyro.updateRotation(getSpeeds().omega);

    odometry.Update(gyro.getRotation2d(), {flModule.getPosition(), frModule.getPosition(), blModule.getPosition(), brModule.getPosition()});

    field.SetRobotPose(getPose());
}

void SwerveSubsystem::setStates(wpi::array<frc::SwerveModuleState, 4> states){
    frc::SwerveDriveKinematics<4>::DesaturateWheelSpeeds(&states, SwerveConstants::maxModuleSpeed);

    flModule.setTargetState(states[0]);
    frModule.setTargetState(states[1]);
    blModule.setTargetState(states[2]);
    brModule.setTargetState(states[3]);
}

void SwerveSubsystem::driveRobotRelative(const frc::ChassisSpeeds& robotRelativeSpeeds){
    frc::ChassisSpeeds targetSpeeds = frc::ChassisSpeeds::Discretize(robotRelativeSpeeds, 0.02_s);

    auto targetStates = kinematics.ToSwerveModuleStates(targetSpeeds);
    setStates(targetStates);
}
