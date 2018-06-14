package org.rangerrobotics.pathplanner.generation;

public class Vector2 {
    private double x;
    private double y;
    private double magnitude;

    public Vector2(double x, double y){
        this.x = x;
        this.y = y;
        this.magnitude = Math.sqrt((x*x) + (y*y));
    }

    public double getX() {
        return x;
    }

    public double getY() {
        return y;
    }

    public double getMagnitude(){
        return this.magnitude;
    }

    public Vector2 normalized(){
        if(magnitude > 0){
            return Vector2.divide(this, magnitude);
        }
        return new Vector2(0, 0);
    }

    public static Vector2 add(Vector2 a, Vector2 b){
        return new Vector2(a.getX() + b.getX(), a.getY() + b.getY());
    }

    public static Vector2 subtract(Vector2 a, Vector2 b){
        return new Vector2(a.getX() - b.getX(), a.getY() - b.getY());
    }

    public static Vector2 multiply(Vector2 vec, double mult){
        return new Vector2(vec.getX() * mult, vec.getY() * mult);
    }

    public static Vector2 divide(Vector2 vec, double div){
        return new Vector2(vec.getX() / div, vec.getY() / div);
    }
}
