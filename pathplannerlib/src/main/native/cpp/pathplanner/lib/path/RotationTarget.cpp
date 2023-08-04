#include "pathplanner/lib/path/RotationTarget.h"
#include <units/angle.h>

using namespace pathplanner;

RotationTarget RotationTarget::fromJson(const wpi::json &json) {
	double pos = static_cast<double>(json.at("waypointRelativePos"));
	auto targetDeg = units::degree_t { static_cast<double>(json.at(
			"rotationDegrees")) };

	return RotationTarget(pos, frc::Rotation2d(targetDeg));
}

bool RotationTarget::operator==(const RotationTarget &other) const {
	return std::abs(m_position - other.m_position) < 1E-9
			&& m_target == other.m_target;
}
