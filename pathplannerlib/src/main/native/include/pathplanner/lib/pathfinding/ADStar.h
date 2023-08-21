#pragma once

#include <unordered_map>
#include <vector>
#include <atomic>
#include <thread>
#include <mutex>
#include <frc/geometry/Translation2d.h>
#include <optional>
#include "pathplanner/lib/path/PathPoint.h"

namespace pathplanner {
class ADStar {
public:
	static void ensureInitialized();

	static inline bool isNewPathAvailable() {
		return newPathAvailable;
	}

	static std::vector<PathPoint> getCurrentPath();

	class GridPosition {
	public:
		int x;
		int y;

		constexpr GridPosition(const int xPos, const int yPos) : x(xPos), y(
				yPos) {
		}

		constexpr bool operator==(const GridPosition &other) const {
			return x == other.x && y == other.y;
		}
	};

private:
	static const double SMOOTHING_ANCHOR_PCT;
	static const double SMOOTHING_CONTROL_PCT;

	static double FIELD_LENGTH;
	static double FIELD_WIDTH;

	static double NODE_SIZE;

	static int NODE_X;
	static int NODE_Y;

	static const double EPS;

	static std::unordered_map<GridPosition, double> g;
	static std::unordered_map<GridPosition, double> rhs;
	static std::unordered_map<GridPosition, std::pair<double, double>> open;
	static std::unordered_map<GridPosition, std::pair<double, double>> incons;
	static std::vector<GridPosition> closed;
	static std::vector<GridPosition> staticObstacles;
	static std::vector<GridPosition> dynamicObstacles;
	static std::vector<GridPosition> obstacles;

	static std::atomic<GridPosition> sStart;
	static std::atomic<GridPosition> sGoal;

	static std::atomic<double> eps;

	static std::thread planningThread;
	static std::mutex mutex;

	static std::atomic_bool doMinor;
	static std::atomic_bool doMajor;
	static std::atomic_bool needsReset;
	static std::atomic_bool needsExtract;
	static std::atomic_bool running;
	static std::atomic_bool newPathAvailable;

	static std::vector<PathPoint> currentPath;
	static std::mutex currentPath_mutex;

	static void runThread();

	static void doWork();

	static std::vector<PathPoint> extractPath();

    // TODO: isCollision ^

	static std::vector<GridPosition> getOpenNeighbors(const GridPosition &s);

	static std::vector<GridPosition> getAllNeighbors(const GridPosition &s);

	static std::pair<double, double> key(const GridPosition &s);

	static std::optional<std::pair<GridPosition, std::pair<double, double>>> topKey();

	static inline double heuristic(const GridPosition &sStart,
			const GridPosition &sGoal) {
		return std::hypot(sGoal.x - sStart.x, sGoal.y - sStart.y);
	}

	static constexpr int comparePair(const std::pair<double, double> &a,
			const std::pair<double, double> &b) {
		int first = compareDouble(a.first, b.first);
		if (first == 0) {
			return compareDouble(a.second, b.second);
		} else {
			return first;
		}
	}

	static constexpr int compareDouble(const double a, const double b) {
		if (a < b) {
			return -1;
		} else if (a > b) {
			return 1;
		}
		return 0;
	}

	static inline GridPosition getGridPos(const frc::Translation2d &pos) {
		return GridPosition(static_cast<int>(std::floor(pos.X()() / NODE_SIZE)),
				static_cast<int>(std::floor(pos.Y()() / NODE_SIZE)));
	}

	static inline frc::Translation2d gridPosToTranslation2d(
			const GridPosition &pos) {
		return frc::Translation2d(units::meter_t { pos.x * NODE_SIZE },
				units::meter_t { pos.y * NODE_SIZE });
	}
};
}

namespace std {
template<>
struct hash<pathplanner::ADStar::GridPosition> {
	size_t operator()(const pathplanner::ADStar::GridPosition &gridPos) const {
		return ((hash<int>()(gridPos.x) ^ ((hash<int>()(gridPos.y) << 1) >> 1)));
	}
};
}
