const {Util, Vector2} = require('./js/util.js');
const ipc = require('electron').ipcRenderer;
const {remote, clipboard} = require('electron');
const {dialog, getGlobal} = require('electron').remote;
const homeDir = require('os').homedir();
const log = require('electron-log');
const fs = require('fs');
const trackEvent = getGlobal('trackEvent');
const unhandled = require('electron-unhandled');
unhandled({logger: log.error, showDialog: true});
const joinStep = 0.00001;

// Generate the path when the main process requests it
ipc.on('generate-path', function (event, data) {
	try {
		if (data.preview) {
			generateAndSendSegments(data.points, data.preferences);
		}else if(data.deploy){
			generateAndDeploy(data.points, data.preferences, data.reverse);
		} else if (data.preferences.p_outputType == 0) {
			generateAndSave(data.points, data.preferences, data.reverse);
		} else {
			generateAndCopy(data.points, data.preferences, data.reverse);
		}
	} catch (err) {
		trackEvent('Error', 'Generate Error');
		log.error(err);
	} finally {
		var window = remote.getCurrentWindow();
		window.close();
	}
});

/**
 * Generate the path and send the segments back for a preview
 * @param points The path points
 * @param preferences The robot preferences
 */
function generateAndSendSegments(points, preferences) {
	ipc.send('generating');
	var robotPath = new RobotPath(points, preferences);
	ipc.send('preview-segments', {
		left: robotPath.left.segments,
		right: robotPath.right.segments
	});
}

/**
 * Generate the path and upload the files to the roborio
 * @param points The path points
 * @param preferences The robot preferences
 * @param reverse Should the robot drive backwards
 */
function generateAndDeploy(points, preferences, reverse) {
	ipc.send('generating');
	var robotPath = new RobotPath(points, preferences);
	var outL = '';
	var outR = '';
	if (reverse) {
		outL = robotPath.right.formatCSV(reverse, preferences.p_outputFormat);
		outR = robotPath.left.formatCSV(reverse, preferences.p_outputFormat);
	} else {
		outL = robotPath.left.formatCSV(reverse, preferences.p_outputFormat);
		outR = robotPath.right.formatCSV(reverse, preferences.p_outputFormat);
	}
	ipc.send('deploy-segments', {
		left: outL,
		right: outR,
		name: preferences.currentPathName,
		team: preferences.p_teamNumber,
		path: preferences.p_rioPathLocation
	});
}

/**
 * Generate the path and copy the output arrays to the clipboard
 * @param points The path points
 * @param preferences The robot preferences
 * @param reverse Should the robot drive backwards
 */
function generateAndCopy(points, preferences, reverse) {
	trackEvent('Generation', 'Generate and Copy', undefined, parseInt(preferences.p_outputType));
	ipc.send('generating');
	var robotPath = new RobotPath(points, preferences);
	var out;
	if (preferences.p_outputType == 1) {
		if (reverse) {
			out = robotPath.right.formatJavaArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat) + '\n\n    ' +
				robotPath.left.formatJavaArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat);
		} else {
			out = robotPath.left.formatJavaArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat) + '\n\n    ' +
				robotPath.right.formatJavaArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat);
		}
	} else if (preferences.p_outputType == 2) {
		if (reverse) {
			out = robotPath.right.formatCppArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat) + '\n\n    ' +
				robotPath.left.formatCppArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat);
		} else {
			out = robotPath.left.formatCppArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat) + '\n\n    ' +
				robotPath.right.formatCppArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat);
		}
	} else if (preferences.p_outputType == 3) {
		if (reverse) {
			out = robotPath.right.formatPythonArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat) + '\n\n' +
				robotPath.left.formatPythonArray(preferences.currentPathName + 'Right', reverse);
		} else {
			out = robotPath.left.formatPythonArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat) + '\n\n' +
				robotPath.right.formatPythonArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat);
		}
	}
	clipboard.writeText(out);
	ipc.send('copied-to-clipboard', preferences.currentPathName);
}

/**
 * Generate the path and save the files
 * @param points The path points
 * @param preferences The robot preferences
 * @param reverse Should the robot drive backwards
 */
