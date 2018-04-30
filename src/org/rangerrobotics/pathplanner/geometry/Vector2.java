package org.rangerrobotics.pathplanner.geometry;

import com.jfoenix.controls.datamodels.treetable.RecursiveTreeObject;
import javafx.beans.property.SimpleDoubleProperty;

public class Vector2 extends RecursiveTreeObject<Vector2>{
    public SimpleDoubleProperty x;
    public SimpleDoubleProperty y;
    private double magnitude;

    public Vector2(double x, double y){
        this.x = new SimpleDoubleProperty(x);
        this.y = new SimpleDoubleProperty(y);
        this.magnitude = Math.sqrt((x*x) + (y*y));
    }

    public double getX() {
        return x.get();
    }

    public double getY() {
        return y.get();
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
