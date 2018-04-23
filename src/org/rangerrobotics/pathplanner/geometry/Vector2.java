package org.rangerrobotics.pathplanner.geometry;

public class Vector2 {
    public double x;
    public double y;

    public Vector2(double x, double y){
        this.x = x;
        this.y = y;
    }

    public static Vector2 add(Vector2 a, Vector2 b){
        return new Vector2(a.x + b.x, a.y + b.y);
    }

    public static Vector2 subtract(Vector2 a, Vector2 b){
        return new Vector2(a.x - b.x, a.y - b.y);
    }

    public static Vector2 multiply(Vector2 vec, double mult){
        return new Vector2(vec.x * mult, vec.y * mult);
    }
}