function generateAndSave(points, preferences, reverse) {
	trackEvent('Generation', 'Generate and Save');
	var filePath = preferences.p_lastGenerateDir;
	if (filePath == 'none') {
		filePath = homeDir;
	}

	var filename = dialog.showOpenDialog({
		title: 'Generate Path',
		defaultPath: filePath,
		buttonLabel: 'Generate',
		properties: ['openDirectory']
	});
	if (filename != undefined) {
		filename = filename[0];
		ipc.send('update-last-generate-dir', filename);
		log.info(filename);

		ipc.send('generating');
		var robotPath = new RobotPath(points, preferences);
		var outL = '';
		var outR = '';
		if (reverse) {
			outL = robotPath.right.formatCSV(reverse, preferences.p_outputFormat);
			outR = robotPath.left.formatCSV(reverse, preferences.p_outputFormat);
		} else {
			outL = robotPath.left.formatCSV(reverse, preferences.p_outputFormat);
			outR = robotPath.right.formatCSV(reverse, preferences.p_outputFormat);
		}

		fs.writeFileSync(filename + '/' + preferences.currentPathName + '_left.csv', outL, 'utf8');
		fs.writeFileSync(filename + '/' + preferences.currentPathName + '_right.csv', outR, 'utf8');
		ipc.send('files-saved', preferences.currentPathName);
	}
}

/**
 * Creates a segment group of many points on the curve from the list of anchor and control points
 * @param points The path points
 * @param step The step to use to interpolate the curve
 * @returns The points on the curve
 */
function join(points, step) {
	log.info('    Joining splines... ');
	var start = new Date().getTime();
	var s = new SegmentGroup();
	var numSplines = ((points.length - 4) / 3) + 1;
	for (var i = 0; i < numSplines; i++) {
		var pointsInSpline = new Array(points[i * 3], points[i * 3 + 1], points[i * 3 + 2], points[i * 3 + 3]);
		for (var d = step; d <= 1.0; d += step) {
			var p = Util.cubicCurve(pointsInSpline[0], pointsInSpline[1], pointsInSpline[2], pointsInSpline[3], d);
			var seg = new Segment();
			seg.x = p.x;
			seg.y = p.y;
			s.add(seg);
		}
	}
	log.info('        Num segments per spline: ' + (s.segments.length / numSplines));
	log.info('        Total segments: ' + s.segments.length);
	log.info('    DONE IN: ' + (new Date().getTime() - start) + 'ms');
	return s;
}

class RobotPath {
	constructor(points, preferences) {
		log.info('Generating path...');
		var start = new Date().getTime();
		this.path = new Path(join(points, joinStep), points[0], preferences.p_useMetric ? Util.pixelsPerMeter : Util.pixelsPerFoot);
		this.pathSegments = this.path.group;
		this.timeSegments = new SegmentGroup();
		this.left = new SegmentGroup();
		this.right = new SegmentGroup();
		this.maxVel = preferences.p_maxVel;
		this.maxAcc = preferences.p_maxAcc;
		this.mu = preferences.p_mu;
		this.wheelbaseWidth = preferences.p_wheelbaseWidth;
		this.timeStep = preferences.p_timeStep;
		this.calculateMaxVelocity();
		this.calculateVelocity();
		this.splitGroupByTime();
		this.recalculateValues();
		this.calculateHeading();
		this.splitLeftRight();
		var time = new Date().getTime() - start;
		log.info('DONE IN: ' + time + 'ms');
		trackEvent('Generation', 'Generate', undefined, time);
	}

    /**
	 * Calculate the max velocity of the robot along every point on the curve
     */
	calculateMaxVelocity() {
		log.info('    Calculating max velocity on curve...');
		var start = new Date().getTime();
		for (var i = 0; i < this.pathSegments.segments.length; i++) {
			var r;
			if (i == this.path.group.segments.length - 1) {
				r = this.calculateCurveRadius(i - 2, i - 1, i);
			} else if (i == 0) {
				r = this.calculateCurveRadius(i, i + 1, i + 2);
			} else {
				r = this.calculateCurveRadius(i - 1, i, i + 1);
			}
			if (!isFinite(r) || isNaN(r)) {
				this.pathSegments.segments[i].vel = this.maxVel;
			} else {
				// Calculate max velocity on curve given the coefficient of friction between wheels and carpet
				var maxVCurve = Math.sqrt(this.mu * 9.8 * r);
				this.pathSegments.segments[i].vel = Math.min(maxVCurve, this.maxVel);
			}
		}
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
	}

