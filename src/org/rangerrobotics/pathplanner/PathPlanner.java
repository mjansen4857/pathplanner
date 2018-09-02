package org.rangerrobotics.pathplanner;

import javafx.application.Application;
import javafx.scene.image.Image;
import javafx.stage.DirectoryChooser;
import javafx.stage.FileChooser;
import javafx.stage.Stage;
import org.kohsuke.github.GHRepository;
import org.kohsuke.github.GitHub;
import org.rangerrobotics.pathplanner.gui.MainScene;

import java.io.File;
import java.io.IOException;

public class PathPlanner extends Application {
    private static Stage mStage;
    public static final String VERSION =  "v0.10";

    public static void main(String[] args){
        launch(args);
    }

    @Override
    public void start(Stage stage){
        mStage = stage;
        mStage.setTitle("PathPlanner " + VERSION);
        mStage.getIcons().add(new Image(getClass().getResourceAsStream("icon.png")));

        mStage.setOnCloseRequest(event -> {
            event.consume();
            mStage.close();
            System.exit(0);
        });

        mStage.setScene(MainScene.getScene());
        mStage.show();

        new Thread(() -> {
            try {
                GitHub github = GitHub.connectAnonymously();
                GHRepository repo = github.getRepository("mjansen4857/PathPlanner");
                String lastReleaseVersion = repo.getLatestRelease().getTagName().substring(1);
                int major = Integer.parseInt(lastReleaseVersion.substring(0, lastReleaseVersion.indexOf(".")));
                int minor = Integer.parseInt(lastReleaseVersion.substring(lastReleaseVersion.indexOf(".") + 1));
                int thisMajor = Integer.parseInt(VERSION.substring(1, VERSION.indexOf(".")));
                int thisMinor = Integer.parseInt(VERSION.substring(VERSION.indexOf(".") + 1));
                if(major > thisMajor || (major == thisMajor && minor > thisMinor)){
                    MainScene.showUpdateSnackbar("PathPlanner v" + lastReleaseVersion + " is now available!");
                }
            }catch(IOException e){
                e.printStackTrace();
            }
        }).start();
    }

    public static File chooseOutputFolder(PathPreferences pathPreferences){
        DirectoryChooser chooser = new DirectoryChooser();
        chooser.setTitle("Select Destination Folder...");
        if(!pathPreferences.lastGenerateDir.equals("none")) {
            chooser.setInitialDirectory(new File(pathPreferences.lastGenerateDir));
        }
        return chooser.showDialog(mStage);
    }

    public static File chooseSaveFile(PathPreferences pathPreferences){
        FileChooser chooser = new FileChooser();
        chooser.setTitle("Save as...");
        chooser.getExtensionFilters().add(new FileChooser.ExtensionFilter("PATH files (*.path)", "*.path"));
        chooser.setInitialFileName(pathPreferences.currentPathName);
        if(!pathPreferences.lastPathDir.equals("none")) {
            chooser.setInitialDirectory(new File(pathPreferences.lastPathDir));
        }
        return chooser.showSaveDialog(mStage);
    }

    public static File chooseLoadFile(PathPreferences pathPreferences){
        FileChooser chooser = new FileChooser();
        chooser.setTitle("Open path...");
        chooser.getExtensionFilters().add(new FileChooser.ExtensionFilter("PATH files (*.path)", "*.path"));
        if(!pathPreferences.lastPathDir.equals("none")) {
            chooser.setInitialDirectory(new File(pathPreferences.lastPathDir));
        }
        return chooser.showOpenDialog(mStage);
    }
}
