#include "pathplanner/lib/path/RotationTarget.h"
#include <units/angle.h>

using namespace pathplanner;

RotationTarget RotationTarget::fromJson(const wpi::json &json) {
	double pos = json.at("waypointRelativePos").get<double>();
	auto targetDeg = units::degree_t(json.at("rotationDegrees").get<double>());
	bool rotateFast = false;

	if (json.contains("rotateFast")) {
		rotateFast = json.at("rotateFast").get<bool>();
	}

	return RotationTarget(pos, frc::Rotation2d(targetDeg), rotateFast);
}