    /**
	 * Helper method to calculate the curve radius anywhere on the path, given 3 points
     * @param i0 Point 1 index
     * @param i1 Point 2 index
     * @param i2 Point 3 index
     * @returns The curve radius
     */
	calculateCurveRadius(i0, i1, i2) {
		var a = this.pathSegments.segments[i0];
		var b = this.pathSegments.segments[i1];
		var c = this.pathSegments.segments[i2];
		var ab = Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
		var bc = Math.sqrt((c.x - b.x) * (c.x - b.x) + (b.y - c.y) * (b.y - c.y));
		var ac = Math.sqrt((c.x - a.x) * (c.x - a.x) + (c.y - a.y) * (c.y - a.y));
		var p = (ab + bc + ac) / 2;
		var area = Math.sqrt(Math.abs(p * (p - ab) * (p - bc) * (p - ac)));
		var r = (ab * bc * ac) / (4 * area);
		// things get weird where 2 splines meet, and will give a very small radius
		// therefore, ignore those points
		if (i2 % Math.round(1/joinStep) == 0) {
			r = this.calculateCurveRadius(i0 - 1, i0, i1);
		}
		// Return radius on outside of curve
		return r + (this.wheelbaseWidth / 2);
	}

    /**
	 * Calculate the position, velocity, acceleration, etc at every point on the curve
     */
	calculateVelocity() {
		log.info('    Calculating velocity...');
		var start = new Date().getTime();
		var p = this.pathSegments.segments;
		p[0].vel = 0;
		var time = 0;
		var start1 = new Date().getTime();
		for (var i = 1; i < p.length; i++) {
			var v0 = p[i - 1].vel;
			var dx = p[i - 1].dx;
			if (dx > 0) {
				var vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * this.maxAcc * dx));
				var v = Math.min(vMax, p[i].vel);
				if (isNaN(v)) {
					v = p[i - 1].vel;
				}
				p[i].vel = v;
			} else {
				p[i].vel = p[i - 1].vel;
			}
		}
		log.info('1: ' + (new Date().getTime() - start1) + 'ms');
		var start2 = new Date().getTime();
		p[p.length - 1].vel = 0;
		for (i = p.length - 2; i > 1; i--) {
			var v0 = p[i + 1].vel;
			var dx = p[i + 1].dx;
			var vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * this.maxAcc * dx));
			p[i].vel = Math.min((isNaN(vMax) ? this.maxVel : vMax), p[i].vel);
		}
		log.info('2: ' + (new Date().getTime() - start2) + 'ms');
		var start3 = new Date().getTime();
		for (var i = 1; i < p.length; i++) {
			var v = p[i].vel;
			var dx = p[i - 1].dx;
			var v0 = p[i - 1].vel;
			time += (2 * dx) / (v + v0);
			if (isNaN(time)) {
				time = 0;
			}
			p[i].time = time;
		}
		log.info('3: ' + (new Date().getTime() - start3) + 'ms');
		var start4 = new Date().getTime();
		for (var i = 1; i < p.length; i++) {
			var dt = p[i].time - p[i - 1].time;
			if (dt == 0 || !isFinite(dt)) {
				p.splice(i, 1);
			}
		}
		log.info('4: ' + (new Date().getTime() - start4) + 'ms');
		var start5 = new Date().getTime();
		for (var i = 1; i < p.length; i++) {
			var dv = p[i].vel - p[i - 1].vel;
			var dt = p[i].time - p[i - 1].time;
			if (dt == 0) {
				p[i].acc = 0;
			} else {
				p[i].acc = dv / dt;
			}
		}
		log.info('5: ' + (new Date().getTime() - start5) + 'ms');
		this.pathSegments.segments = p;
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
	}

    /**
	 * Split the generated path into a list of points at the correct time interval
     */
	splitGroupByTime() {
		log.info('    Splitting segments by time...');
		var start = new Date().getTime();
		var segNum = 0;
		var numMessySeg = 0;
		var p = this.pathSegments.segments;
		for (var i = 0; i < p.length; i++) {
			if (i == 0) {
				this.timeSegments.segments.push(p[0]);
				segNum++;
			}

			if (p[i].time >= this.segmentTime(segNum)) {
				this.timeSegments.segments.push(p[i]);
				this.timeSegments.segments[this.timeSegments.segments.length - 1].dt = this.timeSegments.segments[this.timeSegments.segments.length - 1].time - this.timeSegments.segments[this.timeSegments.segments.length - 2].time;
				if (Math.abs(p[i].time - this.segmentTime(segNum)) > this.timeStep + 0.00005) {
					numMessySeg++;
				}
				segNum++;
			}
		}
		log.info('        Divided into: ' + segNum + ' segments, with ' + numMessySeg + ' messy segments.');
		log.info('        Stats:');
		log.info('            Time: ' + this.timeSegments.segments[this.timeSegments.segments.length - 1].time + 's');
		log.info('            Distance: ' + this.timeSegments.segments[this.timeSegments.segments.length - 1].pos + 'ft');
		log.info('            Average velocity: ' + this.timeSegments.segments[this.timeSegments.segments.length - 1].pos / this.timeSegments.segments[this.timeSegments.segments.length - 1].time + 'ft/s');
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
	}

    /**
	 * Calculate the heading of the robot at every point on the path
     */
	calculateHeading() {
		log.info('    Calculating robot heading...');
		var start = new Date().getTime();
		for (var i = 0; i < this.timeSegments.segments.length; i++) {
			var angle;
			if (i == 0) {
				angle = Math.atan2(-this.timeSegments.segments[i].y, -this.timeSegments.segments[i].x) * (180 / Math.PI);
			} else {
				angle = Math.atan2(this.timeSegments.segments[i - 1].y - this.timeSegments.segments[i].y, this.timeSegments.segments[i - 1].x - this.timeSegments.segments[i].x) * (180 / Math.PI);
			}
			angle -= 180;
			if(angle < -180){
				angle += 360;
			}else if(angle > 180){
				angle -= 360;
			}
			this.timeSegments.segments[i].heading = angle;
		}
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
	}

    /**
	 * Split the path into a left and right path for each side of the robot
     */
	splitLeftRight() {
		log.info('    Splitting left and right robot paths...');
		var start = new Date().getTime();
		var w = this.wheelbaseWidth / 2;
		for (var i = 0; i < this.timeSegments.segments.length; i++) {
			var seg = this.timeSegments.segments[i];
			var left = new Segment();
			var right = new Segment();

			var cos_angle = Math.cos(seg.heading * (Math.PI/180));
			var sin_angle = Math.sin(seg.heading * (Math.PI/180));

			left.x = seg.x - (w * sin_angle);
			left.y = seg.y + (w * cos_angle);
			left.heading = seg.heading;
			left.dydx = seg.dydx;
			left.dt = seg.dt;
			left.time = seg.time;

			if (i > 0) {
				var last = this.left.segments[i - 1];
				var distance = Math.sqrt((left.x - last.x) * (left.x - last.x) + (left.y - last.y) * (left.y - last.y));

				left.pos = last.pos + distance;
				left.vel = distance / seg.dt;
				left.acc = (left.vel - last.vel) / seg.dt;
			}

			right.x = seg.x + (w * sin_angle);
			right.y = seg.y - (w * cos_angle);
			right.heading = seg.heading;
			right.dydx = seg.dydx;
			right.dt = seg.dt;
			right.time = seg.time;

			if (i > 0) {
				var last = this.right.segments[i - 1];
				var distance = Math.sqrt((right.x - last.x) * (right.x - last.x) + (right.y - last.y) * (right.y - last.y));

				right.pos = last.pos + distance;
				right.vel = distance / seg.dt;
				right.acc = (right.vel - last.vel) / seg.dt;
			}

			this.left.segments.push(left);
			this.right.segments.push(right);
		}
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
	}

    /**
	 * Recalculate all the values for validation
     */
	recalculateValues() {
		log.info('    Verifying values...');
		var start = new Date().getTime();
		for (var i = 1; i < this.timeSegments.segments.length; i++) {
			var now = this.timeSegments.segments[i];
			var last = this.timeSegments.segments[i - 1];
			var dt = now.time - last.time;
			now.vel = (now.pos - last.pos) / dt;
			now.acc = (now.vel - last.vel) / dt;
		}
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
	}

    /**
	 * Get the time for a segment
     * @param segNum The index of the segment
     * @returns The time
     */
	segmentTime(segNum) {
		return segNum * this.timeStep;
	}
}

