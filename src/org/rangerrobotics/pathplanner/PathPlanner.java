package org.rangerrobotics.pathplanner;

import javafx.application.Application;
import javafx.scene.image.Image;
import javafx.stage.DirectoryChooser;
import javafx.stage.Stage;
import org.rangerrobotics.pathplanner.gui.MainScene;

import java.io.File;

public class PathPlanner extends Application {
    private static Stage mStage;

    public static void main(String[] args){
        launch(args);
    }

    @Override
    public void start(Stage stage){
        mStage = stage;
        mStage.setTitle("PathPlanner GUI");
        mStage.getIcons().add(new Image(getClass().getResourceAsStream("32.png")));
        mStage.getIcons().add(new Image(getClass().getResourceAsStream("64.png")));
        mStage.getIcons().add(new Image(getClass().getResourceAsStream("128.png")));

        mStage.setOnCloseRequest(event -> {
            event.consume();
            mStage.close();
            System.exit(0);
        });

        mStage.setScene(MainScene.getScene());
        mStage.show();
    }

    public static File getDestination(){
        DirectoryChooser chooser = new DirectoryChooser();
        chooser.setTitle("Select Destination Folder");
        if(!Preferences.destinationPath.equals("none")) {
            chooser.setInitialDirectory(new File(Preferences.destinationPath));
        }
        return chooser.showDialog(mStage);
    }
}
