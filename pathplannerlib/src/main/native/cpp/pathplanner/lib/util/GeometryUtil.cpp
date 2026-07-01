#include "pathplanner/lib/util/GeometryUtil.h"
#include <iostream>

using namespace pathplanner;

wpi::units::meter_t GeometryUtil::calculateRadius(
		const wpi::math::Translation2d a, const wpi::math::Translation2d b,
		const wpi::math::Translation2d c) {
	wpi::math::Translation2d vba = a - b;
	wpi::math::Translation2d vbc = c - b;
	double cross_z = (vba.X()() * vbc.Y()()) - (vba.Y()() * vbc.X()());
	int sign = (cross_z < 0) ? 1 : -1;

	double ab = a.Distance(b)();
	double bc = b.Distance(c)();
	double ac = a.Distance(c)();

	double p = (ab + bc + ac) / 2;
	double area = std::sqrt(std::abs(p * (p - ab) * (p - bc) * (p - ac)));
	double radius = sign * (ab * bc * ac) / (4 * area);
	return wpi::units::meter_t { radius };
}