class Path {
	constructor(s, p0, pixelsPerUnit) {
		this.length = 0.0;
		this.p0 = p0;
		this.x = [];
		this.y = [];
		this.l = [];
		this.inGroup = s;
		this.group = new SegmentGroup();
		this.makePath(pixelsPerUnit);
	}

    /**
	 * Make the pre-generation path
     */
	makePath(pixelsPerUnit) {
		var start = new Date().getTime();
		log.info('Generating path...');
		this.makeScaledLists(pixelsPerUnit);
		this.calculateLength();
		this.createSegments();
		log.info('DONE IN: ' + (new Date().getTime() - start) + 'ms');
	}

    /**
	 * Make x and y lists and convert the values from pixels to feet
     */
	makeScaledLists(pixelsPerUnit) {
		for (var i = 0; i < this.inGroup.segments.length; i++) {
			this.x.push((this.inGroup.segments[i].x - this.p0.x) / pixelsPerUnit);
			this.y.push((this.inGroup.segments[i].y - this.p0.y) / pixelsPerUnit);
		}
	}

    /**
	 * Calculate the length of the path
     */
	calculateLength() {
		log.info('    Calculating length...');
		var start = new Date().getTime();
		for (var i = 1; i < this.x.length; i++) {
			var dx = this.x[i] - this.x[i - 1];
			var dy = this.y[i] - this.y[i - 1];
			var c = Math.sqrt((dx * dx) + (dy * dy));
			this.length += c;

			var prevLength = 0.0;
			if (i != 1) {
				prevLength = this.l[this.l.length - 1];
			}
			this.l.push(c + prevLength);
		}
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms. Length: ' + this.length + 'ft');
	}

