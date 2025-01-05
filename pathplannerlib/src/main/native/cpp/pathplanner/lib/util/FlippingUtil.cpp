#include "pathplanner/lib/util/FlippingUtil.h"

using namespace pathplanner;

FlippingUtil::FieldSymmetry FlippingUtil::symmetryType =
		FlippingUtil::FieldSymmetry::kRotational;
units::meter_t FlippingUtil::fieldSizeX = 57.573_ft;
units::meter_t FlippingUtil::fieldSizeY = 26.417_ft;
