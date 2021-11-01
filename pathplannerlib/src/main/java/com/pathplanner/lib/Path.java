package com.pathplanner.lib;

import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;

import java.util.ArrayList;

public class Path {
    private final ArrayList<State> generatedStates;
    private ArrayList<Waypoint> pathPoints;
    private double maxVel;
    private double maxAccel;
    private boolean reversed;

    protected Path(ArrayList<Waypoint> pathPoints, double maxVel, double maxAccel, boolean reversed){
        this.pathPoints = pathPoints;
        this.maxVel = maxVel;
        this.maxAccel = maxAccel;
        this.reversed = reversed;

        ArrayList<State> joined = joinSplines(PathPlanner.resolution);
        calculateMaxVel(joined);
        calculateVelocity(joined);
        recalculateValues(joined);

        this.generatedStates = joined;
    }

    protected Path(ArrayList<State> generatedStates){
        this.generatedStates = generatedStates;
    }

    public ArrayList<State> getStates(){
        return this.generatedStates;
    }

    public int numStates(){
        return getStates().size();
    }

    public State getState(int i){
        return getStates().get(i);
    }

    public double getTotalTime(){
        return getEndState().time;
    }

    public State getInitialState(){
        return getState(0);
    }

    public State getEndState(){
        return getState(numStates() - 1);
    }

    public State sample(double time){
        if(time <= getInitialState().time) return getInitialState();
        if(time >= getTotalTime()) return getEndState();

        int low = 1;
        int high = getStates().size() - 1;

        while(low != high) {
            int mid = (low + high) / 2;
            if(getState(mid).time < time){
                low = mid + 1;
            }else{
                high = mid;
            }
        }

        State sample = getState(low);
        State prevSample = getState(low - 1);

        if(Math.abs(sample.time - prevSample.time) < 1E-3) return sample;

        return prevSample.interpolate(sample, (time - prevSample.time) / (sample.time - prevSample.time));
    }

    private ArrayList<State> joinSplines(double step){
        ArrayList<State> states = new ArrayList<>();

        for(int i = 0; i < numSplines(); i++){
            Waypoint startPoint = pathPoints.get(i);
            Waypoint endPoint = pathPoints.get(i + 1);

            double endStep = (i == numSplines() - 1) ? 1.0 : 1.0 - step;
            for(double t = 0; t <= endStep; t += step){
                Translation2d p = GeometryUtil.cubicLerp(startPoint.anchorPoint, startPoint.nextControl, endPoint.prevControl, endPoint.anchorPoint, t);

                State state = new State();
                state.pose = new Pose2d(p, state.pose.getRotation());

                double deltaRot = endPoint.holonomicRotation.minus(startPoint.holonomicRotation).getDegrees();
                if(Math.abs(deltaRot) > 180){
                    if(deltaRot < 0){
                        deltaRot = 180 + (deltaRot % 180);
                    }else{
                        deltaRot = -180 + (deltaRot % 180);
                    }
                }
                double holonomicRot = endPoint.holonomicRotation.getDegrees() + (t * deltaRot);
                state.holonomicRotation = Rotation2d.fromDegrees(holonomicRot);

                if(i > 0 || t > 0){
                    State s1 = states.get(states.size() - 1);
                    State s2 = state;
                    double hypot = s1.pose.getTranslation().getDistance(s2.pose.getTranslation());
                    state.linearPosMeters = s1.linearPosMeters + hypot;
                    state.deltaPos = hypot;

                    double heading = Math.atan2(s1.pose.getY() - s2.pose.getY(), s1.pose.getX() - s2.pose.getX());
                    state.pose = new Pose2d(state.pose.getTranslation(), new Rotation2d(heading));

                    if(i == 0 && t == step){
                        states.get(states.size() - 1).pose = new Pose2d(states.get(states.size() - 1).pose.getTranslation(), new Rotation2d(heading));
                    }
                }

                if(t == 0.0){
                    state.linearVelMeters = startPoint.velOverride;
                }else if(t == 1.0){
                    state.linearVelMeters = endPoint.velOverride;
                }else {
                    state.linearVelMeters = this.maxVel;
                }

                if(state.linearVelMeters == -1) state.linearVelMeters = this.maxVel;

                states.add(state);
            }
        }
        return states;
    }

