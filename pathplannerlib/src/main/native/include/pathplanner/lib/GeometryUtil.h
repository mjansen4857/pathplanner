#pragma once

#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Translation2d.h>
#include <units/time.h>
#include <units/velocity.h>
#include <units/acceleration.h>
#include <units/length.h>
#include <units/angle.h>
#include <units/angular_velocity.h>
#include <units/angular_acceleration.h>
#include <units/math.h>
#include <units/curvature.h>

namespace pathplanner {
    class GeometryUtil {
    public:
        static units::second_t unitLerp(units::second_t startVal, units::second_t endVal, double t);
        static units::meters_per_second_t unitLerp(units::meters_per_second_t startVal, units::meters_per_second_t endVal, double t);
        static units::meters_per_second_squared_t unitLerp(units::meters_per_second_squared_t startVal, units::meters_per_second_squared_t endVal, double t);
        static units::radians_per_second_t unitLerp(units::radians_per_second_t startVal, units::radians_per_second_t endVal, double t);
        static units::radians_per_second_squared_t unitLerp(units::radians_per_second_squared_t startVal, units::radians_per_second_squared_t endVal, double t);
        static units::meter_t unitLerp(units::meter_t startVal, units::meter_t endVal, double t);
        static units::curvature_t unitLerp(units::curvature_t startVal, units::curvature_t endVal, double t);

        static frc::Rotation2d rotationLerp(const frc::Rotation2d startVal, const frc::Rotation2d endVal, double t);
        static frc::Translation2d translationLerp(const frc::Translation2d startVal, const frc::Translation2d endVal, double t);
        static frc::Translation2d quadraticLerp(const frc::Translation2d a, const frc::Translation2d b, const frc::Translation2d c, double t);
        static frc::Translation2d cubicLerp(const frc::Translation2d a, const frc::Translation2d b, const frc::Translation2d c, const frc::Translation2d d, double t);

        static units::degree_t modulo(units::degree_t a, units::degree_t b);

        static bool isFinite(units::meter_t u);
        static bool isNaN(units::meter_t u);
    };
} // namespace pathplanner