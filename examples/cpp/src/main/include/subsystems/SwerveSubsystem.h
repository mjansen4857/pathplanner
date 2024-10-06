// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

#pragma once

#include <frc2/command/SubsystemBase.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/kinematics/SwerveModulePosition.h>
#include <frc/kinematics/SwerveModuleState.h>
#include <frc/kinematics/SwerveDriveOdometry.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/smartdashboard/Field2d.h>
#include <units/time.h>
#include <units/angular_velocity.h>
#include <optional>
#include <pathplanner/lib/config/RobotConfig.h>
#include "Constants.h"

class SwerveSubsystem : public frc2::SubsystemBase {
  public:
    SwerveSubsystem();

    /**
     * Will be called periodically whenever the CommandScheduler runs.
     */
    void Periodic() override;

    inline const frc::Pose2d& getPose() const {
      return odometry.GetPose();
    }

    inline void resetPose(const frc::Pose2d& pose) {
      odometry.ResetPosition(gyro.getRotation2d(), {flModule.getPosition(), frModule.getPosition(), blModule.getPosition(), brModule.getPosition()}, pose);
    }

    inline frc::ChassisSpeeds getSpeeds() {
      return kinematics.ToChassisSpeeds({flModule.getState(), frModule.getState(), blModule.getState(), brModule.getState()});
    }

    void setStates(wpi::array<frc::SwerveModuleState, 4> states);

    void driveRobotRelative(const frc::ChassisSpeeds& robotRelativeSpeeds);

    inline void driveFieldRelative(const frc::ChassisSpeeds& fieldRelativeSpeeds) {
      driveRobotRelative(frc::ChassisSpeeds::FromFieldRelativeSpeeds(fieldRelativeSpeeds, getPose().Rotation()));
    }

  private:
    /**
     * Basic simulation of a swerve module, will just hold its current state and not use any hardware
     */
    class SimSwerveModule{
      public:
        constexpr SimSwerveModule() : currentPosition(), currentState() {}

        constexpr const frc::SwerveModulePosition& getPosition() {
          return currentPosition;
        }

        constexpr const frc::SwerveModuleState& getState() {
          return currentState;
        }

        inline void setTargetState(const frc::SwerveModuleState& targetState) {
          currentState = frc::SwerveModuleState::Optimize(targetState, currentState.angle);
          currentPosition = frc::SwerveModulePosition{currentPosition.distance + (currentState.speed * 0.02_s), currentState.angle};
        }

      private:
        frc::SwerveModulePosition currentPosition;
        frc::SwerveModuleState currentState;
    };

    /**
     * Basic simulation of a gyro, will just hold its current state and not use any hardware
     */
    class SimGyro {
      public:
        constexpr SimGyro() : currentRotation() {}

        constexpr const frc::Rotation2d& getRotation2d() {
          return currentRotation;
        }

        constexpr void updateRotation(units::radians_per_second_t angularVel) {
          currentRotation = currentRotation + frc::Rotation2d(angularVel * 0.02_s);
        }
      
      private:
        frc::Rotation2d currentRotation;
    };

    frc::SwerveDriveKinematics<4> kinematics{
      SwerveConstants::flOffset,
      SwerveConstants::frOffset,
      SwerveConstants::blOffset,
      SwerveConstants::brOffset
    };

    SimSwerveModule flModule;
    SimSwerveModule frModule;
    SimSwerveModule blModule;
    SimSwerveModule brModule;

    SimGyro gyro;

    frc::SwerveDriveOdometry<4> odometry;

    frc::Field2d field;

    std::optional<pathplanner::RobotConfig> robotConfig;
};
