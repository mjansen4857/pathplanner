package org.rangerrobotics.pathplanner.generation;

import org.rangerrobotics.pathplanner.Preferences;

import java.util.ArrayList;

public class RobotPath {
    public static RobotPath generatedPath = null;
    private Path path;
    private SegmentGroup pathSegments;
    private SegmentGroup timeSegments = new SegmentGroup();
    public SegmentGroup left = new SegmentGroup();
    public SegmentGroup right = new SegmentGroup();

    public RobotPath(PlannedPath plannedPath){
        this.path = new Path(plannedPath.join(0.00001));
        System.out.println("Calculating Robot Data...");
        long start = System.currentTimeMillis();
        pathSegments = path.group;
        calculateSecondDerivative();
        calculateMaxVelocity();
        calculateVelocity();
        splitGroupByTime();
        recalculateValues();
        splitLeftRight();
        System.out.println("DONE IN: " + (System.currentTimeMillis() - start) + " ms");
        generatedPath = this;
    }

    private void calculateSecondDerivative(){
        System.out.println("    Finding Second Derivative of " + pathSegments.segments.size() + " Segments...");
        for(int i = 0; i < pathSegments.segments.size(); i++){
            if(i == 0){
                pathSegments.segments.get(i).d2ydx2 = 0;
            }else{
                double d2 = pathSegments.segments.get(i).dydx;
                double d1 = pathSegments.segments.get(i - 1).dydx;
                double t2 = pathSegments.segments.get(i).x;
                double t1 = pathSegments.segments.get(i - 1).x;
                pathSegments.segments.get(i).d2ydx2 = ((d2 - d1) / (t2 - t1));
            }
        }
    }

    private void calculateMaxVelocity(){
        System.out.println("    Calculating Maximum Possible Velocity Along Curve...");
        for(int i = 0; i < path.group.segments.size(); i++){
            double r = radiusOfCurve(pathSegments.segments.get(i));
            double vMaxCurve = Math.sqrt(Preferences.maxAcc * r);
            double bigR = r + Preferences.wheelbaseWidth / 2;
            double vMaxWheel = (r / bigR) * Preferences.maxVel;
            pathSegments.segments.get(i).vel = Math.min(vMaxCurve, Math.min(vMaxWheel, Preferences.maxVel));
        }
    }

