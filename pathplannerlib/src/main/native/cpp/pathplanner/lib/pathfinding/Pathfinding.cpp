#include "pathplanner/lib/pathfinding/Pathfinding.h"
#include "pathplanner/lib/pathfinding/Pathfinder.h"
#include "pathplanner/lib/pathfinding/LocalADStar.h"

using namespace pathplanner;

std::unique_ptr<Pathfinder> Pathfinding::pathfinder;

void Pathfinding::ensureInitialized() {
	if (!pathfinder) {
		pathfinder = std::make_unique<LocalADStar>();
	}
}
