package org.rangerrobotics.pathplanner.generation;

import java.util.ArrayList;

public class RobotPath {
    public static double maxVel = 14;
    public static double maxAcc = 10;
    public static double maxDcc = 20;
    public static double maxJerk = 100;
    public static double wheelbaseWidth = 2;
    public static double timeStep = 0.01;
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
    }

    private void calculateSecondDerivative(){
        System.out.println("    Finding Second Derivative of " + pathSegments.s.size() + " Segments...");
        for(int i = 0; i < pathSegments.s.size(); i++){
            if(i == 0){
                pathSegments.s.get(i).d2ydx2 = 0;
            }else{
                double d2 = pathSegments.s.get(i).dydx;
                double d1 = pathSegments.s.get(i - 1).dydx;
                double t2 = pathSegments.s.get(i).x;
                double t1 = pathSegments.s.get(i - 1).x;
                pathSegments.s.get(i).d2ydx2 = ((d2 - d1) / (t2 - t1));
            }
        }
    }

    private void calculateMaxVelocity(){
        System.out.println("    Calculating Maximum Possible Velocity Along Curve...");
        for(int i = 0; i < path.group.s.size(); i++){
            double r = radiusOfCurve(pathSegments.s.get(i));
            double vMaxCurve = Math.sqrt(maxAcc * r);
            double bigR = r + wheelbaseWidth / 2;
            double vMaxWheel = (r / bigR) * maxVel;
            pathSegments.s.get(i).vel = Math.min(vMaxCurve, Math.min(vMaxWheel, maxVel));
        }
    }

    private void calculateVelocity(){
        System.out.println("    Calculating Velocities...");
        ArrayList<Segment> p = pathSegments.s;
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
                double vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * maxAcc * dx));
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
            double vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * maxDcc * dx));
            p.get(i).vel = Math.min((Double.isNaN(vMax) ? maxVel : vMax), p.get(i).vel);
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
        ArrayList<Segment> p = pathSegments.s;
        for(int i = 0; i < p.size(); i++){
            if(i == 0){
                timeSegments.s.add(p.get(0));
                segNum++;
            }

            if(p.get(i).time > segmentTime(segNum)){
                timeSegments.s.add(p.get(i));
                timeSegments.s.get(timeSegments.s.size() - 1).dt = timeSegments.s.get(timeSegments.s.size() - 1).time - timeSegments.s.get(timeSegments.s.size() - 2).time;
                if(Math.abs(p.get(i).time - segmentTime(segNum)) > this.timeStep + 0.00005){
                    numMessySeg++;
                }
                segNum++;
            }
        }
        System.out.println("        Divided into " + segNum + " Segments, with " + numMessySeg + " Messy Segments.");
        System.out.println("        STATS:");
        System.out.println("          Time: " + timeSegments.s.get(timeSegments.s.size() - 1).time + " s");
        System.out.println("          Distance: " + timeSegments.s.get(timeSegments.s.size() - 1).pos + " ft");
        System.out.println("          Average Velocity: " + (timeSegments.s.get(timeSegments.s.size() - 1).pos / timeSegments.s.get(timeSegments.s.size() - 1).time) + " ft/s");
    }

    private void recalculateValues(){
        System.out.println("    Verifying Values...");
        for(int i = 0; i < timeSegments.s.size(); i++){
            if(i != 0){
                Segment now = timeSegments.s.get(i);
                Segment past = timeSegments.s.get(i - 1);
                now.vel = (now.pos - past.pos) / (now.time - past.time);
                now.acc = (now.vel - past.vel) / (now.time - past.time);
            }
        }
    }

    private void splitLeftRight(){
        System.out.println("    Splitting Left and Right Robot Paths...");
        for(int i = 0; i < timeSegments.s.size(); i++){
            //left
            Segment s = timeSegments.s.get(i);
            Segment l = new Segment();
            ArrayList<Segment> lg = left.s;
            left.s.add(l);
            l = left.s.get(i);
            l.x = s.x + wheelbaseWidth / 2 * Math.sin(Math.atan(s.dydx));
            l.y = s.y - wheelbaseWidth / 2 * Math.cos(Math.atan(s.dydx));

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
            ArrayList<Segment> rg = right.s;
            right.s.add(r);
            r = right.s.get(i);
            r.x = s.x - wheelbaseWidth / 2 * Math.sin(Math.atan(s.dydx));
            r.y = s.y + wheelbaseWidth / 2 * Math.cos(Math.atan(s.dydx));

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
        return segNum * timeStep;
    }
}
