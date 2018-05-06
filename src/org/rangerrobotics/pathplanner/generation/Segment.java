package org.rangerrobotics.pathplanner.generation;

public class Segment {
    public double x, heading, y, pos, vel, acc, dydx, d2ydx2, jerk, dt, time, dx;

    public Segment(){
        this.x = 0;
        this.heading = 0;
        this.y = 0;
        this.pos = 0;
        this.vel = 0;
        this.acc = 0;
        this.dydx = 0;
        this.d2ydx2 = 0;
        this.jerk = 0;
        this.dt = 0;
        this.time = 0;
        this.dx = 0;
    }
}
