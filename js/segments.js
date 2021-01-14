const log = require('electron-log');

class SegmentGroup {
    constructor() {
        this.segments = [];
    }

    formatCSV(reverse, format, step, header, robotPath, outputRadians) {
        let str = '';
        if(header) {
            str += header + '\n';
        }
        for (let i = 0; i < this.segments.length; i++) {
            str += this.formatSegment(i, reverse, format, step, robotPath, outputRadians);
            if (i < this.segments.length - 1) {
                str += '\n';
            }
        }
        return str;
    }

    formatJavaArray(arrayName, reverse, format, step, robotPath, outputRadians) {
        let str = 'public static double[][] ' + arrayName + ' = new double[][] {\n';
        for (let i = 0; i < this.segments.length; i++) {
            str += '        {' + this.formatSegment(i, reverse, format, step, robotPath, outputRadians) + '}' + ((i < this.segments.length - 1) ? ',\n' : '\n');
        }
        str += '    }';
        return str;
    }

    formatCppArray(arrayName, reverse, format, step, robotPath, outputRadians) {
        let str = 'double ' + arrayName + '[][] = {\n';
        for (let i = 0; i < this.segments.length; i++) {
            str += '        {' + this.formatSegment(i, reverse, format, step, robotPath, outputRadians) + '}' + ((i < this.segments.length - 1) ? ',\n' : '\n');
        }
        str += '    }';
        return str;
    }

    formatPythonArray(arrayName, reverse, format, step, robotPath, outputRadians) {
        let str = arrayName + ' = [\n';
        for (let i = 0; i < this.segments.length; i++) {
            str += '    [' + this.formatSegment(i, reverse, format, step, robotPath, outputRadians) + ((i < this.segments.length - 1) ? '],\n' : ']]');
        }
        return str;
    }

    formatSegment(index, reverse, format, step, robotPath, outputRadians) {
        const s = this.segments[index];
        let l = this.segments[index], r = this.segments[index];
        if(robotPath){
            l = robotPath.left.segments[index];
            r = robotPath.right.segments[index];
        }
        const n = (reverse) ? -1 : 1;
        let ret = format.replace(/x/g, (Math.round(s.x * 10000) / 10000 * n).toString());
        ret = ret.replace(/y/g, (Math.round(s.y * 10000) / 10000 * n).toString());
        ret = ret.replace(/X/g, (Math.round(s.fieldX * 10000) / 10000).toString());
        ret = ret.replace(/Y/g, (Math.round(s.fieldY * 10000) / 10000).toString());
        ret = ret.replace(/pl/g, (Math.round((reverse ? r.pos : l.pos) * 10000) / 10000 * n).toString());
        ret = ret.replace(/pr/g, (Math.round((reverse ? l.pos : r.pos) * 10000) / 10000 * n).toString());
        ret = ret.replace(/vl/g, (Math.round((reverse ? r.vel : l.vel) * 10000) / 10000 * n).toString());
        ret = ret.replace(/vr/g, (Math.round((reverse ? l.vel : r.vel) * 10000) / 10000 * n).toString());
        ret = ret.replace(/al/g, (Math.round((reverse ? r.acc : l.acc) * 10000) / 10000 * n).toString());
        ret = ret.replace(/ar/g, (Math.round((reverse ? l.acc : r.acc) * 10000) / 10000 * n).toString());
        ret = ret.replace(/p/g, (Math.round(s.pos * 10000) / 10000 * n).toString());
        ret = ret.replace(/v/g, (Math.round(s.vel * 10000) / 10000 * n).toString());
        ret = ret.replace(/a/g, (Math.round(s.acc * 10000) / 10000 * n).toString());
        let holonomicHeading = s.holonomicAngle;
        if(holonomicHeading > 180){
            holonomicHeading -= 360;
        }else if(holonomicHeading < -180){
            holonomicHeading += 360;
        }
        if(outputRadians){
            holonomicHeading *= Math.PI / 180;
        }
        ret = ret.replace(/hh/g, (Math.round(holonomicHeading * 10000) / 10000).toString());
        let heading = s.heading;
        if(reverse){
            heading += 180;
            if(heading > 180){
                heading -= 360;
            }else if(heading < -180){
                heading += 360;
            }
        }
        if(outputRadians){
            heading *= Math.PI / 180;
        }
        ret = ret.replace(/h/g, (Math.round(heading * 10000) / 10000).toString());
        let relativeHeading = s.relativeHeading;
        if(outputRadians){
            relativeHeading *= Math.PI / 180;
        }
        ret = ret.replace(/H/g, (Math.round(relativeHeading * 10000) / 10000).toString());
        ret = ret.replace(/t/g, (Math.round(s.time * 10000) / 10000).toString());
        ret = ret.replace(/S/g, step.toString());
        ret = ret.replace(/s/g, (step * 1000).toString());
        let relativeWinding = s.relativeWinding;
        if(outputRadians){
            relativeWinding *= Math.PI / 180;
        }
        ret = ret.replace(/W/g, (Math.round(relativeWinding * 10000) / 10000).toString());
        let winding = s.winding;
        if(outputRadians){
            winding *= Math.PI / 180;
        }
        ret = ret.replace(/w/g, (Math.round(winding * 10000) / 10000).toString());
        ret = ret.replace(/r/g, (Math.round(s.radius * 10000) / 10000).toString());
        let angularVelocity = s.angularVelocity;
        if(outputRadians){
            angularVelocity *= Math.PI / 180;
        }
        ret = ret.replace(/o/g, (Math.round(angularVelocity * 10000) / 10000).toString());
        let angularAccel = s.angularAccel;
        if(outputRadians){
            angularAccel *= Math.PI / 180;
        }
        ret = ret.replace(/O/g, (Math.round(angularAccel * 10000) / 10000).toString());
        ret = ret.replace(/j/g, (Math.round(s.jerk * 10000) / 10000).toString());
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
        this.fieldX = 0.0;
        this.fieldY = 0.0;
        this.heading = 0.0;
        this.relativeHeading = 0.0;
        this.winding = 0.0;
        this.relativeWinding = 0.0;
        this.rawHeading = 0.0;
        this.radius = 0.0;
        this.pos = 0.0;
        this.vel = 0.0;
        this.acc = 0.0;
        this.dydx = 0.0;
        this.dt = 0.0;
        this.time = 0;
        this.dx = 0.0;
        this.angularVelocity = 0.0;
        this.angularAccel = 0.0;
        this.holonomicAngle = 0.0;
        this.jerk = 0.0;
    }
}

module.exports.Segment = Segment;
module.exports.SegmentGroup = SegmentGroup;