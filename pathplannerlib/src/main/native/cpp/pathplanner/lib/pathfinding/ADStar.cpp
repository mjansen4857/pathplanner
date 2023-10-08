#include "pathplanner/lib/pathfinding/ADStar.h"
#include <cmath>
#include <frc/Filesystem.h>
#include <wpi/raw_istream.h>
#include <wpi/json.h>
#include <chrono>
#include <frc/Errors.h>
#include <queue>

using namespace pathplanner;

const double ADStar::SMOOTHING_ANCHOR_PCT = 0.8;
const double ADStar::SMOOTHING_CONTROL_PCT = 0.33;

double ADStar::FIELD_LENGTH = 16.54;
double ADStar::FIELD_WIDTH = 8.02;

double ADStar::NODE_SIZE = 0.2;

int ADStar::NODE_X = static_cast<int>(std::ceil(
		ADStar::FIELD_LENGTH / ADStar::NODE_SIZE));
int ADStar::NODE_Y = static_cast<int>(std::ceil(
		ADStar::FIELD_WIDTH / ADStar::NODE_SIZE));

const double ADStar::EPS = 2.5;

std::unordered_map<ADStar::GridPosition, double> ADStar::g;
std::unordered_map<ADStar::GridPosition, double> ADStar::rhs;
std::unordered_map<ADStar::GridPosition, std::pair<double, double>> ADStar::open;
std::unordered_map<ADStar::GridPosition, std::pair<double, double>> ADStar::incons;
std::unordered_set<ADStar::GridPosition> ADStar::closed;
std::unordered_set<ADStar::GridPosition> ADStar::staticObstacles;
std::unordered_set<ADStar::GridPosition> ADStar::dynamicObstacles;
std::unordered_set<ADStar::GridPosition> ADStar::obstacles;

ADStar::GridPosition ADStar::sStart;
frc::Translation2d ADStar::realStartPos;
ADStar::GridPosition ADStar::sGoal;
frc::Translation2d ADStar::realGoalPos;

double ADStar::eps = ADStar::EPS;

std::thread ADStar::planningThread;
std::mutex ADStar::mutex;

bool ADStar::doMinor = true;
bool ADStar::doMajor = true;
bool ADStar::needsReset = true;
bool ADStar::needsExtract = false;
bool ADStar::running = false;
bool ADStar::newPathAvailable = false;

std::vector<frc::Translation2d> ADStar::currentPath;
void ADStar::ensureInitialized() {
	if (!running) {
		running = true;
		sStart = GridPosition(0, 0);
		realStartPos = frc::Translation2d(0_m, 0_m);
		sGoal = GridPosition(0, 0);
		realGoalPos = frc::Translation2d(0_m, 0_m);

		staticObstacles.clear();
		dynamicObstacles.clear();

		const std::string filePath = frc::filesystem::GetDeployDirectory()
				+ "/pathplanner/navgrid.json";

		std::error_code error_code;
		wpi::raw_fd_istream input { filePath, error_code };

		if (!error_code) {
			try {
				wpi::json json;
				input >> json;

				NODE_SIZE = json.at("nodeSizeMeters").get<double>();
				wpi::json::const_reference grid = json.at("grid");
				NODE_Y = grid.size();
				for (size_t row = 0; row < grid.size(); row++) {
					wpi::json::const_reference rowArr = grid[row];
					if (row == 0) {
						NODE_X = rowArr.size();
					}
					for (size_t col = 0; col < rowArr.size(); col++) {
						bool isObstacle = rowArr[col].get<bool>();
						if (isObstacle) {
							staticObstacles.emplace(col, row);
						}
					}
				}

				wpi::json::const_reference fieldSize = json.at("field_size");
				FIELD_LENGTH = fieldSize.at("x").get<double>();
				FIELD_WIDTH = fieldSize.at("y").get<double>();
			} catch (...) {
				// Ignore, just use defaults
			}
		}

		obstacles.clear();
		obstacles.insert(staticObstacles.begin(), staticObstacles.end());
		obstacles.insert(dynamicObstacles.begin(), dynamicObstacles.end());

		needsReset = true;
		doMajor = true;
		doMinor = true;

		newPathAvailable = false;

		planningThread = std::thread(ADStar::runThread);
		planningThread.detach();
	}
}

void ADStar::runThread() {
	while (running) {
		try {
			std::lock_guard < std::mutex > lock(mutex);

			if (needsReset || doMinor || doMajor) {
				doWork();
			} else if (needsExtract) {
				currentPath = extractPath();
				newPathAvailable = true;
				needsExtract = false;
			}
		} catch (...) {
			// Ignore
		}

		if (!needsReset && !doMinor && !doMajor) {
			std::this_thread::sleep_for(std::chrono::milliseconds(20));
		}
	}
}

