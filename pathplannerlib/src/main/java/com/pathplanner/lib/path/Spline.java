package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj.smartdashboard.SmartDashboard;

public class Spline {
    double x0, x1, x2, x3, x4, x5;
    double y0, y1, y2, y3, y4, y5;

    public Spline(
            Translation2d p1,
            Translation2d v1,
            Translation2d p2,
            Translation2d v2) {

        this.x0 = p1.getX();
        this.x1 = v1.getX();
        this.x2 = 0.5 * 0.0;
        this.x3 = -10 * p1.getX() - 6 * v1.getX() - 4 * v2.getX() + 10 * p2.getX() - 1.5 * 0.0 + 0.5 * 0.0;
        this.x4 = 15 * p1.getX() + 8 * v1.getX() + 7 * v2.getX() - 15 * p2.getX() + 1.5 * 0.0 - 0.0;
        this.x5 = -6 * p1.getX() - 3 * v1.getX() - 3 * v2.getX() + 6 * p2.getX() - 0.5 * 0.0 + 0.5 * 0.0;
        this.y0 = p1.getY();
        this.y1 = v1.getY();
        this.y2 = 0.5 * 0.0;
        this.y3 = -10 * p1.getY() - 6 * v1.getY() - 4 * v2.getY() + 10 * p2.getY() - 1.5 * 0.0 + 0.5 * 0.0;
        this.y4 = 15 * p1.getY() + 8 * v1.getY() + 7 * v2.getY() - 15 * p2.getY() + 1.5 * 0.0 - 0.0;
        this.y5 = -6 * p1.getY() - 3 * v1.getY() - 3 * v2.getY() + 6 * p2.getY() - 0.5 * 0.0 + 0.5 * 0.0;
    }

    static Translation2d getPoint(Translation2d p1, Translation2d v1, Translation2d p2, Translation2d v2, double t) {
        return new Translation2d(
                getValue(p1.getX(), v1.getX(), p2.getX(), v2.getX(), t),
                getValue(p1.getY(), v1.getY(), p2.getY(), v2.getY(), t));
    }

    static Translation2d getVelocity(Translation2d p1, Translation2d v1, Translation2d p2, Translation2d v2, double t) {
        return new Translation2d(
                getdValue(p1.getX(), v1.getX(), p2.getX(), v2.getX(), t),
                getdValue(p1.getY(), v1.getY(), p2.getY(), v2.getY(), t));
    }

    private static double getdValue(double x1, double dx1, double x2, double dx2, double t) {
        double c1 = dx1;
        double c2 = 0.5 * 0.0;
        double c3 = -10 * x1 - 6 * dx1 - 4 * dx2 + 10 * x2 - 1.5 * 0.0 + 0.5 * 0.0;
        double c4 = 15 * x1 + 8 * dx1 + 7 * dx2 - 15 * x2 + 1.5 * 0.0 - 0.0;
        double c5 = -6 * x1 - 3 * dx1 - 3 * dx2 + 6 * x2 - 0.5 * 0.0 + 0.5 * 0.0;

        return c1 + 2.0 * c2 * t + 3.0 * c3 * t * t + 4.0 * c4 * t * t * t + 5.0 * c5 * t * t * t * t;
    }

    private static double getValue(double x1, double dx1, double x2, double dx2, double t) {
        double c0 = x1;
        double c1 = dx1;
        double c2 = 0.5 * 0.0;
        double c3 = -10 * x1 - 6 * dx1 - 4 * dx2 + 10 * x2 - 1.5 * 0.0 + 0.5 * 0.0;
        double c4 = 15 * x1 + 8 * dx1 + 7 * dx2 - 15 * x2 + 1.5 * 0.0 - 0.0;
        double c5 = -6 * x1 - 3 * dx1 - 3 * dx2 + 6 * x2 - 0.5 * 0.0 + 0.5 * 0.0;

        return c0 + c1 * t + c2 * t * t + c3 * t * t * t + c4 * t * t * t * t + c5 * t * t * t * t * t;
    }

    Translation2d getPoint(double t) {
        return new Translation2d(getX(t), getY(t));
    }

    private double getX(double t) {
        return x0 + x1 * t + x2 * t * t + x3 * t * t * t + x4 * t * t * t * t + x5 * t * t * t * t * t;
    }

    private double getY(double t) {
        return y0 + y1 * t + y2 * t * t + y3 * t * t * t + y4 * t * t * t * t + y5 * t * t * t * t * t;
    }
}