    /**
	 * Create a segment for ech point on the path
     */
	createSegments() {
		log.info('    Calculating segments...');
		var start = new Date().getTime();
		for (var i = 0; i < this.x.length - 1; i++) {
			var s = i;
			var s2 = i + 1;
			var seg = new Segment();
			seg.x = this.x[s];
			seg.y = this.y[s];
			seg.pos = this.l[s];
			seg.dydx = this.derivative(s, s2);
			if (i != 0) {
				seg.dx = seg.pos - this.group.segments[this.group.segments.length - 1].pos;
			}
			this.group.segments.push(seg);
		}
		log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms. Created ' + this.group.segments.length + ' segments.');
	}

	derivative(t1, t2) {
		return Util.slope(new Vector2(this.x[t1], this.y[t1]), new Vector2(this.x[t2], this.y[t2]));
	}
}

class SegmentGroup {
	constructor() {
		this.segments = [];
	}
	
	formatCSV(reverse, format) {
		var str = '';
		for (var i = 0; i < this.segments.length; i++) {
			str += this.formatSegment(i, reverse, format);
			if (i < this.segments.length - 1) {
				str += '\n';
			}
		}
		return str;
	}

	formatJavaArray(arrayName, reverse, format) {
		var str = 'public static double[][] ' + arrayName + ' = new double[][] {\n';
		for (var i = 0; i < this.segments.length; i++) {
			str += '        {' + this.formatSegment(i, reverse, format) + '}' + ((i < this.segments.length - 1) ? ',\n' : '\n');
		}
		str += '    }';
		return str;
	}

	formatCppArray(arrayName, reverse, format) {
		var str = 'double ' + arrayName + '[][] = {\n';
		for (var i = 0; i < this.segments.length; i++) {
			str += '        {' + this.formatSegment(i, reverse, format) + '}' + ((i < this.segments.length - 1) ? ',\n' : '\n');
		}
		str += '    }';
		return str;
	}

	formatPythonArray(arrayName, reverse, format) {
		var str = arrayName + ' = [\n';
		for (var i = 0; i < this.segments.length; i++) {
			str += '    [' + this.formatSegment(i, reverse, format) + ((i < this.segments.length - 1) ? '],\n' : ']]');
		}
		return str;
	}

	formatSegment(index, reverse, format) {
		var s = this.segments[index];
		var n = (reverse) ? -1 : 1;
		var ret = format.replace(/p/g, (Math.round(s.pos * 10000) / 10000 * n));
		ret = ret.replace(/v/g, (Math.round(s.vel * 10000) / 10000 * n).toString());
		ret = ret.replace(/a/g, (Math.round(s.acc * 10000) / 10000 * n).toString());
		ret = ret.replace(/h/g, (Math.round(s.heading * 10000) / 10000 * n).toString());
		return ret;
	}

	add(seg) {
		this.segments.push(seg);
	}
}

class Segment {
	constructor() {
		this.x = 0.0;
		this.y = 0.0;
		this.heading = 0.0;
		this.pos = 0.0;
		this.vel = 0.0;
		this.acc = 0.0;
		this.dydx = 0.0;
		this.dt = 0.0;
		this.time = 0;
		this.dx = 0.0;
	}
}

module.exports.generateAndSave = generateAndSave;
module.exports.Segment = Segment;
module.exports.SegmentGroup = SegmentGroup;