const {
	Vector2,
	Util
} = require('./util.js');
const {
	PlannedPath
} = require('./planned_path.js');
const log = require('electron-log');

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
		this.highlightedHolonomicPoint = -1;
		this.pointDragIndex = -1;
		this.holonomicDragIndex = -1;
		this.updatePoint = -1;
		this.lastMousePos = {
			x: 0,
			y: 0
		};
		this.saveHistory = saveHistory;
		// Handle all mouse interactions with the points
		// (Add, delete, drag, etc.)
		this.canvas.addEventListener('mousemove', (evt) => {
			let mousePos = getMousePos(this.canvas, evt);
			if (evt.buttons === 0) {
				// No Mouse button pressed
				for (let i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(mousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(mousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						this.highlightedPoint = i;
						this.update();
						this.lastMousePos.x = mousePos.x;
						this.lastMousePos.y = mousePos.y;
						return;
					}
					if(i % 3 === 0){
						//check if holonomic angle point is hovered
						const angle = this.plannedPath.getHolonomicAngle(i) * (Math.PI / 180);
						const halfLength = (preferences.robotLength/2) * (preferences.useMetric ? Util.pixelsPerMeter : Util.pixelsPerFoot);
						let holoPointX = this.plannedPath.points[i].x + (halfLength * Math.cos(angle));
						let holoPointY = this.plannedPath.points[i].y + (halfLength * Math.sin(angle));
						if ((Math.pow(mousePos.x - holoPointX, 2) + (Math.pow(mousePos.y - holoPointY, 2))) <= Math.pow(6, 2)) {
							this.highlightedHolonomicPoint = i;
							this.update();
							this.lastMousePos.x = mousePos.x;
							this.lastMousePos.y = mousePos.y;
							return;
						}
					}
				}
				for (let i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(this.lastMousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(this.lastMousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						this.highlightedPoint = -1;
						this.update();
						this.lastMousePos.x = mousePos.x;
						this.lastMousePos.y = mousePos.y;
						return;
					}
					if(i % 3 === 0){
						//check if holonomic angle point is hovered
						const angle = this.plannedPath.getHolonomicAngle(i) * (Math.PI / 180);
						const halfLength = (preferences.robotLength/2) * (preferences.useMetric ? Util.pixelsPerMeter : Util.pixelsPerFoot);
						let holoPointX = this.plannedPath.points[i].x + (halfLength * Math.cos(angle));
						let holoPointY = this.plannedPath.points[i].y + (halfLength * Math.sin(angle));
						if ((Math.pow(this.lastMousePos.x - holoPointX, 2) + (Math.pow(this.lastMousePos.y - holoPointY, 2))) <= Math.pow(6, 2)) {
							this.highlightedHolonomicPoint = -1;
							this.update();
							this.lastMousePos.x = mousePos.x;
							this.lastMousePos.y = mousePos.y;
							return;
						}
					}
				}
			} else if (evt.buttons === 1) {
				// Left mouse button pressed
				if (this.pointDragIndex !== -1) {
					if (mousePos.x >= 0 && mousePos.y >= 0 && mousePos.x <= this.width && mousePos.y <= this.height) {
						if (evt.getModifierState('Shift') && this.pointDragIndex % 3 !== 0) {
							const controlIndex = this.pointDragIndex;
							const nextIsAnchor = (controlIndex + 1) % 3 === 0;
							const anchorIndex = (nextIsAnchor) ? controlIndex + 1 : controlIndex - 1;
							const lineStart = this.plannedPath.points[anchorIndex];
							const lineEnd = Vector2.add(this.plannedPath.points[controlIndex], Vector2.subtract(this.plannedPath.points[controlIndex], this.plannedPath.points[anchorIndex]));
							const p = new Vector2(mousePos.x, mousePos.y);
							const newPoint = Util.closestPointOnLine(lineStart, lineEnd, p);
							if (newPoint.x - lineStart.x !== 0 || newPoint.y - lineStart.y !== 0) {
								this.plannedPath.movePoint(controlIndex, newPoint);
							}
						} else {
							if (evt.getModifierState('Shift') && this.pointDragIndex % 3 === 0) {
								this.plannedPath.movePoint(this.pointDragIndex, new Vector2(mousePos.x, this.originalYPos));
							} else {
								this.plannedPath.movePoint(this.pointDragIndex, new Vector2(mousePos.x, mousePos.y));
							}
						}
						this.update();
					}
				}else if(this.holonomicDragIndex !== -1){
					const dx = mousePos.x - this.plannedPath.points[this.holonomicDragIndex].x;
					const dy = mousePos.y - this.plannedPath.points[this.holonomicDragIndex].y;
					const theta = Math.round(Math.atan2(dy, dx) / (Math.PI / 180));
					this.plannedPath.updateHolonomicAngle(this.holonomicDragIndex, theta);
					this.update();
				}
			}
			this.lastMousePos.x = mousePos.x;
			this.lastMousePos.y = mousePos.y;
		});
		this.canvas.addEventListener('mousedown', (evt) => {
			const mousePos = getMousePos(this.canvas, evt);
			if (evt.buttons === 1) {
				// Left mouse button pressed
				for (let i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(mousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(mousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						this.pointDragIndex = i;
						this.originalXPos = this.plannedPath.points[i].x; // Used for constraining X axis position of main point of a spline duing mouseMove
						this.originalYPos = this.plannedPath.points[i].y; // Used for constraining Y axis position of main point of a spline duing mouseMove
					}else if(i % 3 === 0){
						//check if holonomic angle point is hovered
						const angle = this.plannedPath.getHolonomicAngle(i) * (Math.PI / 180);
						const halfLength = (preferences.robotLength/2) * (preferences.useMetric ? Util.pixelsPerMeter : Util.pixelsPerFoot);
						let holoPointX = this.plannedPath.points[i].x + (halfLength * Math.cos(angle));
						let holoPointY = this.plannedPath.points[i].y + (halfLength * Math.sin(angle));
						if ((Math.pow(mousePos.x - holoPointX, 2) + (Math.pow(mousePos.y - holoPointY, 2))) <= Math.pow(6, 2)) {
							this.holonomicDragIndex = i;
						}
					}
				}
			} else if (evt.buttons === 2) {
				// Right mouse button pressed
				for (let i = 0; i < this.plannedPath.numPoints(); i++) {
					if ((Math.pow(mousePos.x - this.plannedPath.points[i].x, 2) + (Math.pow(mousePos.y - this.plannedPath.points[i].y, 2))) <= Math.pow(8, 2)) {
						if (i % 3 === 0) {
							if (((evt.getModifierState('Control') || evt.getModifierState('Meta'))) && this.plannedPath.numSplines() > 1) {
								this.plannedPath.deleteSpline(i);
								this.update();
								this.saveHistory();
							} else {
								const pointConfigDialog = M.Modal.getInstance(document.getElementById('pointConfig'));
								this.updatePoint = i;
								document.getElementById('pointX').value = Math.round((this.plannedPath.points[i].x - Util.xPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 10000) / 10000;
								document.getElementById('pointY').value = Math.round((this.plannedPath.points[i].y - Util.yPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 10000) / 10000;
								let control;
								const anchor = this.plannedPath.points[i];
								if (i === this.plannedPath.points.length - 1) {
									control = Vector2.subtract(anchor, Vector2.subtract(this.plannedPath.points[i - 1], anchor));
								} else {
									control = this.plannedPath.points[i + 1];
								}
								document.getElementById('pointAngle').value = Math.round(Math.atan2(control.y - anchor.y, control.x - anchor.x) * (180 / Math.PI) * 10000) / 10000;
								let velocity = this.plannedPath.getVelocity(this.updatePoint);
								if (velocity === -1) {
									velocity = null;
								}
								document.getElementById('pointVelocity').value = velocity;
								M.updateTextFields();
								pointConfigDialog.open();
							}
						}
						return;
					}
				}
				if (!evt.getModifierState('Control') && !evt.getModifierState('Meta') && !evt.getModifierState('Shift') && evt.buttons === 2) {
					this.plannedPath.addSpline(new Vector2(mousePos.x, mousePos.y));
					this.highlightedPoint = this.plannedPath.points.length - 1;
					this.update();
					this.saveHistory();
				}

				if(evt.getModifierState('Shift')){
					let closestPoint = 0;
					for(let i = 3; i < this.plannedPath.points.length; i += 3){
						let d1 = Util.distanceBetweenPoints(this.plannedPath.points[closestPoint], mousePos);
						let d2 = Util.distanceBetweenPoints(this.plannedPath.points[i], mousePos);

						if(d2 < d1){
							closestPoint = i;
						}
					}
					if(closestPoint === 0){
						this.plannedPath.insertSpline(mousePos, 2);
						this.highlightedPoint = 3;
					}else if(closestPoint === this.plannedPath.points.length - 1){
						this.plannedPath.insertSpline(mousePos, closestPoint - 1);
						this.highlightedPoint = closestPoint - 3;
					}else{
						let lower = Util.closestPointOnLine(this.plannedPath.points[closestPoint], this.plannedPath.points[closestPoint - 3], mousePos);
						let upper = Util.closestPointOnLine(this.plannedPath.points[closestPoint], this.plannedPath.points[closestPoint + 3], mousePos);
						let lowerDist = Util.distanceBetweenPoints(lower, mousePos);
						let upperDist = Util.distanceBetweenPoints(upper, mousePos);
						if(lowerDist < upperDist){
							this.plannedPath.insertSpline(mousePos, closestPoint - 1);
							this.highlightedPoint = closestPoint;
						}else{
							this.plannedPath.insertSpline(mousePos, closestPoint + 2);
							this.highlightedPoint = closestPoint + 3;
						}
					}
					this.update();
					this.saveHistory();
				}
			}
		});
		this.canvas.addEventListener('mouseup', (evt) => {
			if (this.pointDragIndex !== -1 || this.holonomicDragIndex !== -1) {
				this.saveHistory();
			}
			this.pointDragIndex = -1;
			this.holonomicDragIndex = -1;
			this.highlightedPoint = -1;
			this.highlightedHolonomicPoint = -1;
			this.update();
		});
	}

	flipPathY() {
		for (let i = 0; i < this.plannedPath.numPoints(); i++) {
			this.plannedPath.get(i).y = this.height - this.plannedPath.get(i).y;
		}
		this.update();
		this.saveHistory();
	}

	flipPathX() {
		for (let i = 0; i < this.plannedPath.numPoints(); i++) {
			this.plannedPath.get(i).x = this.width - this.plannedPath.get(i).x;
		}
		this.update();
		this.saveHistory();
	}

	/**
	 * Update all point velocities that are one value to another.
	 * Used when the robot max velocity is changed so point velocities
	 * that are the max should be updated as well
	 * @param oldValue
	 * @param newValue
	 */
	updateVelocities(oldValue, newValue) {
		for (let i = 0; i < this.plannedPath.velocities.length; i++) {
			if (this.plannedPath.velocities[i] === oldValue || this.plannedPath.velocities[i] > newValue) {
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
		const g = this.canvas.getContext('2d');
		g.clearRect(0, 0, this.canvas.width, this.canvas.height);
	}

	/**
	 * Draw the canvas. This draws the background image and the path/points
	 */
	draw() {
		const g = this.canvas.getContext('2d');

		//draw field
		if(preferences.gameYear == 21){
			g.drawImage(this.image, 75, 75, 1050, 525);
		}else{
			g.drawImage(this.image, 0, 50);
		}

		if(preferences.driveTrain == 'holonomic'){
			this.drawPathHolonomic();
		}else{
			this.drawPathSkidSteer();
		}
	}

	drawPathSkidSteer(){
		const g = this.canvas.getContext('2d');

		//draw path line
		g.lineWidth = 3;
		g.strokeStyle = '#eeeeee';
		g.imageSmoothingEnabled = false;
		g.beginPath();
		const angle = Math.atan2(this.plannedPath.points[1].y - this.plannedPath.points[0].y, this.plannedPath.points[1].x - this.plannedPath.points[0].x);
		const startL = new Vector2(this.plannedPath.points[0].x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), this.plannedPath.points[0].y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
		const startR = new Vector2(this.plannedPath.points[0].x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), this.plannedPath.points[0].y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
		g.moveTo(startL.x, startL.y);
		for (let i = 0; i < this.plannedPath.numSplines(); i++) {
			const points = this.plannedPath.getPointsInSpline(i);

			for (let d = 0; d <= 1; d += 0.01) {
				const p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
				const p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
				let angle = Math.atan2(p1.y - p0.y, p1.x - p0.x);
				const p1L = new Vector2(p1.x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), p0.y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));

				g.lineTo(p1L.x, p1L.y);
			}
		}
		g.moveTo(startR.x, startR.y);
		for (let i = 0; i < this.plannedPath.numSplines(); i++) {
			const points = this.plannedPath.getPointsInSpline(i);
			for (let d = 0; d <= 1; d += 0.01) {
				const p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
				const p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
				const angle = Math.atan2(p1.y - p0.y, p1.x - p0.x);
				const p1R = new Vector2(p1.x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), p0.y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));

				g.lineTo(p1R.x, p1R.y);
			}
		}
		g.stroke();

		//draw control lines
		g.strokeStyle = '#000000';
		g.lineWidth = 2.5;
		g.beginPath();
		for (let i = 0; i < this.plannedPath.numSplines(); i++) {
			const points = this.plannedPath.getPointsInSpline(i);
			g.moveTo(points[0].x, points[0].y);
			g.lineTo(points[1].x, points[1].y);
			g.moveTo(points[2].x, points[2].y);
			g.lineTo(points[3].x, points[3].y);
		}
		g.stroke();

		//draw points and perimeter
		const points = this.plannedPath.points;
		for (let i = 0; i < points.length; i++) {
			g.lineWidth = 3;
			if (i === 0) {
				const angle = Math.atan2(points[i + 1].y - points[i].y, points[i + 1].x - points[i].x);
				const l = new Vector2(points[i].x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				const r = new Vector2(points[i].x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				g.fillStyle = "#388e3c";
				g.strokeStyle = "#388e3c";
				this.drawRobotPerimeter(l, r);
			} else if (i === points.length - 1) {
				const angle = Math.atan2(points[i - 1].y - points[i].y, points[i - 1].x - points[i].x);
				const l = new Vector2(points[i].x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				const r = new Vector2(points[i].x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				g.fillStyle = "#d32f2f";
				g.strokeStyle = "#d32f2f";
				this.drawRobotPerimeter(l, r);
			} else {
				g.fillStyle = '#FFFFFF';
			}
			if (i === this.highlightedPoint) {
				g.fillStyle = '#ffeb3b';
			}
			g.strokeStyle = '#000000';
			g.beginPath();
			g.arc(points[i].x, points[i].y, 8, 2 * Math.PI, 0);
			g.fill();
			g.stroke();
		}
	}

	drawPathHolonomic(){
		const g = this.canvas.getContext('2d');

		//draw path line
		g.lineWidth = 3;
		g.strokeStyle = '#eeeeee';
		g.imageSmoothingEnabled = false;
		g.beginPath();
		g.moveTo(this.plannedPath.points[0].x, this.plannedPath.points[0].y);
		for (let i = 0; i < this.plannedPath.numSplines(); i++) {
			const points = this.plannedPath.getPointsInSpline(i);

			for (let d = 0; d <= 1; d += 0.01) {
				const p = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
				g.lineTo(p.x, p.y);
			}
		}
		g.stroke();

		//draw control lines
		g.strokeStyle = '#000000';
		g.lineWidth = 2.5;
		g.beginPath();
		for (let i = 0; i < this.plannedPath.numSplines(); i++) {
			const points = this.plannedPath.getPointsInSpline(i);
			g.moveTo(points[0].x, points[0].y);
			g.lineTo(points[1].x, points[1].y);
			g.moveTo(points[2].x, points[2].y);
			g.lineTo(points[3].x, points[3].y);
		}
		g.stroke();

		//draw points and perimeter
		const points = this.plannedPath.points;
		for (let i = 0; i < points.length; i++) {
			g.lineWidth = 3;

			if (i % 3 === 0) {
				const angle = this.plannedPath.getHolonomicAngle(i) * (Math.PI / 180);
				const l = new Vector2(points[i].x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				const r = new Vector2(points[i].x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle)), points[i].y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle)));
				if(i === points.length - 1){
					g.fillStyle = "#d32f2f";
					g.strokeStyle = "#d32f2f";
				}else if(i === 0){
					g.fillStyle = "#388e3c";
					g.strokeStyle = "#388e3c";
				}else{
					g.fillStyle = "#ffffff";
					g.strokeStyle = "#ffffff";
				}
				this.drawRobotPerimeter(l, r);
			} else {
				g.fillStyle = '#FFFFFF';
			}
			if (i === this.highlightedPoint) {
				g.fillStyle = '#ffeb3b';
			}
			g.strokeStyle = '#000000';
			g.beginPath();
			g.arc(points[i].x, points[i].y, 8, 2 * Math.PI, 0);
			g.fill();
			g.stroke();
		}

		this.drawHolonomicPoints();
	}

	/**
	 * Helper method to draw the outline of a robot
	 * @param left The left-middle point of the robot
	 * @param right The right-middle point of the robot
	 */
	drawRobotPerimeter(left, right) {
		const g = this.canvas.getContext('2d');
		const angle = Math.atan2(left.y - right.y, left.x - right.x);
		const halfLength = preferences.robotLength / 2;
		const frontLeftX = (left.x + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		const frontLeftY = (left.y - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		const backLeftX = (left.x - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		const backLeftY = (left.y + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		const frontRightX = (right.x + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		const frontRightY = (right.y - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		const backRightX = (right.x - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angle));
		const backRightY = (right.y + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angle));
		g.beginPath();
		g.moveTo(backLeftX, backLeftY);
		g.lineTo(frontLeftX, frontLeftY);
		g.lineTo(frontRightX, frontRightY);
		g.lineTo(backRightX, backRightY);
		g.lineTo(backLeftX, backLeftY);
		g.stroke();
	}

	drawHolonomicPreviewPerimeter(center, angle) {
		const g = this.canvas.getContext('2d');
		const angleRadians = angle * (Math.PI / 180);
		const halfLength = preferences.robotLength / 2;
		const l = new Vector2(center.x + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angleRadians)), center.y - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angleRadians)));
		const r = new Vector2(center.x - (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angleRadians)), center.y + (preferences.wheelbaseWidth / 2 * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angleRadians)));
		const frontLeftX = (l.x + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angleRadians));
		const frontLeftY = (l.y + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angleRadians));
		const backLeftX = (l.x - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angleRadians));
		const backLeftY = (l.y - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angleRadians));
		const frontRightX = (r.x + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angleRadians));
		const frontRightY = (r.y + halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angleRadians));
		const backRightX = (r.x - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.cos(angleRadians));
		const backRightY = (r.y - halfLength * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * Math.sin(angleRadians));
		g.beginPath();
		g.moveTo(backLeftX, backLeftY);
		g.lineTo(frontLeftX, frontLeftY);
		g.lineTo(frontRightX, frontRightY);
		g.lineTo(backRightX, backRightY);
		g.lineTo(backLeftX, backLeftY);
		g.stroke();
		const halfLengthPx = (preferences.robotLength/2) * (preferences.useMetric ? Util.pixelsPerMeter : Util.pixelsPerFoot);
		let holoPointX = center.x + (halfLengthPx * Math.cos(angleRadians));
		let holoPointY = center.y + (halfLengthPx * Math.sin(angleRadians));
		g.beginPath();
		g.arc(holoPointX, holoPointY, 6, 2 * Math.PI, 0);
		g.fill();
	}

	drawHolonomicPoints(){
		const g = this.canvas.getContext('2d');
		for(let i = 0; i < this.plannedPath.numPoints(); i+=3){
			g.beginPath();
			g.strokeStyle = '#000000';
			if (i === this.highlightedHolonomicPoint) {
				g.fillStyle = '#ffeb3b';
			}else{
				g.fillStyle = '#222222';
			}
			const angle = this.plannedPath.getHolonomicAngle(i) * (Math.PI / 180);
			const halfLength = (preferences.robotLength/2) * (preferences.useMetric ? Util.pixelsPerMeter : Util.pixelsPerFoot);
			let holoPointX = this.plannedPath.points[i].x + (halfLength * Math.cos(angle));
			let holoPointY = this.plannedPath.points[i].y + (halfLength * Math.sin(angle));
			g.arc(holoPointX, holoPointY, 6, 2 * Math.PI, 0);
			g.fill();
			g.stroke();
		}
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
	 * @param centerSegments The generated path for the center
	 */
	previewPath(leftSegments, rightSegments, centerSegments) {
		var i = 0;
		this.previewing = true;
		var interval = setInterval(() => {
			if (i < centerSegments.length) {
				var g = this.canvas.getContext('2d');
				this.clear();
				if(preferences.gameYear == 21){
					g.drawImage(this.image, 75, 75, 1050, 525);
				}else{
					g.drawImage(this.image, 0, 50);
				}
				g.strokeStyle = '#eeeeee';
				g.fillStyle = '#eeeeee';
				if(preferences.driveTrain == 'holonomic'){
					const x = centerSegments[i].x * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].x;
					const y = centerSegments[i].y * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].y;
					this.drawHolonomicPreviewPerimeter(new Vector2(x, y), centerSegments[i].holonomicAngle);
				}else {
					var leftX = leftSegments[i].x * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].x;
					var leftY = leftSegments[i].y * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].y;
					var rightX = rightSegments[i].x * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].x;
					var rightY = rightSegments[i].y * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + this.plannedPath.points[0].y;
					this.drawRobotPerimeter(new Vector2(leftX, leftY), new Vector2(rightX, rightY));
				}
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