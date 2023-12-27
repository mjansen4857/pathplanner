#pragma once

#include "pathplanner/lib/pathfinding/Pathfinder.h"
#include "pathplanner/lib/path/PathPoint.h"
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <atomic>
#include <thread>
#include <wpi/mutex.h>
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
	std::unordered_set<GridPosition> requestObstacles;

	GridPosition requestStart;
	frc::Translation2d requestRealStartPos;
	GridPosition requestGoal;
	frc::Translation2d requestRealGoalPos;

	double eps;

	std::thread planningThread;
	wpi::mutex pathMutex;
	wpi::mutex requestMutex;

	bool requestMinor;
	bool requestMajor;
	bool requestReset;
	bool newPathAvailable;

	std::vector<PathPoint> currentPathPoints;
	std::vector<GridPosition> currentPathFull;

	void runThread();

	void doWork(const bool needsReset, const bool doMinor, const bool doMajor,
			const GridPosition &sStart, const GridPosition &sGoal,
			const frc::Translation2d &realStartPos,
			const frc::Translation2d &realGoalPos,
			const std::unordered_set<GridPosition> &obstacles);

	GridPosition findClosestNonObstacle(const GridPosition &pos,
			const std::unordered_set<GridPosition> &obstacles);

	std::vector<GridPosition> extractPath(const GridPosition &sStart,
			const GridPosition &sGoal,
			const std::unordered_set<GridPosition> &obstacles);

	std::vector<PathPoint> createPathPoints(
			const std::vector<GridPosition> &path,
			const frc::Translation2d &realStartPos,
			const frc::Translation2d &realGoalPos,
			const std::unordered_set<GridPosition> &obstacles);

	bool walkable(const GridPosition &s1, const GridPosition &s2,
			const std::unordered_set<GridPosition> &obstacles);

	void reset(const GridPosition &sStart, const GridPosition &sGoal);

	void computeOrImprovePath(const GridPosition &sStart,
			const GridPosition &sGoal,
			const std::unordered_set<GridPosition> &obstacles);

	void updateState(const GridPosition &s, const GridPosition &sStart,
			const GridPosition &sGoal,
			const std::unordered_set<GridPosition> &obstacles);

	inline double cost(const GridPosition &sStart, const GridPosition &sGoal,
			const std::unordered_set<GridPosition> &obstacles) {
		if (isCollision(sStart, sGoal, obstacles)) {
			return std::numeric_limits<double>::infinity();
		}
		return heuristic(sStart, sGoal);
	}

	bool isCollision(const GridPosition &sStart, const GridPosition &sEnd,
			const std::unordered_set<GridPosition> &obstacles);

	std::unordered_set<GridPosition> getOpenNeighbors(const GridPosition &s,
			const std::unordered_set<GridPosition> &obstacles);

	std::unordered_set<GridPosition> getAllNeighbors(const GridPosition &s);

	std::pair<double, double> key(const GridPosition &s,
			const GridPosition &sStart);

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
