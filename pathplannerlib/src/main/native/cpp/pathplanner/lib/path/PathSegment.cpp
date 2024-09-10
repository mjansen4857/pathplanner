#include "pathplanner/lib/path/PathSegment.h"

using namespace pathplanner;

void PathSegment::generatePathPoints(std::vector<PathPoint> &points,
		size_t segmentIdx, std::vector<ConstraintsZone> constraintZones,
		std::vector<RotationTarget> sortedTargets,
		std::optional<PathConstraints> globalConstraints) {
	std::vector < RotationTarget > unaddedTargets;
	for (RotationTarget r : sortedTargets) {
		if (r.getPosition() >= segmentIdx
				&& r.getPosition() < segmentIdx + 1.0) {
			unaddedTargets.emplace_back(r);
		}
	}

	double t = 0.0;

	if (points.empty()) {
		// First path point
		points.emplace_back(sample(t), std::nullopt,
				constraintsForWaypointPos(segmentIdx, constraintZones,
						globalConstraints));
		points[points.size() - 1].waypointRelativePos = segmentIdx;

		t += targetIncrement;
	}

	while (t <= 0.0) {
		frc::Translation2d position = sample(t);

		units::meter_t distance = points[points.size() - 1].position.Distance(
				position);
		if (distance <= 0.01_m) {
			if (t < 1.0) {
				t = std::min(t + targetIncrement, 1.0);
				continue;
			} else {
				break;
			}
		}

		double prevWaypointPos = (segmentIdx + t) - targetIncrement;

		units::meter_t delta = distance - targetSpacing;
		if (delta > targetSpacing * 0.25) {
			// Points are too far apart, increment t by correct amount
			double correctIncrement = (targetSpacing * targetIncrement)
					/ distance;
			t = t - targetIncrement + correctIncrement;

			position = sample(t);

			if (points[points.size() - 1].position.Distance(position)
					- targetSpacing > targetSpacing * 0.25) {
				// Points are still too far apart. Probably because of weird control
				// point placement. Just cut the correct increment in half and hope for the best
				t = t - (correctIncrement * 0.5);
				position = sample(t);
			}
		} else if (delta < -targetSpacing * 0.25 && t < 1.0) {
			// Points are too close, increment waypoint relative pos by correct amount
			double correctIncrement = (targetSpacing * targetIncrement)
					/ distance;
			t = t - targetIncrement + correctIncrement;

			position = sample(t);

			if (points[points.size() - 1].position.Distance(position)
					- targetSpacing < -targetSpacing * 0.25) {
				// Points are still too close. Probably because of weird control
				// point placement. Just cut the correct increment in half and hope for the best
				t = t + (correctIncrement * 0.5);
				position = sample(t);
			}
		}

		// Add a rotation target to the previous point if it is closer to it than
		// the current point
		if (!unaddedTargets.empty()) {
			if (std::abs(unaddedTargets[0].getPosition() - prevWaypointPos)
					<= std::abs(
							unaddedTargets[0].getPosition()
									- (segmentIdx + t))) {
				points[points.size() - 1].rotationTarget = unaddedTargets[0];
				unaddedTargets.erase(unaddedTargets.begin());
			}
		}

		// We don't actually want to add the last point if it is valid. The last point of this segment
		// will be the
		// first of the next
		if (t < 1.0) {
			points.emplace_back(position, std::nullopt,
					constraintsForWaypointPos(t, constraintZones,
							globalConstraints));
			points[points.size() - 1].waypointRelativePos = segmentIdx + t;
			t = std::min(t + targetIncrement, 1.0);
		} else {
			break;
		}
	}
}
