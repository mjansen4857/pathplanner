const pixelsPerFoot = 20.3;
const xPixelOffset = 54;
const yPixelOffset = 76;

class Vector2{
	constructor(x, y){
		this.x = x;
		this.y = y;
		this.magnitude = Math.sqrt((x*x) + (y*y));
	}

	getMagnitude(){
		return this.magnitude;
	}

	normalized(){
		if(this.magnitude > 0){
			return Vector2.divide(this, this.magnitude);
		}
		return new Vector2(0, 0);
	}

	static add(a, b){
		return new Vector2(a.x + b.x, a.y + b.y);
	}

	static subtract(a, b){
		return new Vector2(a.x - b.x, a.y - b.y);
	}

	static multiply(a, mult){
		return new Vector2(a.x * mult, a.y * mult);
	}

	static divide(a, div){
		return new Vector2(a.x / div, a.y / div);
	}
}

class Util{
	static lerp(a, b, t){
		return Vector2.add(a, Vector2.multiply(Vector2.subtract(b, a), t));
	}

	static quadraticCurve(a, b, c, t){
		var p0 = Util.lerp(a, b, t);
		var p1 = Util.lerp(b, c, t);
		return Util.lerp(p0, p1, t);
	}

	static cubicCurve(a, b, c, d, t){
		var p0 = Util.quadraticCurve(a, b, c, t);
		var p1 = Util.quadraticCurve(b, c, d, t);
		return Util.lerp(p0, p1, t);
	}

	static slope(a, b){
		var dy = a.y - b.y;
		var dx = a.x - b.x;
		return dy/dx;
	}

	static closestPointOnLine(lineStart, lineEnd, p){
		var dx = lineEnd.x - lineStart.x;
		var dy = lineEnd.y - lineStart.y;

		if(dx === 0 === dy){
			return lineStart;
		}

		var t = ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) / (dx * dx + dy * dy);

		var closestPoint;
		if(t < 0){
			closestPoint = lineStart;
		}else if(t > 1){
			closestPoint = lineEnd;
		}else{
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