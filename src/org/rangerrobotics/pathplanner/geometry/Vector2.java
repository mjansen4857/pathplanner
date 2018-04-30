package org.rangerrobotics.pathplanner.geometry;

import com.jfoenix.controls.datamodels.treetable.RecursiveTreeObject;
import javafx.beans.property.SimpleDoubleProperty;

public class Vector2 extends RecursiveTreeObject<Vector2>{
    public SimpleDoubleProperty x;
    public SimpleDoubleProperty y;
    public boolean isAnchorPoint;

    public Vector2(double x, double y, boolean isAnchorPoint){
        this.x = new SimpleDoubleProperty(x);
        this.y = new SimpleDoubleProperty(y);
        this.isAnchorPoint = isAnchorPoint;
    }

    public double getX() {
        return x.get();
    }

    public double getY() {
        return y.get();
    }

    public void setX(double x) {
        this.x.set(x);
    }

    public void setY(double y) {
        this.y.set(y);
    }

    public static Vector2 add(Vector2 a, Vector2 b){
        return new Vector2(a.getX() + b.getX(), a.getY() + b.getY(), a.isAnchorPoint);
    }

    public static Vector2 subtract(Vector2 a, Vector2 b){
        return new Vector2(a.getX() - b.getX(), a.getY() - b.getY(), a.isAnchorPoint);
    }

    public static Vector2 multiply(Vector2 vec, double mult){
        return new Vector2(vec.getX() * mult, vec.getY() * mult, vec.isAnchorPoint);
    }
}
