package org.rangerrobotics.pathplanner.gui;

import javafx.scene.canvas.Canvas;
import javafx.scene.layout.StackPane;

public class PathPreview extends StackPane {
    Canvas canvas = new Canvas();

    public PathPreview(){
        this.getChildren().add(canvas);
    }
}
