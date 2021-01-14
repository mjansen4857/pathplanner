const {Util, Vector2} = require('./util.js');
const {Segment, SegmentGroup} = require('./segments.js');
const log = require('electron-log');
const joinStep = 0.00001;

/**
 * Creates a segment group of many points on the curve from the list of anchor and control points
 * @param points The path points
 * @param holonomicAngles The angles for holonomic driving
 * @param step The step to use to interpolate the curve
 * @param noLogging true if logging info should be skipped
 * @returns The points on the curve
 */
function join(points, holonomicAngles, step, noLogging) {
    if(!noLogging) log.info('    Joining splines... ');
    const start = new Date().getTime();
    let s = new SegmentGroup();
    const numSplines = ((points.length - 4) / 3) + 1;
    for (let i = 0; i < numSplines; i++) {
        const pointsInSpline = [points[i * 3], points[i * 3 + 1], points[i * 3 + 2], points[i * 3 + 3]];
        for (let d = step; d <= 1.0; d += step) {
            const p = Util.cubicCurve(pointsInSpline[0], pointsInSpline[1], pointsInSpline[2], pointsInSpline[3], d);
            let seg = new Segment();
            seg.x = p.x;
            seg.y = p.y;
            // Interpolate the holonomic angle via a sine curve
            // const interpolationFactor = (Math.sin((d * Math.PI) - (Math.PI / 2)) + 1) / 2;
            const interpolationFactor = d;
            let deltaAngle = holonomicAngles[i + 1] - holonomicAngles[i];
            if(Math.abs(deltaAngle) > 180){
                if(deltaAngle < 0){
                    deltaAngle = 180 + (deltaAngle % 180);
                }else{
                    deltaAngle = -180 + (deltaAngle % 180);
                }
            }
            seg.holonomicAngle = holonomicAngles[i] + (interpolationFactor * (deltaAngle));
            s.add(seg);
        }
    }
    if(!noLogging) {
        log.info('        Num segments per spline: ' + (s.segments.length / numSplines));
        log.info('        Total segments: ' + s.segments.length);
        log.info('    DONE IN: ' + (new Date().getTime() - start) + 'ms');
    }
    return s;
}

class RobotPath {
    constructor(points, velocities, holonomicAngles, preferences, reverse, noLogging) {
        this.noLogging = noLogging;
        if(!this.noLogging) log.info('Generating path...');
        const start = new Date().getTime();
        this.xPixelOffset = (preferences.p_gameYear === '20') ? Util.xOffset20 : Util.xOffsetNormal;
        log.info(Util.pixelsPerFoot, preferences.gameYear);
        let pixelsPerUnit = preferences.p_useMetric ? Util.pixelsPerMeter : Util.pixelsPerFoot;
        if(preferences.p_gameYear == 21){
            pixelsPerUnit = preferences.p_useMetric ? Util.pixelsPerMeter21 : Util.pixelsPerFoot21;
        }
        this.path = new Path(join(points, holonomicAngles, joinStep, noLogging), points[0], pixelsPerUnit, noLogging, this.xPixelOffset);
        this.velocities = velocities;
        this.holonomicAngles = holonomicAngles;
        this.pathSegments = this.path.group;
        this.timeSegments = new SegmentGroup();
        this.left = new SegmentGroup();
        this.right = new SegmentGroup();
        this.maxVel = preferences.maxVel;
        this.maxAcc = preferences.maxAcc;
        this.wheelbaseWidth = preferences.p_wheelbaseWidth;
        this.timeStep = preferences.p_timeStep;
        this.reverse = reverse;
        this.isHolonomic = preferences.p_driveTrain == 'holonomic';
        this.calculateMaxVelocity();
        this.calculateVelocity();
        this.splitGroupByTime();
        this.recalculateValues();
        this.calculateHeading();
        this.splitLeftRight();
        const time = new Date().getTime() - start;
        if(!this.noLogging) log.info('DONE IN: ' + time + 'ms');
    }

