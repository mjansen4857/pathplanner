// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

#include "subsystems/SwerveSubsystem.h"
#include <frc/smartdashboard/SmartDashboard.h>
#include <pathplanner/lib/auto/AutoBuilder.h>
#include <pathplanner/lib/util/PathPlannerLogging.h>
#include <pathplanner/lib/controllers/PPHolonomicDriveController.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

SwerveSubsystem::SwerveSubsystem() : flModule(), frModule(), blModule(), brModule(), odometry(
    kinematics, gyro.getRotation2d(), 
    {flModule.getPosition(), frModule.getPosition(), blModule.getPosition(), brModule.getPosition()},
    frc::Pose2d()), field() {
    robotConfig = RobotConfig::fromGUISettings();

    // Configure AutoBuilder
    AutoBuilder::configure(
        [this]() {return this->getPose();},
        [this](const frc::Pose2d& pose) {this->resetPose(pose);},
        [this]() {return this->getSpeeds();},
        [this](const frc::ChassisSpeeds& robotRelativeSpeeds) {this->driveRobotRelative(robotRelativeSpeeds);},
        std::make_shared<PPHolonomicDriveController>(
            SwerveConstants::translationConstants,
            SwerveConstants::rotationConstants
        ),
        robotConfig.value(),
        []() {
            // Boolean supplier that controls when the path will be mirrored for the red alliance
            // This will flip the path being followed to the red side of the field.
            // THE ORIGIN WILL REMAIN ON THE BLUE SIDE

            auto alliance = frc::DriverStation::GetAlliance();
            if (alliance) {
                return alliance.value() == frc::DriverStation::Alliance::kRed;
            }
            return false;
        },
        this
    );

    // Set up custom logging to add the current path to a field 2d widget
    PathPlannerLogging::setLogActivePathCallback([this](const auto& poses) {
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
    frc::SwerveDriveKinematics<4>::DesaturateWheelSpeeds(&states, robotConfig.value().moduleConfig.maxDriveVelocityMPS);

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
