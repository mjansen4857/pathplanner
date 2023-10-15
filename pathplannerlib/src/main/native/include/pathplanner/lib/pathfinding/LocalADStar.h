#pragma once

#include "pathplanner/lib/pathfinding/Pathfinder.h"
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <atomic>
#include <thread>
#include <mutex>
#include <frc/geometry/Translation2d.h>
#include <optional>

namespace pathplanner {
class GridPosition {
public:
	int x;
	int y;

	constexpr GridPosition() : x(0), y(0) {
	}

	constexpr GridPosition(const int xPos, const int yPos) : x(xPos), y(yPos) {
	}

	constexpr bool operator==(const GridPosition &other) const {
		return x == other.x && y == other.y;
	}
};
}

namespace std {
template<>
struct hash<pathplanner::GridPosition> {
	size_t operator()(const pathplanner::GridPosition &gridPos) const {
		return ((hash<int>()(gridPos.x) ^ ((hash<int>()(gridPos.y) << 1) >> 1)));
	}
};
}

namespace pathplanner {
class LocalADStar: public Pathfinder {
public:
	LocalADStar();

	~LocalADStar() {
	}

	inline bool isNewPathAvailable() override {
		return newPathAvailable;
	}

	std::shared_ptr<PathPlannerPath> getCurrentPath(PathConstraints constraints,
			GoalEndState goalEndState) override;

	void setStartPosition(const frc::Translation2d &start) override;

	void setGoalPosition(const frc::Translation2d &goal) override;

	void setDynamicObstacles(
			const std::vector<std::pair<frc::Translation2d, frc::Translation2d>> &obs,
			const frc::Translation2d &currentRobotPos) override;

	inline GridPosition getGridPos(const frc::Translation2d &pos) {
		return GridPosition(static_cast<int>(std::floor(pos.X()() / nodeSize)),
				static_cast<int>(std::floor(pos.Y()() / nodeSize)));
	}

private:
	const double SMOOTHING_ANCHOR_PCT = 0.8;
	const double SMOOTHING_CONTROL_PCT = 0.33;
	const double EPS = 2.5;

	double fieldLength;
	double fieldWidth;

	double nodeSize;

	int nodesX;
	int nodesY;

	std::unordered_map<GridPosition, double> g;
	std::unordered_map<GridPosition, double> rhs;
	std::unordered_map<GridPosition, std::pair<double, double>> open;
	std::unordered_map<GridPosition, std::pair<double, double>> incons;
	std::unordered_set<GridPosition> closed;
	std::unordered_set<GridPosition> staticObstacles;
	std::unordered_set<GridPosition> dynamicObstacles;
	std::unordered_set<GridPosition> obstacles;

	GridPosition sStart;
	frc::Translation2d realStartPos;
	GridPosition sGoal;
	frc::Translation2d realGoalPos;

	double eps;

	std::thread planningThread;
	std::mutex mutex;

	bool doMinor;
	bool doMajor;
	bool needsReset;
	bool needsExtract;
	bool newPathAvailable;

	std::vector<frc::Translation2d> currentPath;

	void runThread();

	void doWork();

	GridPosition findClosestNonObstacle(const GridPosition &pos);

	std::vector<frc::Translation2d> extractPath();

	bool walkable(const GridPosition &s1, const GridPosition &s2);

	void reset();

	void computeOrImprovePath();

	void updateState(const GridPosition &s);

	inline double cost(const GridPosition &sStart, const GridPosition &sGoal) {
		if (isCollision(sStart, sGoal)) {
			return std::numeric_limits<double>::infinity();
		}
		return heuristic(sStart, sGoal);
	}

	bool isCollision(const GridPosition &sStart, const GridPosition &sEnd);

	std::unordered_set<GridPosition> getOpenNeighbors(const GridPosition &s);

	std::unordered_set<GridPosition> getAllNeighbors(const GridPosition &s);

	std::pair<double, double> key(const GridPosition &s);

	std::optional<std::pair<GridPosition, std::pair<double, double>>> topKey();

	inline double heuristic(const GridPosition &sStart,
			const GridPosition &sGoal) {
		return std::hypot(sGoal.x - sStart.x, sGoal.y - sStart.y);
	}

	constexpr int comparePair(const std::pair<double, double> &a,
			const std::pair<double, double> &b) {
		int first = compareDouble(a.first, b.first);
		if (first == 0) {
			return compareDouble(a.second, b.second);
		} else {
			return first;
		}
	}

	constexpr int compareDouble(const double a, const double b) {
		if (a < b) {
			return -1;
		} else if (a > b) {
			return 1;
		}
		return 0;
	}

	inline frc::Translation2d gridPosToTranslation2d(const GridPosition &pos) {
		return frc::Translation2d(
				units::meter_t { (pos.x * nodeSize) + (nodeSize / 2.0) },
				units::meter_t { (pos.y * nodeSize) + (nodeSize / 2.0) });
	}
};
}
