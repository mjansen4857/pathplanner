#include "pathplanner/lib/GeometryUtil.h"

using namespace pathplanner;

units::second_t GeometryUtil::unitLerp(units::second_t startVal, units::second_t endVal, double t) {
   return startVal + (endVal - startVal) * t;
}

units::meters_per_second_t GeometryUtil::unitLerp(units::meters_per_second_t startVal, units::meters_per_second_t endVal, double t) {
   return startVal + (endVal - startVal) * t;
}

units::meters_per_second_squared_t GeometryUtil::unitLerp(units::meters_per_second_squared_t startVal, units::meters_per_second_squared_t endVal, double t) {
   return startVal + (endVal - startVal) * t;
}

units::radians_per_second_t GeometryUtil::unitLerp(units::radians_per_second_t startVal, units::radians_per_second_t endVal, double t) {
   return startVal + (endVal - startVal) * t;
}

units::radians_per_second_squared_t GeometryUtil::unitLerp(units::radians_per_second_squared_t startVal, units::radians_per_second_squared_t endVal, double t) {
   return startVal + (endVal - startVal) * t;
}

units::meter_t GeometryUtil::unitLerp(units::meter_t startVal, units::meter_t endVal, double t) {
   return startVal + (endVal - startVal) * t;
}

units::curvature_t GeometryUtil::unitLerp(units::curvature_t startVal, units::curvature_t endVal, double t) {
   return startVal + (endVal - startVal) * t;
}

frc::Rotation2d GeometryUtil::rotationLerp(const frc::Rotation2d startVal, const frc::Rotation2d endVal, double t) {
   return startVal + ((endVal - startVal) * t);
}

frc::Translation2d GeometryUtil::translationLerp(const frc::Translation2d startVal, const frc::Translation2d endVal, double t) {
   return startVal + ((endVal - startVal) * t);
}

frc::Translation2d GeometryUtil::quadraticLerp(const frc::Translation2d a, const frc::Translation2d b, const frc::Translation2d c, double t){
   frc::Translation2d p0 = GeometryUtil::translationLerp(a, b, t);
   frc::Translation2d p1 = GeometryUtil::translationLerp(b, c, t);
   return GeometryUtil::translationLerp(p0, p1, t);
}

frc::Translation2d GeometryUtil::cubicLerp(const frc::Translation2d a, const frc::Translation2d b, const frc::Translation2d c, const frc::Translation2d d, double t){
   frc::Translation2d p0 = GeometryUtil::quadraticLerp(a, b, c, t);
   frc::Translation2d p1 = GeometryUtil::quadraticLerp(b, c, d, t);
   return GeometryUtil::translationLerp(p0, p1, t);
}

units::degree_t GeometryUtil::modulo(units::degree_t a, units::degree_t b){
   return a - (b * units::math::floor(a / b));
}

bool GeometryUtil::isFinite(units::meter_t u){
   return std::isfinite(u());
}

bool GeometryUtil::isNaN(units::meter_t u){
   return std::isnan(u());
}
