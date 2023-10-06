#include "pathplanner/lib/pathfinding/ADStar.h"
#include <cmath>
#include <frc/Filesystem.h>
#include <wpi/raw_istream.h>
#include <wpi/json.h>
#include <chrono>
#include <frc/Errors.h>

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

std::atomic<ADStar::GridPosition> ADStar::sStart = ADStar::GridPosition(0, 0);
std::atomic<ADStar::GridPosition> ADStar::sGoal = ADStar::GridPosition(0, 0);

std::atomic<double> ADStar::eps = ADStar::EPS;

std::thread ADStar::planningThread;
std::mutex ADStar::mutex;

std::atomic_bool ADStar::doMinor = true;
std::atomic_bool ADStar::doMajor = true;
std::atomic_bool ADStar::needsReset = true;
std::atomic_bool ADStar::needsExtract = false;
std::atomic_bool ADStar::running = false;
std::atomic_bool ADStar::newPathAvailable = false;

std::vector<frc::Translation2d> ADStar::currentPath;
std::mutex ADStar::currentPath_mutex;

void ADStar::ensureInitialized() {
	if (!running) {
		running = true;
		sStart = GridPosition(0, 0);
		sGoal = GridPosition(0, 0);

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
				std::lock_guard < std::mutex > pathLock(currentPath_mutex);
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
	// TODO
}

std::vector<frc::Translation2d> ADStar::extractPath() {
	std::vector < frc::Translation2d > bezierPoints;

	// TODO

	return bezierPoints;
}

std::vector<frc::Translation2d> ADStar::getCurrentPath() {
	if (!running) {
		FRC_ReportError(frc::warn::Warning,
				"ADStar path was retrieved before it was initialized");
	}

	std::lock_guard < std::mutex > pathLock(currentPath_mutex);
	newPathAvailable = false;
	return currentPath;
}

std::unordered_set<ADStar::GridPosition> ADStar::getOpenNeighbors(
		const ADStar::GridPosition &s) {
	std::unordered_set < GridPosition > ret;

	for (int xMove = -1; xMove <= 1; xMove++) {
		for (int yMove = -1; yMove <= 1; yMove++) {
			GridPosition sNext = GridPosition(s.x + xMove, s.y + yMove);
			if (std::find(obstacles.begin(), obstacles.end(), sNext)
					== obstacles.end() && sNext.x >= 0 && sNext.x < NODE_X
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
