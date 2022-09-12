#pragma once

#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <units/velocity.h>

namespace pathplanner{
    class PathPoint{
        public:
            frc::Translation2d m_position;
            frc::Rotation2d m_heading;
            frc::Rotation2d m_holonomicRotation;
            units::meters_per_second_t m_velocityOverride;

            PathPoint(frc::Translation2d position, frc::Rotation2d heading, frc::Rotation2d holonomicRotation, units::meters_per_second_t velocityOverride) :
                m_position(position),
                m_heading(heading),
                m_holonomicRotation(holonomicRotation),
                m_velocityOverride(velocityOverride) {}
            
            PathPoint(frc::Translation2d position, frc::Rotation2d heading, frc::Rotation2d holonomicRotation) :
                PathPoint(position, heading, holonomicRotation, -1_mps) {}
            
            PathPoint(frc::Translation2d position, frc::Rotation2d heading, units::meters_per_second_t velocityOverride) :
                PathPoint(position, heading, frc::Rotation2d(), velocityOverride) {}
            
            PathPoint(frc::Translation2d position, frc::Rotation2d heading) :
                PathPoint(position, heading, frc::Rotation2d(), -1_mps) {}
    };
}