    private void calculateMaxVel(ArrayList<State> states){
        for(int i = 0; i < states.size(); i++){
            double radius;
            if(i == states.size() - 1){
                radius = calculateRadius(states.get(i - 2), states.get(i - 1), states.get(i));
            }else if(i == 0){
                radius = calculateRadius(states.get(i), states.get(i + 1), states.get(i + 2));
            }else{
                radius = calculateRadius(states.get(i - 1), states.get(i), states.get(i + 1));
            }

            if(!Double.isFinite(radius) || Double.isNaN(radius)){
                states.get(i).linearVelMeters = Math.min(this.maxVel, states.get(i).linearVelMeters);
            }else{
                states.get(i).curveRadius = radius;

                double maxVCurve = Math.sqrt(this.maxAccel * radius);

                states.get(i).linearVelMeters = Math.min(maxVCurve, states.get(i).linearVelMeters);
            }
        }
    }

    private void calculateVelocity(ArrayList<State> states){
        states.get(0).linearVelMeters = 0;

        for(int i = 1; i < states.size(); i++){
            double v0 = states.get(i - 1).linearVelMeters;
            double deltaPos = states.get(i).deltaPos;

            if(deltaPos > 0) {
                double vMax = Math.sqrt(Math.abs(Math.pow(v0, 2) + (2 * this.maxAccel * deltaPos)));
                states.get(i).linearVelMeters = Math.min(vMax, states.get(i).linearVelMeters);
            }else{
                states.get(i).linearVelMeters = states.get(i - 1).linearVelMeters;
            }
        }

        if(pathPoints.get(pathPoints.size() - 1).velOverride == -1){
            states.get(states.size() - 1).linearVelMeters = 0;
        }
        for(int i = states.size() - 2; i > 1; i--){
            double v0 = states.get(i + 1).linearVelMeters;
            double deltaPos = states.get(i + 1).deltaPos;

            double vMax = Math.sqrt(Math.abs(v0 * v0 + 2 * this.maxAccel * deltaPos));
            states.get(i).linearVelMeters = Math.min(vMax, states.get(i).linearVelMeters);
        }

        double time = 0;
        for(int i = 1; i < states.size(); i++){
            double v = states.get(i).linearVelMeters;
            double deltaPos = states.get(i).deltaPos;
            double v0 = states.get(i - 1).linearVelMeters;

            time += (2 * deltaPos) / (v + v0);
            states.get(i).time = time;

            double dv = v - v0;
            double dt = time - states.get(i - 1).time;

            if(dt == 0){
                states.get(i).linearAccelMeters = 0;
            }else{
                states.get(i).linearAccelMeters = dv / dt;
            }
        }
    }

    private void recalculateValues(ArrayList<State> states){
        for(int i = 1; i < states.size(); i++){
            State now = states.get(i);
            State last = states.get(i - 1);

            double dt = now.time - last.time;
            now.linearVelMeters = (now.linearPosMeters - last.linearPosMeters) / dt;
            now.linearAccelMeters = (now.linearVelMeters - last.linearVelMeters) / dt;
            now.linearJerkMeters = (now.linearAccelMeters - last.linearAccelMeters) / dt;

            if(this.reversed){
                now.linearPosMeters *= -1;
                now.linearVelMeters *= -1;
                now.linearAccelMeters *= -1;
                now.linearJerkMeters *= -1;

                double h = now.pose.getRotation().getDegrees() + 180;
                if(h > 180){
                    h -= 360;
                }else if(h < -180){
                    h += 360;
                }
                now.pose = new Pose2d(now.pose.getTranslation(), Rotation2d.fromDegrees(h));
            }

            now.angularVel = now.pose.getRotation().minus(last.pose.getRotation()).times(1 / dt);
            now.angularAccel = now.angularVel.minus(last.angularVel).times(1 / dt);
        }
    }

    private double calculateRadius(State s0, State s1, State s2){
        Translation2d a = s0.pose.getTranslation();
        Translation2d b = s1.pose.getTranslation();
        Translation2d c = s2.pose.getTranslation();

        double ab = a.getDistance(b);
        double bc = b.getDistance(c);
        double ac = a.getDistance(c);

        double p = (ab + bc + ac) / 2;
        double area = Math.sqrt(Math.abs(p * (p - ab) * (p - bc) * (p - ac)));
        return (ab * bc * ac) / (4 * area);
    }

