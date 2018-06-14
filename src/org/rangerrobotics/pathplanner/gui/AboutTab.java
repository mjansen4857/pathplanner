package org.rangerrobotics.pathplanner.gui;

import javafx.scene.control.Label;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.StackPane;

public class AboutTab extends StackPane {
    private BorderPane layout;

    public AboutTab(){
        layout = new BorderPane();
        layout.setCenter(new Label("Test"));

        this.getChildren().add(layout);
    }
}
