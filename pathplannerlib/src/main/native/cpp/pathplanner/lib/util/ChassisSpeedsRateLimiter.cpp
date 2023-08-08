#include "pathplanner/lib/util/ChassisSpeedsRateLimiter.h"
#include <wpimath/MathShared.h>
#include <algorithm>

using namespace pathplanner;

void ChassisSpeedsRateLimiter::reset(frc::ChassisSpeeds value) {
	m_prevVal = value;
	m_prevTime = wpi::math::MathSharedStore::GetTimestamp();
}

frc::ChassisSpeeds ChassisSpeedsRateLimiter::calculate(
		const frc::ChassisSpeeds &input) {
	units::second_t currentTime = wpi::math::MathSharedStore::GetTimestamp();
	units::second_t elapsedTime = currentTime - m_prevTime;

	m_prevVal.omega += std::clamp(input.omega - m_prevVal.omega,
			-m_rotationRateLimit * elapsedTime,
			m_rotationRateLimit * elapsedTime);

	Vector2 prevVelVec = Vector2(m_prevVal.vx, m_prevVal.vy);
	Vector2 targetVelVec = Vector2(input.vx, input.vy);
	Vector2 deltaVelVec = targetVelVec - prevVelVec;
	units::meters_per_second_t maxDelta = m_translationRateLimit * elapsedTime;

	units::meters_per_second_t norm = deltaVelVec.norm();
	if (norm > maxDelta) {
		Vector2 deltaUnitVec = deltaVelVec / norm();
		Vector2 limitedDelta = deltaUnitVec * maxDelta();
		Vector2 nextVelVec = prevVelVec + limitedDelta;

		m_prevVal.vx = nextVelVec.x;
		m_prevVal.vy = nextVelVec.y;
	} else {
		m_prevVal.vx = targetVelVec.x;
		m_prevVal.vy = targetVelVec.y;
	}

	m_prevTime = currentTime;
	return m_prevVal;
}