    private int numSplines() {
        return this.pathPoints.size() - 1;
    }

    protected static Path joinPaths(ArrayList<Path> paths){
        ArrayList<State> joinedStates = new ArrayList<>();

        for(Path path : paths){
            joinedStates.addAll(path.getStates());
        }

        return new Path(joinedStates);
    }

    public static class State{
        private Pose2d pose = new Pose2d();
        private double linearPosMeters = 0;
        private double linearVelMeters = 0;
        private double linearAccelMeters = 0;
        private double linearJerkMeters = 0;
        private double time = 0;
        private Rotation2d angularVel = new Rotation2d();
        private Rotation2d angularAccel = new Rotation2d();
        private Rotation2d holonomicRotation = new Rotation2d();

        private double curveRadius = 0;
        private double deltaPos = 0;

        public Pose2d getPose(){
            return this.pose;
        }

        public double getLinearPositionMeters(){
            return this.linearPosMeters;
        }

        public double getLinearVelocityMeters(){
            return this.linearVelMeters;
        }

        public double getLinearAccelerationMeters(){
            return this.linearAccelMeters;
        }

        public double getLinearJerkMeters(){
            return this.linearJerkMeters;
        }

        public double getTime(){
            return this.time;
        }

        public Rotation2d getAngularVelocity(){
            return this.angularVel;
        }

        public Rotation2d getAngularAcceleration(){
            return this.angularAccel;
        }

        public Rotation2d getHolonomicRotation(){
            return this.holonomicRotation;
        }

        public double getCurveRadiusMeters(){
            return this.curveRadius;
        }

        private State interpolate(State endVal, double t){
            State lerpedState = new State();

            lerpedState.time = GeometryUtil.doubleLerp(time, endVal.time, t);
            double deltaT = lerpedState.time - time;

            if(deltaT < 0){
                return endVal.interpolate(this, 1 - t);
            }

            lerpedState.linearVelMeters = linearVelMeters + (linearAccelMeters * deltaT);
            lerpedState.linearPosMeters = (linearVelMeters * deltaT) + (0.5 * linearAccelMeters * Math.pow(deltaT, 2));
            lerpedState.linearAccelMeters = GeometryUtil.doubleLerp(linearAccelMeters, endVal.linearAccelMeters, t);
            lerpedState.linearJerkMeters = GeometryUtil.doubleLerp(linearJerkMeters, endVal.linearJerkMeters, t);
            Translation2d newTrans = GeometryUtil.translationLerp(pose.getTranslation(), endVal.pose.getTranslation(), t);
            Rotation2d newHeading = GeometryUtil.rotationLerp(pose.getRotation(), endVal.pose.getRotation(), t);
            lerpedState.pose = new Pose2d(newTrans, newHeading);
            lerpedState.angularVel = GeometryUtil.rotationLerp(angularVel, endVal.angularVel, t);
            lerpedState.angularAccel = GeometryUtil.rotationLerp(angularAccel, endVal.angularAccel, t);
            lerpedState.holonomicRotation = GeometryUtil.rotationLerp(holonomicRotation, endVal.holonomicRotation, t);
            lerpedState.curveRadius = GeometryUtil.doubleLerp(curveRadius, endVal.curveRadius, t);

            return lerpedState;
        }
    }

    protected static class Waypoint {
        private final Translation2d anchorPoint;
        private final Translation2d prevControl;
        private final Translation2d nextControl;
        private final double velOverride;
        private final Rotation2d holonomicRotation;
        protected final boolean isReversal;

        protected Waypoint(Translation2d anchorPoint, Translation2d prevControl, Translation2d nextControl, double velOverride, Rotation2d holonomicRotation, boolean isReversal){
            this.anchorPoint = anchorPoint;
            this.prevControl = prevControl;
            this.nextControl = nextControl;
            this.velOverride = velOverride;
            this.holonomicRotation = holonomicRotation;
            this.isReversal = isReversal;
        }
    }
}
