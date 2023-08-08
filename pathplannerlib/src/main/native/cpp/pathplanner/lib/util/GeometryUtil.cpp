#include "pathplanner/lib/util/GeometryUtil.h"
#include <iostream>

using namespace pathplanner;

units::meter_t GeometryUtil::calculateRadius(const frc::Translation2d a,
		const frc::Translation2d b, const frc::Translation2d c) {
	frc::Translation2d vba = a - b;
	frc::Translation2d vbc = c - b;
	double cross_z = (vba.X()() * vbc.Y()()) - (vba.Y()() * vbc.X()());
	int sign = (cross_z < 0) ? 1 : -1;

	double ab = a.Distance(b)();
	double bc = b.Distance(c)();
	double ac = a.Distance(c)();

	double p = (ab + bc + ac) / 2;
	double area = std::sqrt(std::abs(p * (p - ab) * (p - bc) * (p - ac)));
	double radius = sign * (ab * bc * ac) / (4 * area);
	return units::meter_t { radius };
}
