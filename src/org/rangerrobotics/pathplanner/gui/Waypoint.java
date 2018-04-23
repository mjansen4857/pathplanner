package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.datamodels.treetable.RecursiveTreeObject;
import javafx.beans.property.SimpleDoubleProperty;

public class Waypoint extends RecursiveTreeObject<Waypoint> {
    SimpleDoubleProperty x;
    SimpleDoubleProperty y;
    SimpleDoubleProperty angle;
    SimpleDoubleProperty speed;

    public Waypoint(double x, double y, double angle, double speed){
        this.x = new SimpleDoubleProperty(x);
        this.y = new SimpleDoubleProperty(y);
        this.angle = new SimpleDoubleProperty(angle);
        this.speed = new SimpleDoubleProperty(speed);
    }
}