void ADStar::doWork() {
	if (needsReset) {
		reset();
		needsReset = false;
	}

	if (doMinor) {
		computeOrImprovePath();
		currentPath = extractPath();
		newPathAvailable = true;
		doMinor = false;
	} else if (doMajor) {
		if (eps > 1.0) {
			eps -= 0.5;
			open.insert(incons.begin(), incons.end());

			for (auto entry : open) {
				open[entry.first] = key(entry.first);
			}
			closed.clear();
			computeOrImprovePath();
			currentPath = extractPath();
			newPathAvailable = true;
		}

		if (eps <= 1.0) {
			doMajor = false;
		}
	}
}

std::vector<frc::Translation2d> ADStar::getCurrentPath() {
	if (!running) {
		FRC_ReportError(frc::warn::Warning,
				"ADStar path was retrieved before it was initialized");
	}

	newPathAvailable = false;
	return currentPath;
}

void ADStar::setStartPos(const frc::Translation2d &start) {
	std::lock_guard < std::mutex > lock(mutex);

	GridPosition startPos = findClosestNonObstacle(getGridPos(start));

	if (startPos != sStart) {
		sStart = startPos;
		realStartPos = start;

		doMinor = true;
	}
}

void ADStar::setGoalPos(const frc::Translation2d &goal) {
	std::lock_guard < std::mutex > lock(mutex);

	GridPosition gridPos = findClosestNonObstacle(getGridPos(goal));

	if (gridPos != sGoal) {
		sGoal = gridPos;
		realGoalPos = goal;

		doMinor = true;
		doMajor = true;
		needsReset = true;
	}
}

ADStar::GridPosition ADStar::findClosestNonObstacle(const GridPosition &pos) {
	if (!obstacles.contains(pos)) {
		return pos;
	}

	std::unordered_set < GridPosition > visited;
	std::queue < GridPosition > queue;
	for (const GridPosition &gp : getAllNeighbors(pos)) {
		queue.push(gp);
	}

	while (!queue.empty()) {
		GridPosition check = queue.front();
		if (!obstacles.contains(check)) {
			return check;
		}
		visited.emplace(check);

		for (const GridPosition &neighbor : getAllNeighbors(check)) {
			if (!visited.contains(neighbor)) {
				queue.push(neighbor);
			}
		}

		queue.pop();
	}

	// Somehow didn't find one, return the original position cuz everything would be messed up anyways
	return pos;
}

void ADStar::setDynamicObstacles(
		const std::vector<std::pair<frc::Translation2d, frc::Translation2d>> &obs,
		const frc::Translation2d &currentRobotPos) {
	std::unordered_set < GridPosition > newObs;

	for (auto obstacle : obs) {
		GridPosition gridPos1 = getGridPos(obstacle.first);
		GridPosition gridPos2 = getGridPos(obstacle.second);

		int minX = std::min(gridPos1.x, gridPos2.x);
		int maxX = std::max(gridPos1.x, gridPos2.x);

		int minY = std::min(gridPos1.y, gridPos2.y);
		int maxY = std::max(gridPos1.y, gridPos2.y);

		for (int x = minX; x <= maxX; x++) {
			for (int y = minY; y <= maxY; y++) {
				newObs.emplace(x, y);
			}
		}
	}

	std::lock_guard < std::mutex > lock(mutex);

	dynamicObstacles.clear();
	dynamicObstacles.insert(newObs.begin(), newObs.end());
	obstacles.clear();
	obstacles.insert(staticObstacles.begin(), staticObstacles.end());
	obstacles.insert(dynamicObstacles.begin(), dynamicObstacles.end());
	needsReset = true;
	doMinor = true;
	doMajor = true;

	if (dynamicObstacles.contains(getGridPos(currentRobotPos))) {
		// Set the start position to the closest non-obstacle
		setStartPos(currentRobotPos);
	}
}

