const {Vector2, Util} = require('./util.js');

class PlannedPath {
	/**
	 * Construct a path which holds an array of points. The initial path
	 * will be a simple path from the middle of the wall to the left switch
	 */
	constructor() {
		this.points = [];
		this.velocities = [];
		this.holonomicAngles = [];
		this.points.push(new Vector2(10 * Util.pixelsPerFoot + Util.xPixelOffset, 8 * Util.pixelsPerFoot + Util.yPixelOffset));
		this.points.push(new Vector2(14.37 * Util.pixelsPerFoot + Util.xPixelOffset, 8 * Util.pixelsPerFoot + Util.yPixelOffset));
		this.points.push(new Vector2(17.52 * Util.pixelsPerFoot + Util.xPixelOffset, 4.28 * Util.pixelsPerFoot + Util.yPixelOffset));
		this.points.push(new Vector2(19.4 * Util.pixelsPerFoot + Util.xPixelOffset, 8.5 * Util.pixelsPerFoot + Util.yPixelOffset));
		this.velocities.push(-1);
		this.velocities.push(-1);
		this.holonomicAngles.push(0);
		this.holonomicAngles.push(45);
	}

	/**
	 * Get a point in the path
	 * @param i The index of the point
	 * @returns {Vector2} The point
	 */
	get(i) {
		return this.points[i];
	}

	/**
	 * Get the number of points in the path
	 * @returns {number} The number of splines
	 */
	numPoints() {
		return this.points.length;
	}

	/**
	 * Get the number of splines in the path
	 * @returns {number} The number of splines
	 */
	numSplines() {
		return ((this.points.length - 4) / 3) + 1;
	}

	/**
	 * Get the points in a spline
	 * @param i The index of the spline
	 * @returns {*[]} The points in the spline
	 */
	getPointsInSpline(i) {
		return [this.points[i * 3], this.points[i * 3 + 1], this.points[i * 3 + 2], this.points[i * 3 + 3]];
	}

	/**
	 * Add a new spline to the path
	 * @param anchorPos The position of the new anchor point
	 */
	addSpline(anchorPos) {
		this.points.push(Vector2.subtract(Vector2.multiply(this.points[this.points.length - 1], 2), this.points[this.points.length - 2]));
		this.points.push(Vector2.multiply(Vector2.add(this.points[this.points.length - 1], new Vector2(anchorPos.x, anchorPos.y)), 0.5));
		this.points.push(new Vector2(anchorPos.x, anchorPos.y));
		this.velocities.push(-1);
		this.holonomicAngles.push(0);
	}

	/**
	 * Insert a new spline into the path
	 * @param anchorPos The pos of the new anchor point
	 * @param index The index to insert the spline at
	 */
	insertSpline(anchorPos, index){
		let control1 = Vector2.multiply(Vector2.add(this.points[index - 1], new Vector2(anchorPos.x, anchorPos.y)), 0.5);
		// let control1 = new Vector2(anchorPos.x - 5, anchorPos.y - 5);
		let anchor = new Vector2(anchorPos.x, anchorPos.y);
		// let control2 = new Vector2(anchorPos.x + 5, anchorPos.y + 5);
		let control2 = Vector2.subtract(Vector2.multiply(anchor, 2), control1);
		if(index === 2){
			this.velocities.splice(1, 0, -1);
			this.holonomicAngles.splice(1, 0, -1);
		}else if(index === this.points.length - 2){
			this.velocities.splice(this.velocities.length - 2, 0, -1);
			this.holonomicAngles.splice(this.velocities.length - 2, 0, -1);
		}else{
			this.velocities.splice(this.anchorIndexToVelocity(index + 1), 0, -1);
			this.holonomicAngles.splice(this.anchorIndexToVelocity(index + 1), 0, -1);
		}
		this.points.splice(index, 0, control1, anchor, control2);
	}

	/**
	 * Move a point in the path
	 * @param i The index of the point to move
	 * @param newPos The new position of the point
	 */
	movePoint(i, newPos) {
		const deltaMove = Vector2.subtract(newPos, this.points[i]);
		this.points[i] = newPos;

		if (i % 3 === 0) {
			if (i + 1 < this.points.length) {
				this.points[i + 1] = Vector2.add(this.points[i + 1], deltaMove);
			}
			if (i - 1 >= 0) {
				this.points[i - 1] = Vector2.add(this.points[i - 1], deltaMove);
			}
		} else {
			const nextIsAnchor = (i + 1) % 3 === 0;
			const correspondingControlIndex = (nextIsAnchor) ? i + 2 : i - 2;
			const anchorIndex = (nextIsAnchor) ? i + 1 : i - 1;

			if (correspondingControlIndex >= 0 && correspondingControlIndex < this.points.length) {
				const dst = Vector2.subtract(this.points[anchorIndex], this.points[correspondingControlIndex]).getMagnitude();
				const dir = Vector2.subtract(this.points[anchorIndex], newPos).normalized();
				this.points[correspondingControlIndex] = Vector2.add(this.points[anchorIndex], Vector2.multiply(dir, dst));
			}
		}
	}

	/**
	 * Delete a spline from the path
	 * @param anchorIndex The index of the anchor point in the spline
	 */
	deleteSpline(anchorIndex) {
		if (anchorIndex % 3 === 0 && this.numSplines() > 1) {
			if (anchorIndex === 0) {
				this.points.splice(0, 3);
			} else if (anchorIndex === this.points.length - 1) {
				this.points.splice(anchorIndex - 2, 3);
			} else {
				this.points.splice(anchorIndex - 1, 3);
			}
			this.velocities.splice(this.anchorIndexToVelocity(anchorIndex));
			this.holonomicAngles.splice(this.anchorIndexToVelocity(anchorIndex));
		}
	}

	/**
	 * Update a custom velocity
	 * @param anchorIndex The index of the point to update
	 * @param vel The new velocity
	 */
	updateVelocity(anchorIndex, vel) {
		this.velocities[this.anchorIndexToVelocity(anchorIndex)] = vel;
	}

	updateHolonomicAngle(anchorIndex, angle) {
		this.holonomicAngles[this.anchorIndexToVelocity(anchorIndex)] = angle;
	}

	/**
	 * Get a velocity for an anchor point
	 * @param anchorIndex The anchor index
	 * @returns {number} The velocity
	 */
	getVelocity(anchorIndex) {
		return this.velocities[this.anchorIndexToVelocity(anchorIndex)];
	}

	getHolonomicAngle(anchorIndex){
		return this.holonomicAngles[this.anchorIndexToVelocity(anchorIndex)];
	}

	/**
	 * Convert an anchor point index to its corresponding velocity index
	 * @param anchorIndex The anchor index
	 * @returns {number} The velocity index
	 */
	anchorIndexToVelocity(anchorIndex) {
		if (anchorIndex === 0) {
			return 0;
		} else {
			return ((anchorIndex - 3) / 3) + 1;
		}
	}
}

module.exports.PlannedPath = PlannedPath;