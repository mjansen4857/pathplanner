#include "pathplanner/lib/util/FlippingUtil.h"

using namespace pathplanner;

FlippingUtil::FieldSymmetry FlippingUtil::symmetryType =
		FlippingUtil::FieldSymmetry::kMirrored;
units::meter_t FlippingUtil::fieldSizeX = 16.54175_m;
units::meter_t FlippingUtil::fieldSizeY = 8.211_m;