    /**
     * Calculate the max velocity of the robot along every point on the curve
     */
    calculateMaxVelocity() {
        if(!this.noLogging) log.info('    Calculating max velocity on curve...');
        const start = new Date().getTime();
        for (let i = 0; i < this.pathSegments.segments.length; i++) {
            let r;
            if (i === this.path.group.segments.length - 1) {
                r = this.calculateCurveRadius(i - 2, i - 1, i);
            } else if (i === 0) {
                r = this.calculateCurveRadius(i, i + 1, i + 2);
            } else {
                r = this.calculateCurveRadius(i - 1, i, i + 1);
            }
            this.pathSegments.segments[i].radius = r;

            if (!isFinite(r) || isNaN(r)) {
                this.pathSegments.segments[i].vel = this.maxVel;

                const numSegments = Math.round(1 / joinStep);
                if (i % numSegments >= numSegments - Math.round(numSegments / 4)) {
                    const index = i + (numSegments - (i % numSegments));
                    const velIndex = ((index - numSegments) / numSegments) + 1;
                    this.pathSegments.segments[i].vel = Math.min(this.pathSegments.segments[i].vel, (this.velocities[velIndex] === -1) ? this.maxVel : this.velocities[velIndex]);
                } else if (i % numSegments <= Math.round(numSegments / 4)) {
                    const index = i - (i % numSegments);
                    const velIndex = ((index - numSegments) / numSegments) + 1;
                    this.pathSegments.segments[i].vel = Math.min(this.pathSegments.segments[i].vel, (this.velocities[velIndex] === -1) ? this.maxVel : this.velocities[velIndex]);
                }
            } else {
                // Calculate max velocity on curve given the coefficient of friction between wheels and carpet
                // var g = 9.8;
                // var radius = this.useMetric ? r : r * 0.3048;
                // var maxVCurve = Math.sqrt(this.mu * g * radius);
                // if (!this.useMetric) maxVCurve *= 3.281;

                let maxVCurve = Math.sqrt(this.maxAcc * (r - this.wheelbaseWidth / 2));
                if(this.isHolonomic){
                    maxVCurve = Math.sqrt(this.maxAcc * r);
                }

                this.pathSegments.segments[i].vel = Math.min(maxVCurve, this.maxVel);

                const numSegments = Math.round(1 / joinStep);
                if (i % numSegments >= numSegments - Math.round(numSegments / 4)) {
                    const index = i + (numSegments - (i % numSegments));
                    const velIndex = ((index - numSegments) / numSegments) + 1;
                    this.pathSegments.segments[i].vel = Math.min(this.pathSegments.segments[i].vel, (this.velocities[velIndex] === -1) ? this.maxVel : this.velocities[velIndex]);
                } else if (i % numSegments <= Math.round(numSegments / 4)) {
                    const index = i - (i % numSegments);
                    const velIndex = ((index - numSegments) / numSegments) + 1;
                    this.pathSegments.segments[i].vel = Math.min(this.pathSegments.segments[i].vel, (this.velocities[velIndex] === -1) ? this.maxVel : this.velocities[velIndex]);
                }
            }
        }
        if(!this.noLogging) log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
    }

    /**
     * Helper method to calculate the curve radius anywhere on the path, given 3 points
     * @param i0 Point 1 index
     * @param i1 Point 2 index
     * @param i2 Point 3 index
     * @returns The curve radius
     */
    calculateCurveRadius(i0, i1, i2) {
        const a = this.pathSegments.segments[i0];
        const b = this.pathSegments.segments[i1];
        const c = this.pathSegments.segments[i2];
        const ab = Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
        const bc = Math.sqrt((c.x - b.x) * (c.x - b.x) + (b.y - c.y) * (b.y - c.y));
        const ac = Math.sqrt((c.x - a.x) * (c.x - a.x) + (c.y - a.y) * (c.y - a.y));
        const p = (ab + bc + ac) / 2;
        const area = Math.sqrt(Math.abs(p * (p - ab) * (p - bc) * (p - ac)));
        let r = (ab * bc * ac) / (4 * area);
        // things get weird where 2 splines meet, and will give a very small radius
        // therefore, ignore those points
        if (i2 % Math.round(1 / joinStep) === 0) {
            r = this.calculateCurveRadius(i0 - 1, i0, i1);
        }
        // Return radius on outside of curve
        return r + (this.wheelbaseWidth / 2);
    }