std::vector<frc::Translation2d> ADStar::extractPath() {
	if (sGoal == sStart) {
		return std::vector<frc::Translation2d> { realGoalPos };
	}

	std::vector < GridPosition > path;
	path.push_back(sStart);

	GridPosition s = sStart;

	for (int k = 0; k < 200; k++) {
		std::unordered_map<GridPosition, double> gList;

		for (const GridPosition &x : getOpenNeighbors(s)) {
			gList[x] = g.at(x);
		}

		auto min = std::pair<GridPosition, double>(sGoal,
				std::numeric_limits<double>::infinity());
		for (auto entry : gList) {
			if (entry.second < min.second) {
				min = entry;
			}
		}
		s = min.first;

		path.push_back(s);
		if (s == sGoal) {
			break;
		}
	}

	std::vector < GridPosition > simplifiedPath;
	simplifiedPath.push_back(path[0]);
	for (size_t i = 1; i < path.size() - 1; i++) {
		if (!walkable(simplifiedPath[simplifiedPath.size() - 1], path[i + 1])) {
			simplifiedPath.push_back(path[i]);
		}
	}
	simplifiedPath.push_back(path[path.size() - 1]);

	std::vector < frc::Translation2d > fieldPosPath;
	for (const GridPosition &pos : simplifiedPath) {
		fieldPosPath.push_back(gridPosToTranslation2d(pos));
	}

	// Replace start and end positions with their real positions
	fieldPosPath[0] = realStartPos;
	fieldPosPath[fieldPosPath.size() - 1] = realGoalPos;

	std::vector < frc::Translation2d > bezierPoints;
	bezierPoints.push_back(fieldPosPath[0]);
	bezierPoints.push_back(
			((fieldPosPath[1] - fieldPosPath[0]) * SMOOTHING_CONTROL_PCT)
					+ fieldPosPath[0]);
	for (size_t i = 1; i < fieldPosPath.size() - 1; i++) {
		frc::Translation2d last = fieldPosPath[i - 1];
		frc::Translation2d current = fieldPosPath[i];
		frc::Translation2d next = fieldPosPath[i + 1];

		frc::Translation2d anchor1 = ((current - last) * SMOOTHING_ANCHOR_PCT)
				+ last;
		frc::Translation2d anchor2 = ((current - next) * SMOOTHING_ANCHOR_PCT)
				+ next;

		units::meter_t controlDist = anchor1.Distance(anchor2)
				* SMOOTHING_CONTROL_PCT;

		frc::Translation2d prevControl1 = ((last - anchor1)
				* SMOOTHING_CONTROL_PCT) + anchor1;
		frc::Translation2d nextControl1 = frc::Translation2d(controlDist,
				(anchor1 - prevControl1).Angle()) + anchor1;

		frc::Translation2d prevControl2 = frc::Translation2d(controlDist,
				(anchor2 - next).Angle()) + anchor2;
		frc::Translation2d nextControl2 = ((next - anchor2)
				* SMOOTHING_CONTROL_PCT) + anchor2;

		bezierPoints.push_back(prevControl1);
		bezierPoints.push_back(anchor1);
		bezierPoints.push_back(nextControl1);

		bezierPoints.push_back(prevControl2);
		bezierPoints.push_back(anchor2);
		bezierPoints.push_back(nextControl2);
	}
	bezierPoints.push_back(
			((fieldPosPath[fieldPosPath.size() - 2]
					- fieldPosPath[fieldPosPath.size() - 1])
					* SMOOTHING_CONTROL_PCT)
					+ fieldPosPath[fieldPosPath.size() - 1]);
	bezierPoints.push_back(fieldPosPath[fieldPosPath.size() - 1]);

	return bezierPoints;
}

bool ADStar::walkable(const ADStar::GridPosition &s1,
		const ADStar::GridPosition &s2) {
	int x0 = s1.x;
	int y0 = s1.y;
	int x1 = s2.x;
	int y1 = s2.y;

	int dx = std::abs(x1 - x0);
	int dy = std::abs(y1 - y0);
	int x = x0;
	int y = y0;
	int n = 1 + dx + dy;
	int xInc = (x1 > x0) ? 1 : -1;
	int yInc = (y1 > y0) ? 1 : -1;
	int error = dx - dy;
	dx *= 2;
	dy *= 2;

	for (; n > 0; n--) {
		if (obstacles.contains(GridPosition(x, y))) {
			return false;
		}

		if (error > 0) {
			x += xInc;
			error -= dy;
		} else if (error < 0) {
			y += yInc;
			error += dx;
		} else {
			x += xInc;
			y += yInc;
			error -= dy;
			error += dx;
			n--;
		}
	}

	return true;
}

void ADStar::reset() {
	g.clear();
	rhs.clear();
	open.clear();
	incons.clear();
	closed.clear();

	for (int x = 0; x < NODE_X; x++) {
		for (int y = 0; y < NODE_Y; y++) {
			g[GridPosition(x, y)] = std::numeric_limits<double>::infinity();
			rhs[GridPosition(x, y)] = std::numeric_limits<double>::infinity();
		}
	}

	rhs[sGoal] = 0.0;

	eps = EPS;

	open[sGoal] = key(sGoal);
}