    private void calculateVelocity(){
        System.out.println("    Calculating Velocities...");
        ArrayList<Segment> p = pathSegments.segments;
        for(int i = 1; i < p.size(); i++){
            if(p.get(i).dx == 0){
                p.remove(i);
            }
        }
        p.get(0).vel = 0;
        double time = 0;
        for(int i = 1; i < p.size(); i++){
            double v0 = p.get(i - 1).vel;
            double dx = p.get(i - 1).dx;
            if(dx != 0){
                double vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * Preferences.maxAcc * dx));
                double v = Math.min(vMax, p.get(i).vel);
                if(Double.isNaN(v)){
                    v = p.get(i - 1).vel;
                }
                p.get(i).vel = v;
            }else{
                p.get(i).vel = p.get(i - 1).vel;
            }
        }
        p.get(p.size() - 1).vel = 0;
        for(int i = p.size() - 2; i > 1; i--){
            double v0 = p.get(i + 1).vel;
            double dx = p.get(i + 1).dx;
            double vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * Preferences.maxDcc * dx));
            p.get(i).vel = Math.min((Double.isNaN(vMax) ? Preferences.maxVel : vMax), p.get(i).vel);
        }
        for(int i = 1; i < p.size(); i++){
            double v = p.get(i).vel;
            double dx = p.get(i - 1).dx;
            double v0 = p.get(i - 1).vel;
            time += (2 * dx) / (v + v0);
            time = (Double.isNaN(time)) ? 0 : time;
            p.get(i).time = time;
        }
        for(int i = 1; i < p.size(); i++){
            double dt = p.get(i).time - p.get(i - 1).time;
            if(dt == 0 || Double.isInfinite(dt)){
                p.remove(i);
            }
        }
        for(int i = 1; i < p.size(); i++){
            double dv = p.get(i).vel - p.get(i - 1).vel;
            double dt = p.get(i).time - p.get(i - 1).time;
            if(dt == 0){
                p.get(i).acc = 0;
            }else{
                p.get(i).acc = dv / dt;
            }
        }
    }

    private void splitGroupByTime(){
        System.out.println("    Time Dividing Segments...");
        int segNum = 0;
        int numMessySeg = 0;
        ArrayList<Segment> p = pathSegments.segments;
        for(int i = 0; i < p.size(); i++){
            if(i == 0){
                timeSegments.segments.add(p.get(0));
                segNum++;
            }

            if(p.get(i).time > segmentTime(segNum)){
                timeSegments.segments.add(p.get(i));
                timeSegments.segments.get(timeSegments.segments.size() - 1).dt = timeSegments.segments.get(timeSegments.segments.size() - 1).time - timeSegments.segments.get(timeSegments.segments.size() - 2).time;
                if(Math.abs(p.get(i).time - segmentTime(segNum)) > Preferences.timeStep + 0.00005){
                    numMessySeg++;
                }
                segNum++;
            }
        }
        System.out.println("        Divided into " + segNum + " Segments, with " + numMessySeg + " Messy Segments.");
        System.out.println("        STATS:");
        System.out.println("          Time: " + timeSegments.segments.get(timeSegments.segments.size() - 1).time + " seconds");
        System.out.println("          Distance: " + timeSegments.segments.get(timeSegments.segments.size() - 1).pos + " ft");
        System.out.println("          Average Velocity: " + (timeSegments.segments.get(timeSegments.segments.size() - 1).pos / timeSegments.segments.get(timeSegments.segments.size() - 1).time) + " ft/s");
    }

    private void recalculateValues(){
        System.out.println("    Verifying Values...");
        for(int i = 0; i < timeSegments.segments.size(); i++){
            if(i != 0){
                Segment now = timeSegments.segments.get(i);
                Segment past = timeSegments.segments.get(i - 1);
                now.vel = (now.pos - past.pos) / (now.time - past.time);
                now.acc = (now.vel - past.vel) / (now.time - past.time);
            }
        }
    }

    private void splitLeftRight(){
        System.out.println("    Splitting Left and Right Robot Paths...");
        for(int i = 0; i < timeSegments.segments.size(); i++){
            //left
            Segment s = timeSegments.segments.get(i);
            Segment l = new Segment();
            ArrayList<Segment> lg = left.segments;
            left.segments.add(l);
            l = left.segments.get(i);
            l.x = s.x + Preferences.wheelbaseWidth / 2 * Math.sin(Math.atan(s.dydx));
            l.y = s.y - Preferences.wheelbaseWidth / 2 * Math.cos(Math.atan(s.dydx));

            if(i != 0){
                double dp = Math.sqrt((l.x - lg.get(i - 1).x)
                        * (l.x - lg.get(i - 1).x)
                        + (l.y - lg.get(i - 1).y)
                        * (l.y - lg.get(i - 1).y));
                l.pos = lg.get(i - 1).pos + dp;
                l.vel = dp / s.dt;
                l.acc = (l.vel - lg.get(i - 1).vel) / s.dt;
                l.time = s.time;
                l.dydx = s.dydx;
            }
            //right
            Segment r = new Segment();
            ArrayList<Segment> rg = right.segments;
            right.segments.add(r);
            r = right.segments.get(i);
            r.x = s.x - Preferences.wheelbaseWidth / 2 * Math.sin(Math.atan(s.dydx));
            r.y = s.y + Preferences.wheelbaseWidth / 2 * Math.cos(Math.atan(s.dydx));

            if (i != 0) {
                double dp = Math.sqrt((r.x - rg.get(i - 1).x)
                        * (r.x - rg.get(i - 1).x)
                        + (r.y - rg.get(i - 1).y)
                        * (r.y - rg.get(i - 1).y));
                r.pos = rg.get(i - 1).pos + dp;
                r.vel = dp / s.dt;
                r.acc = (r.vel - rg.get(i - 1).vel) / s.dt;
                r.time = s.time;
                r.dydx = s.dydx;
            }
        }
    }

    private double radiusOfCurve(Segment s){
        double c = s.dydx * s.dydx;
        double b = Math.pow((c + 1), 1.5);
        return b / Math.abs(s.d2ydx2);
    }

    private double segmentTime(int segNum){
        return segNum * Preferences.timeStep;
    }
}