    /**
     * Calculate the position, velocity, acceleration, etc at every point on the curve
     */
    calculateVelocity() {
        if(!this.noLogging) log.info('    Calculating velocity...');
        const start = new Date().getTime();
        let p = this.pathSegments.segments;
        p[0].vel = 0;
        let time = 0;
        const start1 = new Date().getTime();
        for (let i = 1; i < p.length; i++) {
            const v0 = p[i - 1].vel;
            const dx = p[i - 1].dx;
            if (dx > 0) {
                const vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * this.maxAcc * dx));
                let v = Math.min(vMax, p[i].vel);
                if (isNaN(v)) {
                    v = p[i - 1].vel;
                }
                p[i].vel = v;
            } else {
                p[i].vel = p[i - 1].vel;
            }
        }
        if(!this.noLogging) log.info('1: ' + (new Date().getTime() - start1) + 'ms');
        const start2 = new Date().getTime();
        if(this.velocities[this.velocities.length - 1] === -1){
            p[p.length - 1].vel = 0;
        }
        for (let i = p.length - 2; i > 1; i--) {
            const v0 = p[i + 1].vel;
            const dx = p[i + 1].dx;
            const vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * this.maxAcc * dx));
            p[i].vel = Math.min((isNaN(vMax) ? this.maxVel : vMax), p[i].vel);
        }
        if(!this.noLogging) log.info('2: ' + (new Date().getTime() - start2) + 'ms');
        const start3 = new Date().getTime();
        for (let i = 1; i < p.length; i++) {
            const v = p[i].vel;
            const dx = p[i - 1].dx;
            const v0 = p[i - 1].vel;
            time += (2 * dx) / (v + v0);
            if (isNaN(time)) {
                time = 0;
            }
            p[i].time = time;
        }
        if(!this.noLogging) log.info('3: ' + (new Date().getTime() - start3) + 'ms');
        const start4 = new Date().getTime();
        for (let i = 1; i < p.length; i++) {
            const dt = p[i].time - p[i - 1].time;
            if (dt === 0 || !isFinite(dt)) {
                p.splice(i, 1);
            }
        }
        if(!this.noLogging) log.info('4: ' + (new Date().getTime() - start4) + 'ms');
        const start5 = new Date().getTime();
        for (let i = 1; i < p.length; i++) {
            const dv = p[i].vel - p[i - 1].vel;
            const dt = p[i].time - p[i - 1].time;
            if (dt === 0) {
                p[i].acc = 0;
            } else {
                p[i].acc = dv / dt;
            }
        }
        if(!this.noLogging) log.info('5: ' + (new Date().getTime() - start5) + 'ms');
        this.pathSegments.segments = p;
        if(!this.noLogging) log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
    }

    /**
     * Split the generated path into a list of points at the correct time interval
     */
    splitGroupByTime() {
        if(!this.noLogging) log.info('    Splitting segments by time...');
        const start = new Date().getTime();
        let segNum = 0;
        let numMessySeg = 0;
        const p = this.pathSegments.segments;
        for (let i = 0; i < p.length; i++) {
            if (i === 0) {
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
        if(!this.noLogging) {
            log.info('        Divided into: ' + segNum + ' segments, with ' + numMessySeg + ' messy segments.');
            log.info('        Stats:');
            log.info('            Time: ' + this.timeSegments.segments[this.timeSegments.segments.length - 1].time + 's');
            log.info('            Distance: ' + this.timeSegments.segments[this.timeSegments.segments.length - 1].pos + 'ft');
            log.info('            Average velocity: ' + this.timeSegments.segments[this.timeSegments.segments.length - 1].pos / this.timeSegments.segments[this.timeSegments.segments.length - 1].time + 'ft/s');
            log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
        }
    }

    /**
     * Calculate the heading of the robot at every point on the path
     */
    calculateHeading() {
        if(!this.noLogging) log.info('    Calculating robot heading...');
        const start = new Date().getTime();
        const startAngle = Math.atan2(-this.timeSegments.segments[0].y, -this.timeSegments.segments[0].x) * (180 / Math.PI) - 180;
        for (let i = 0; i < this.timeSegments.segments.length; i++) {
            let angle;
            if (i === 0) {
                angle = Math.atan2(-this.timeSegments.segments[i].y, -this.timeSegments.segments[i].x) * (180 / Math.PI);
            } else {
                angle = Math.atan2(this.timeSegments.segments[i - 1].y - this.timeSegments.segments[i].y, this.timeSegments.segments[i - 1].x - this.timeSegments.segments[i].x) * (180 / Math.PI);
            }
            this.timeSegments.segments[i].rawHeading = angle + 180;
            angle -= 180;
            if (angle < -180) {
                angle += 360;
            } else if (angle > 180) {
                angle -= 360;
            }
            let relativeAngle = angle - startAngle;
            if (relativeAngle < -180) {
                relativeAngle += 360;
            } else if (relativeAngle > 180) {
                relativeAngle -= 360;
            }
            this.timeSegments.segments[i].heading = angle;
            this.timeSegments.segments[i].relativeHeading = relativeAngle;

            if (i === 0) {
                let winding = angle;
                if(this.reverse) {
                    winding += 180;
                    if (winding > 180) {
                        winding -= 360;
                    } else if (winding < -180) {
                        winding += 360;
                    }
                }
                this.timeSegments.segments[i].winding = winding;
                this.timeSegments.segments[i].relativeWinding = relativeAngle;
            } else {
                const diff = this.getAngleDifference(this.timeSegments.segments[i].rawHeading, this.timeSegments.segments[i - 1].rawHeading);
                const winding = this.timeSegments.segments[i - 1].winding + diff;
                const relativeWinding = this.timeSegments.segments[i - 1].relativeWinding + diff;
                this.timeSegments.segments[i].winding = winding;
                this.timeSegments.segments[i].relativeWinding = relativeWinding;
            }
        }
        if(!this.noLogging) log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
    }

    getAngleDifference(a, b) {
        const d = Math.abs(a - b) % 360;
        let r = d > 180 ? 360 - d : d;

        const sign = (a - b >= 0 && a - b <= 180) || (a - b <= -180 && a - b >= -360) ? 1 : -1;
        r *= sign;
        return r;
    }

    /**
     * Split the path into a left and right path for each side of the robot
     */
    splitLeftRight() {
        if(!this.noLogging) log.info('    Splitting left and right robot paths...');
        const start = new Date().getTime();
        const w = this.wheelbaseWidth / 2;
        for (let i = 0; i < this.timeSegments.segments.length; i++) {
            const seg = this.timeSegments.segments[i];
            let left = new Segment();
            let right = new Segment();

            const cos_angle = Math.cos(seg.heading * (Math.PI / 180));
            const sin_angle = Math.sin(seg.heading * (Math.PI / 180));

            left.x = seg.x + (w * sin_angle);
            left.fieldX = seg.fieldX + (w * sin_angle);
            left.y = seg.y - (w * cos_angle);
            left.fieldY = seg.fieldY - (w * cos_angle);
            left.heading = seg.heading;
            left.relativeHeading = seg.relativeHeading;
            left.winding = seg.winding;
            left.relativeWinding = seg.relativeWinding;
            left.dydx = seg.dydx;
            left.dt = seg.dt;
            left.time = seg.time;
            left.radius = seg.radius;
            left.angularVelocity = seg.angularVelocity;
            left.angularAccel = seg.angularAccel;

            if (i > 0) {
                const last = this.left.segments[i - 1];
                const distance = Math.sqrt((left.x - last.x) * (left.x - last.x) + (left.y - last.y) * (left.y - last.y));

                left.pos = last.pos + distance;
                left.vel = distance / seg.dt;
                left.acc = (left.vel - last.vel) / seg.dt;
                left.jerk = (left.acc - last.acc) / seg.dt;
            }

            right.x = seg.x - (w * sin_angle);
            right.fieldX = seg.fieldX - (w * sin_angle);
            right.y = seg.y + (w * cos_angle);
            right.fieldY = seg.fieldY + (w * cos_angle);
            right.heading = seg.heading;
            right.relativeHeading = seg.relativeHeading;
            right.winding = seg.winding;
            right.relativeWinding = seg.relativeWinding;
            right.dydx = seg.dydx;
            right.dt = seg.dt;
            right.time = seg.time;
            right.radius = seg.radius;
            right.angularVelocity = seg.angularVelocity;
            right.angularAccel = seg.angularAccel;

            if (i > 0) {
                const last = this.right.segments[i - 1];
                const distance = Math.sqrt((right.x - last.x) * (right.x - last.x) + (right.y - last.y) * (right.y - last.y));

                right.pos = last.pos + distance;
                right.vel = distance / seg.dt;
                right.acc = (right.vel - last.vel) / seg.dt;
                right.jerk = (right.acc - last.acc) / seg.dt;
            }

            this.left.segments.push(left);
            this.right.segments.push(right);
        }
        if(!this.noLogging) log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
    }

    /**
     * Recalculate all the values for validation
     */
    recalculateValues() {
        if(!this.noLogging) log.info('    Verifying values...');
        const start = new Date().getTime();
        for (let i = 1; i < this.timeSegments.segments.length; i++) {
            let now = this.timeSegments.segments[i];
            const last = this.timeSegments.segments[i - 1];
            const dt = now.time - last.time;
            now.vel = (now.pos - last.pos) / dt;
            now.acc = (now.vel - last.vel) / dt;
            now.jerk = (now.acc - last.acc) / dt;
            now.angularVelocity = now.vel / now.radius;
            now.angularAccel = (now.angularVelocity - last.angularVelocity) / dt;
        }
        if(!this.noLogging) log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms');
    }

    /**
     * Get the time for a segment
     * @param segNum The index of the segment
     * @returns number The time
     */
    segmentTime(segNum) {
        return segNum * this.timeStep;
    }
}

class Path {
    constructor(s, p0, pixelsPerUnit, noLogging, xPixelOffset) {
        this.noLogging = noLogging;
        this.length = 0.0;
        this.p0 = p0;
        this.x = [];
        this.y = [];
        this.l = [];
        this.inGroup = s;
        this.group = new SegmentGroup();
        this.pixelsPerUnit = pixelsPerUnit;
        this.xPixelOffset = xPixelOffset;
        this.makePath();
    }

    /**
     * Make the pre-generation path
     */
    makePath() {
        const start = new Date().getTime();
        if(!this.noLogging) log.info('Generating path...');
        this.makeScaledLists();
        this.calculateLength();
        this.createSegments();
        if(!this.noLogging) log.info('DONE IN: ' + (new Date().getTime() - start) + 'ms');
    }

    /**
     * Make x and y lists and convert the values from pixels to feet
     */
    makeScaledLists() {
        for (let i = 0; i < this.inGroup.segments.length; i++) {
            this.x.push((this.inGroup.segments[i].x - this.p0.x) / this.pixelsPerUnit);
            this.y.push((this.inGroup.segments[i].y - this.p0.y) / this.pixelsPerUnit);
        }
    }

    /**
     * Calculate the length of the path
     */
    calculateLength() {
        if(!this.noLogging) log.info('    Calculating length...');
        const start = new Date().getTime();
        for (let i = 1; i < this.x.length; i++) {
            const dx = this.x[i] - this.x[i - 1];
            const dy = this.y[i] - this.y[i - 1];
            const c = Math.sqrt((dx * dx) + (dy * dy));
            this.length += c;

            let prevLength = 0.0;
            if (i !== 1) {
                prevLength = this.l[this.l.length - 1];
            }
            this.l.push(c + prevLength);
        }
        if(!this.noLogging) log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms. Length: ' + this.length + 'ft');
    }

    /**
     * Create a segment for ech point on the path
     */
    createSegments() {
        if(!this.noLogging) log.info('    Calculating segments...');
        const start = new Date().getTime();
        for (let i = 0; i < this.x.length - 1; i++) {
            const s = i;
            const s2 = i + 1;
            let seg = new Segment();
            seg.x = this.x[s];
            seg.fieldX = ((this.p0.x - this.xPixelOffset) / this.pixelsPerUnit) + seg.x;
            seg.y = this.y[s];
            seg.fieldY = ((this.p0.y - Util.yPixelOffset) / this.pixelsPerUnit) + seg.y;
            seg.pos = this.l[s];
            seg.dydx = this.derivative(s, s2);
            seg.holonomicAngle = this.inGroup.segments[i].holonomicAngle;
            if (i !== 0) {
                seg.dx = seg.pos - this.group.segments[this.group.segments.length - 1].pos;
            }
            this.group.segments.push(seg);
        }
        if(!this.noLogging) log.info('        DONE IN: ' + (new Date().getTime() - start) + 'ms. Created ' + this.group.segments.length + ' segments.');
    }

    derivative(t1, t2) {
        return Util.slope(new Vector2(this.x[t1], this.y[t1]), new Vector2(this.x[t2], this.y[t2]));
    }
}

module.exports.RobotPath = RobotPath;
module.exports.Path = Path;
module.exports.join = join;