void ADStar::computeOrImprovePath() {
	while (true) {
		auto svOpt = topKey();
		if (!svOpt.has_value()) {
			break;
		}
		auto sv = svOpt.value();
		auto s = sv.first;
		auto v = sv.second;

		if (comparePair(v, key(sStart)) >= 0
				&& rhs.at(sStart) == g.at(sStart)) {
			break;
		}

		open.erase(s);

		if (g.at(s) > rhs.at(s)) {
			g[s] = rhs.at(s);
			closed.emplace(s);

			for (const GridPosition &sn : getOpenNeighbors(s)) {
				updateState(sn);
			}
		} else {
			g[s] = std::numeric_limits<double>::infinity();
			for (const GridPosition &sn : getOpenNeighbors(s)) {
				updateState(sn);
			}
			updateState(s);
		}
	}
}

void ADStar::updateState(const ADStar::GridPosition &s) {
	if (s != sGoal) {
		rhs[s] = std::numeric_limits<double>::infinity();

		for (const GridPosition &x : getOpenNeighbors(s)) {
			rhs[s] = std::min(rhs.at(s), g.at(x) + cost(s, x));
		}
	}

	open.erase(s);

	if (g.at(s) != rhs.at(s)) {
		if (!closed.contains(s)) {
			open[s] = key(s);
		} else {
			incons[s] = std::pair<double, double>(0.0, 0.0);
		}
	}
}

bool ADStar::isCollision(const ADStar::GridPosition &sStart,
		const ADStar::GridPosition &sEnd) {
	if (obstacles.contains(sStart) || obstacles.contains(sEnd)) {
		return true;
	}

	if (sStart.x != sEnd.x && sStart.y != sEnd.y) {
		GridPosition s1;
		GridPosition s2;

		if (sEnd.x - sStart.x == sStart.y - sEnd.y) {
			s1 = GridPosition(std::min(sStart.x, sEnd.x),
					std::min(sStart.y, sEnd.y));
			s2 = GridPosition(std::max(sStart.x, sEnd.x),
					std::max(sStart.y, sEnd.y));
		} else {
			s1 = GridPosition(std::min(sStart.x, sEnd.x),
					std::max(sStart.y, sEnd.y));
			s2 = GridPosition(std::max(sStart.x, sEnd.x),
					std::min(sStart.y, sEnd.y));
		}

		return obstacles.contains(s1) || obstacles.contains(s2);
	}

	return false;
}

std::unordered_set<ADStar::GridPosition> ADStar::getOpenNeighbors(
		const ADStar::GridPosition &s) {
	std::unordered_set < GridPosition > ret;

	for (int xMove = -1; xMove <= 1; xMove++) {
		for (int yMove = -1; yMove <= 1; yMove++) {
			GridPosition sNext = GridPosition(s.x + xMove, s.y + yMove);
			if (!obstacles.contains(sNext) && sNext.x >= 0 && sNext.x < NODE_X
					&& sNext.y >= 0 && sNext.y < NODE_Y) {
				ret.emplace(sNext);
			}
		}
	}
	return ret;
}

std::unordered_set<ADStar::GridPosition> ADStar::getAllNeighbors(
		const ADStar::GridPosition &s) {
	std::unordered_set < GridPosition > ret;

	for (int xMove = -1; xMove <= 1; xMove++) {
		for (int yMove = -1; yMove <= 1; yMove++) {
			GridPosition sNext = GridPosition(s.x + xMove, s.y + yMove);
			if (sNext.x >= 0 && sNext.x < NODE_X && sNext.y >= 0
					&& sNext.y < NODE_Y) {
				ret.emplace(sNext);
			}
		}
	}
	return ret;
}

std::pair<double, double> ADStar::key(const ADStar::GridPosition &s) {
	if (g.at(s) > rhs.at(s)) {
		return std::pair<double, double>(rhs.at(s) + eps * heuristic(sStart, s),
				rhs.at(s));
	} else {
		return std::pair<double, double>(g.at(s) + heuristic(sStart, s),
				g.at(s));
	}
}

std::optional<std::pair<ADStar::GridPosition, std::pair<double, double>>> ADStar::topKey() {
	std::optional < std::pair<ADStar::GridPosition, std::pair<double, double>>
			> min = std::nullopt;

	for (auto entry : open) {
		if (!min || comparePair(entry.second, min.value().second) < 0) {
			min = entry;
		}
	}

	return min;
}
