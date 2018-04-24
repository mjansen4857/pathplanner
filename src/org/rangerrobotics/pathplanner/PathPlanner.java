package org.rangerrobotics.pathplanner;

import javafx.application.Application;
import javafx.scene.image.Image;
import javafx.stage.Stage;
import org.rangerrobotics.pathplanner.gui.MainScene;

public class PathPlanner extends Application {

    public static void main(String[] args){
        launch(args);
    }

    @Override
    public void start(Stage stage){
        stage.setTitle("Path Planner GUI");
        stage.getIcons().add(new Image(getClass().getResourceAsStream("32.png")));
        stage.getIcons().add(new Image(getClass().getResourceAsStream("64.png")));
        stage.getIcons().add(new Image(getClass().getResourceAsStream("128.png")));

        stage.setOnCloseRequest(event -> {
            event.consume();
            stage.close();
            System.exit(0);
        });

        stage.setScene(MainScene.getScene());
        stage.show();
    }
}
