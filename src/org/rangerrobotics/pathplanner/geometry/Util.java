package org.rangerrobotics.pathplanner.geometry;

public class Util {
    public static Vector2 lerp (Vector2 a, Vector2 b, double t){
        return Vector2.add(a, Vector2.multiply(Vector2.subtract(b, a), t));
    }

    public static Vector2 quadraticCurve(Vector2 a, Vector2 b, Vector2 c, double t){
        Vector2 p0 = lerp(a, b, t);
        Vector2 p1 = lerp(b, c, t);
        return lerp(p0, p1, t);
    }

    public static Vector2 cubicCurve(Vector2 a, Vector2 b, Vector2 c, Vector2 d, double t){
        Vector2 p0 = quadraticCurve(a, b, c, t);
        Vector2 p1 = quadraticCurve(b, c, d, t);
        return lerp(p0, p1, t);
    }

    public static double slope(Vector2 a, Vector2 b){
        double dy = a.getY() - b.getY();
        double dx = a.getX() - b.getX();
        return dy/dx;
    }
}
