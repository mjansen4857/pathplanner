class PlannedPath {
	constructor() {
		this.points = new Array();
		this.points.push(new Vector2(1.5 * pixelsPerFoot + xPixelOffset, 13.6 * pixelsPerFoot + yPixelOffset));
		this.points.push(new Vector2(7.5 * pixelsPerFoot + xPixelOffset, 13.6 * pixelsPerFoot + yPixelOffset));
		this.points.push(new Vector2(5 * pixelsPerFoot + xPixelOffset, 9 * pixelsPerFoot + yPixelOffset));
		this.points.push(new Vector2(10 * pixelsPerFoot + xPixelOffset, 9 * pixelsPerFoot + yPixelOffset));
	}

	get(i) {
		return this.points[i];
	}

	numPoints() {
		return this.points.length;
	}

	numSplines() {
		return ((this.points.length - 4) / 3) + 1;
	}

	getPointsInSpline(i) {
		return new Array(this.points[i * 3], this.points[i * 3 + 1], this.points[i * 3 + 2], this.points[i * 3 + 3]);
	}

	addSpline(anchorPos) {
		this.points.push(Vector2.subtract(Vector2.multiply(this.points[this.points.length - 1], 2), this.points[this.points.length - 2]));
		this.points.push(Vector2.multiply(Vector2.add(this.points[this.points.length - 1], new Vector2(anchorPos.x, anchorPos.y)), 0.5))
		this.points.push(new Vector2(anchorPos.x, anchorPos.y));
	}

	movePoint(i, newPos) {
		var deltaMove = Vector2.subtract(newPos, this.points[i]);
		this.points[i] = newPos;

		if (i % 3 === 0) {
			if (i + 1 < this.points.length) {
				this.points[i + 1] = Vector2.add(this.points[i + 1], deltaMove);
			}
			if (i - 1 >= 0) {
				this.points[i - 1] = Vector2.add(this.points[i - 1], deltaMove);
			}
		} else {
			var nextIsAnchor = (i + 1) % 3 == 0;
			var correspondingControlIndex = (nextIsAnchor) ? i + 2 : i - 2;
			var anchorIndex = (nextIsAnchor) ? i + 1 : i - 1;

			if (correspondingControlIndex >= 0 && correspondingControlIndex < this.points.length) {
				var dst = Vector2.subtract(this.points[anchorIndex], this.points[correspondingControlIndex]).getMagnitude();
				var dir = Vector2.subtract(this.points[anchorIndex], newPos).normalized();
				this.points[correspondingControlIndex] = Vector2.add(this.points[anchorIndex], Vector2.multiply(dir, dst));
			}
		}
	}

	deleteSpline(anchorIndex) {
		if (anchorIndex % 3 == 0 && this.numSplines() > 1) {
			if (anchorIndex == 0) {
				this.points.splice(0, 3);
			} else if (anchorIndex == this.points.length - 1) {
				this.points.splice(anchorIndex - 2, 3);
			} else {
				this.points.splice(anchorIndex - 1, 3);
			}
		}
	}
}