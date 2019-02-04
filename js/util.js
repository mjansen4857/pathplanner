// Numbers used for converting from pixels to feet and vice versa
const pixelsPerFoot = 20.15;
const pixelsPerMeter = pixelsPerFoot / 0.3048;
const xPixelOffset = 56;
const yPixelOffset = 78;

class Vector2 {
	/**
	 * Construct a new 2D vector
	 * @param x The x position
	 * @param y The y position
	 */
	constructor(x, y) {
		this.x = x;
		this.y = y;
		this.magnitude = Math.sqrt((x * x) + (y * y));
	}

	/**
	 * Get the magnitude
	 * @returns {number} The magnitude
	 */
	getMagnitude() {
		return this.magnitude;
	}

	/**
	 * Get the normalized vector
	 * @returns {Vector2} The normalized vector
	 */
	normalized() {
		if (this.magnitude > 0) {
			return Vector2.divide(this, this.magnitude);
		}
		return new Vector2(0, 0);
	}

	/**
	 * Add two points together
	 * @param a Point #1
	 * @param b Point #2
	 * @returns {Vector2} The sum of the two points
	 */
	static add(a, b) {
		return new Vector2(a.x + b.x, a.y + b.y);
	}

	/**
	 * Subtract one point from another
	 * @param a Point #1
	 * @param b Point #2
	 * @returns {Vector2} The difference of the two points
	 */
	static subtract(a, b) {
		return new Vector2(a.x - b.x, a.y - b.y);
	}

	/**
	 * Multiply a vector by a constant
	 * @param a The vector
	 * @param mult The number to multiply by
	 * @returns {Vector2} The product of the vector and number
	 */
	static multiply(a, mult) {
		return new Vector2(a.x * mult, a.y * mult);
	}

	/**
	 * Divide a vector by a constant
	 * @param a The vector
	 * @param div The number to divide by
	 * @returns {Vector2} The dividend of the vector and number
	 */
	static divide(a, div) {
		return new Vector2(a.x / div, a.y / div);
	}
}

class Util {
	/**
	 * Interpolate on a line
	 * @param a Point #1
	 * @param b Point #2
	 * @param t The value to interpolate for. Between 0 and 1
	 * @returns {Vector2} The interpolated point
	 */
	static lerp(a, b, t) {
		return Vector2.add(a, Vector2.multiply(Vector2.subtract(b, a), t));
	}

	/**
	 * Interpolate on a quadratic curve
	 * @param a Point #1
	 * @param b Point #2
	 * @param c Point #3
	 * @param t The value to interpolate for. Between 0 and 1
	 * @returns {Vector2} The interpolated point
	 */
	static quadraticCurve(a, b, c, t) {
		var p0 = Util.lerp(a, b, t);
		var p1 = Util.lerp(b, c, t);
		return Util.lerp(p0, p1, t);
	}

	/**
	 * Interpolate on a quadratic curve
	 * @param a Point #1
	 * @param b Point #2
	 * @param c Point #3
	 * @param d Point #4
	 * @param t The value to interpolate for. Between 0 and 1
	 * @returns {Vector2} The interpolated point
	 */
	static cubicCurve(a, b, c, d, t) {
		var p0 = Util.quadraticCurve(a, b, c, t);
		var p1 = Util.quadraticCurve(b, c, d, t);
		return Util.lerp(p0, p1, t);
	}

	/**
	 * Calculate the slope between two points
	 * @param a Point #1
	 * @param b Point #2
	 * @returns {number} The slope
	 */
	static slope(a, b) {
		var dy = a.y - b.y;
		var dx = a.x - b.x;
		return dy / dx;
	}

	/**
	 * Find the closest point on a line to another point
	 * @param lineStart The start point of the line
	 * @param lineEnd The end point of the line
	 * @param p Find the closest point to this point
	 * @returns {Vector2} The closest point on the line
	 */
	static closestPointOnLine(lineStart, lineEnd, p) {
		var dx = lineEnd.x - lineStart.x;
		var dy = lineEnd.y - lineStart.y;

		if (dx === 0 === dy) {
			return lineStart;
		}

		var t = ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) / (dx * dx + dy * dy);

		var closestPoint;
		if (t < 0) {
			closestPoint = lineStart;
		} else if (t > 1) {
			closestPoint = lineEnd;
		} else {
			closestPoint = Util.lerp(lineStart, lineEnd, t);
		}
		return closestPoint;
	}
}

module.exports.Vector2 = Vector2;
module.exports.Util = Util;
module.exports.Util.xPixelOffset = xPixelOffset;
module.exports.Util.yPixelOffset = yPixelOffset;
module.exports.Util.pixelsPerFoot = pixelsPerFoot;
module.exports.Util.pixelsPerMeter = pixelsPerMeter;