const {Vector2, Util} = require('./util.js');
const {PlannedPath} = require('./planned_path.js');

class PathEditor {
	/**
	 * Constructs a path editor which is used to edit the point locations for generating
	 * a path
	 * @param image The background image
	 * @param saveHistory The function to save to the undo/redo history
	 */
	constructor(image, saveHistory) {
		this.canvas = document.getElementById('canvas');
		this.plannedPath = new PlannedPath();
		this.image = image;
		this.previewing = false;
		this.width = 1200;
		this.height = 700;
		this.highlightedPoint = -1;
		this.pointDragIndex = -1;
		this.updatePoint = -1;
		this.lastMousePos = {
			x: 0,
			y: 0
		};
		this.saveHistory = saveHistory;
		// Handle all mouse interactions with the points
		// (Add, delete, drag, etc.)
		this.canvas.addEventListener('mousemove', (evt) => {
			var mousePos = getMousePos(this.canvas, evt);
			if (evt.buttons == 0) {
				for (var i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(mousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(mousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						this.highlightedPoint = i;
						this.update();
						this.lastMousePos.x = mousePos.x;
						this.lastMousePos.y = mousePos.y;
						return;
					}
				}
				for (var i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(this.lastMousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(this.lastMousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						this.highlightedPoint = -1;
						this.update();
						this.lastMousePos.x = mousePos.x;
						this.lastMousePos.y = mousePos.y;
						return;
					}
				}
			} else if (evt.buttons == 1) {
				if (this.pointDragIndex != -1) {
					if (mousePos.x >= 0 && mousePos.y >= 0 && mousePos.x <= this.width && mousePos.y <= this.height) {
						if (evt.getModifierState('Shift') && this.pointDragIndex % 3 != 0) {
							var controlIndex = this.pointDragIndex;
							var nextIsAnchor = (controlIndex + 1) % 3 == 0;
							var anchorIndex = (nextIsAnchor) ? controlIndex + 1 : controlIndex - 1;
							var lineStart = this.plannedPath.points[anchorIndex];
							var lineEnd = Vector2.add(this.plannedPath.points[controlIndex], Vector2.subtract(this.plannedPath.points[controlIndex], this.plannedPath.points[anchorIndex]));
							var p = new Vector2(mousePos.x, mousePos.y);
							var newPoint = Util.closestPointOnLine(lineStart, lineEnd, p);
							if (newPoint.x - lineStart.x != 0 || newPoint.y - lineStart.y != 0) {
								this.plannedPath.movePoint(controlIndex, newPoint);
							}
						} else {
							this.plannedPath.movePoint(this.pointDragIndex, new Vector2(mousePos.x, mousePos.y));
						}
						this.update();
					}
				}
			}
			this.lastMousePos.x = mousePos.x;
			this.lastMousePos.y = mousePos.y;
		});
		this.canvas.addEventListener('mousedown', (evt) => {
			var mousePos = getMousePos(this.canvas, evt);
			if (evt.buttons == 1) {
				for (var i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(mousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(mousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						this.pointDragIndex = i;
					}
				}
			} else if (evt.buttons == 2) {
				for (var i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(mousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(mousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						if (i % 3 == 0) {
							if (((evt.getModifierState('Control') || evt.getModifierState('Meta'))) && this.plannedPath.numSplines() > 1) {
								this.plannedPath.deleteSpline(i);
								this.update();
								this.saveHistory();
							} else {
								var pointConfigDialog = M.Modal.getInstance(document.getElementById('pointConfig'));
								this.updatePoint = i;
								document.getElementById('pointX').value = Math.round((this.plannedPath.points[i].x - Util.xPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 10000) / 10000;
								document.getElementById('pointY').value = Math.round((this.plannedPath.points[i].y - Util.yPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 10000) / 10000;
								var control;
								var anchor = this.plannedPath.points[i];
								if (i == this.plannedPath.points.length - 1) {
									control = Vector2.subtract(anchor, Vector2.subtract(this.plannedPath.points[i - 1], anchor));
								} else {
									control = this.plannedPath.points[i + 1];
								}
								var angle = Math.round(Math.atan2(control.y - anchor.y, control.x - anchor.x) * (180 / Math.PI) * 10000) / 10000;
								document.getElementById('pointAngle').value = angle;
								var velocity = this.plannedPath.getVelocity(this.updatePoint);
								if(velocity == -1){
									velocity = preferences.maxVel;
								}
								document.getElementById('pointVelocity').value = velocity;
								M.updateTextFields();
								pointConfigDialog.open();
							}
						}
						return;
					}
				}
				if (!evt.getModifierState('Control') && !evt.getModifierState('Meta') && !evt.getModifierState('Shift') && evt.buttons == 2) {
					this.plannedPath.addSpline(new Vector2(mousePos.x, mousePos.y));
					this.highlightedPoint = this.plannedPath.points.length - 1;
					this.update();
					this.saveHistory();
				}
			}
		});
		this.canvas.addEventListener('mouseup', (evt) => {
			if (this.pointDragIndex != -1) {
				this.saveHistory();
			}
			this.pointDragIndex = -1;
		});
	}

	/**
	 * Update all point velocities that are one value to another.
	 * Used when the robot max velocity is changed so point velocities
	 * that are the max should be updated as well
	 * @param oldValue
	 * @param newValue
	 */
	updateVelocities(oldValue, newValue) {
		for (var i = 0; i < this.plannedPath.velocities.length; i++) {
			if (this.plannedPath.velocities[i] == oldValue || this.plannedPath.velocities[i] > newValue) {
				this.plannedPath.velocities[i] = newValue;
			}
		}
	}

	/**
	 * Update the field image
	 * @param image The image to use
	 */
	updateImage(image) {
		this.image = image;
	}

	/**
	 * Clear the canvas
	 */
	clear() {
		var g = this.canvas.getContext('2d');
		g.clearRect(0, 0, this.canvas.width, this.canvas.height);
	}

	/**
	 * Draw the canvas. This draws the background image and the path/points
	 */
	draw() {
		var g = this.canvas.getContext('2d');

		//draw field
		g.drawImage(this.image, 0, 50);

		//draw path line
		g.lineWidth = 3;
		g.strokeStyle = '#eeeeee';
		g.imageSmoothingEnabled = false;
		g.beginPath();
		var angle = Math.atan2(this.plannedPath.points[1].y - this.plannedPath.points[0].y, this.plannedPath.points[1].x - this.plannedPath.points[0].x);
		var startL = new Vector2(this.plannedPath.points[0].x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), this.plannedPath.points[0].y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
		var startR = new Vector2(this.plannedPath.points[0].x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), this.plannedPath.points[0].y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
		g.moveTo(startL.x, startL.y);
		for (var i = 0; i < this.plannedPath.numSplines(); i++) {
			var points = this.plannedPath.getPointsInSpline(i);

			for (var d = 0; d <= 1; d += 0.01) {
				var p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
				var p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
				var angle = Math.atan2(p1.y - p0.y, p1.x - p0.x);
				var p1L = new Vector2(p1.x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), p0.y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));

				g.lineTo(p1L.x, p1L.y);
			}
		}
		g.moveTo(startR.x, startR.y);
		for (var i = 0; i < this.plannedPath.numSplines(); i++) {
			var points = this.plannedPath.getPointsInSpline(i);
			for (var d = 0; d <= 1; d += 0.01) {
				var p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
				var p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
				var angle = Math.atan2(p1.y - p0.y, p1.x - p0.x);
				var p1R = new Vector2(p1.x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), p0.y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));

				g.lineTo(p1R.x, p1R.y);
			}
		}
		g.stroke();

		//draw control lines
		g.strokeStyle = '#000000';
		g.lineWidth = 2.5;
		g.beginPath();
		for (var i = 0; i < this.plannedPath.numSplines(); i++) {
			var points = this.plannedPath.getPointsInSpline(i);
			g.moveTo(points[0].x, points[0].y);
			g.lineTo(points[1].x, points[1].y);
			g.moveTo(points[2].x, points[2].y);
			g.lineTo(points[3].x, points[3].y);
		}
		g.stroke();

		//draw points and perimeter
		var points = this.plannedPath.points;
		for (var i = 0; i < points.length; i++) {
			g.lineWidth = 3;
			if (i == 0) {
				var angle = Math.atan2(points[i + 1].y - points[i].y, points[i + 1].x - points[i].x);
				var l = new Vector2(points[i].x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				var r = new Vector2(points[i].x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				g.fillStyle = "#388e3c";
				g.strokeStyle = "#388e3c";
				this.drawRobotPerimeter(l, r);
			} else if (i == points.length - 1) {
				var angle = Math.atan2(points[i - 1].y - points[i].y, points[i - 1].x - points[i].x);
				var l = new Vector2(points[i].x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				var r = new Vector2(points[i].x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				g.fillStyle = "#d32f2f";
				g.strokeStyle = "#d32f2f";
				this.drawRobotPerimeter(l, r);
			} else {
				g.fillStyle = '#FFFFFF';
			}
			if (i == this.highlightedPoint) {
				g.fillStyle = '#ffeb3b';
			}
			g.strokeStyle = '#000000';
			g.beginPath();
			g.arc(points[i].x, points[i].y, 8, 2 * Math.PI, false);
			g.fill();
			g.stroke();
		}
	}

	/**
	 * Helper method to draw the outline of a robot
	 * @param left The left-middle point of the robot
	 * @param right The right-middle point of the robot
	 */
	drawRobotPerimeter(left, right) {
		var g = this.canvas.getContext('2d');
		var angle = Math.atan2(left.y - right.y, left.x - right.x);
		var halfLength = preferences.robotLength / 2;
		var backLeftX = (left.x + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		var backLeftY = (left.y - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		var frontLeftX = (left.x - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		var frontLeftY = (left.y + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		var backRightX = (right.x + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		var backRightY = (right.y - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		var frontRightX = (right.x - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		var frontRightY = (right.y + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		g.beginPath();
		g.moveTo(backLeftX, backLeftY);
		g.lineTo(frontLeftX, frontLeftY);
		g.lineTo(frontRightX, frontRightY);
		g.lineTo(backRightX, backRightY);
		g.lineTo(backLeftX, backLeftY);
		g.stroke();
	}

	/**
	 * Update the canvas
	 */
	update() {
		if (!this.previewing) {
			this.clear();
			this.draw();
		}
	}

	/**
	 * Run a path preview
	 * @param leftSegments The generated path for the left side
	 * @param rightSegments The generated path for the right side
	 */
	previewPath(leftSegments, rightSegments) {
		var i = 0;
		this.previewing = true;
		var interval = setInterval(() => {
			if (i < leftSegments.length) {
				var g = this.canvas.getContext('2d');
				this.clear();
				g.drawImage(this.image, 0, 50);
				g.strokeStyle = '#eeeeee';
				var leftX = leftSegments[i].x * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].x;
				var leftY = leftSegments[i].y * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].y;
				var rightX = rightSegments[i].x * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].x;
				var rightY = rightSegments[i].y * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].y;
				this.drawRobotPerimeter(new Vector2(leftX, leftY), new Vector2(rightX, rightY));
				i++;
			} else {
				this.previewing = false;
				this.update();
				clearInterval(interval);
			}
		}, preferences.timeStep * 1000);
	}

	/**
	 * Method called when a point is manually changed. This updates that point
	 */
	pointConfigOnConfirm() {
		if (this.updatePoint != -1) {
			var xPos = parseFloat(document.getElementById('pointX').value);
			var yPos = parseFloat(document.getElementById('pointY').value);
			var angle = parseFloat(document.getElementById('pointAngle').value);
			var velocity = Math.max(parseFloat(document.getElementById('pointVelocity').value), (preferences.useMetric) ? 1 * 0.3048 : 1);
			if (!velocity) {
				velocity = -1;
			}
			this.plannedPath.updateVelocity(this.updatePoint, Math.min(velocity, preferences.maxVel));

			var controlIndex;
			if (this.updatePoint == this.plannedPath.points.length - 1) {
				controlIndex = this.updatePoint - 1;
			} else {
				controlIndex = this.updatePoint + 1;
			}
			this.plannedPath.movePoint(this.updatePoint, new Vector2((xPos * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot)) + Util.xPixelOffset, (yPos * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot)) + Util.yPixelOffset));
			var theta = angle * Math.PI / 180;
			var h = Vector2.subtract(this.plannedPath.points[this.updatePoint], this.plannedPath.points[controlIndex]).getMagnitude();
			var o = Math.sin(theta) * h;
			var a = Math.cos(theta) * h;

			if (this.updatePoint == this.plannedPath.points.length - 1) {
				this.plannedPath.movePoint(controlIndex, Vector2.subtract(this.plannedPath.points[this.updatePoint], new Vector2(a, o)));
			} else {
				this.plannedPath.movePoint(controlIndex, Vector2.add(this.plannedPath.points[this.updatePoint], new Vector2(a, o)));
			}

			this.updatePoint = -1;
			this.highlightedPoint = -1;

			this.update();

			M.Modal.getInstance(document.getElementById('pointConfig')).close();
		}
	}
}

function getMousePos(canvas, evt) {
	var rect = canvas.getBoundingClientRect();
	return {
		x: evt.clientX - rect.left,
		y: evt.clientY - rect.top
	}
}

module.exports.PathEditor = PathEditor;