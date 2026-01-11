#include "pathplanner/lib/util/FlippingUtil.h"

using namespace pathplanner;

FlippingUtil::FieldSymmetry FlippingUtil::symmetryType =
		FlippingUtil::FieldSymmetry::kRotational;
units::meter_t FlippingUtil::fieldSizeX = 16.54_m;
units::meter_t FlippingUtil::fieldSizeY = 8.07_m;
