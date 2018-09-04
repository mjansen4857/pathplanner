package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import javafx.scene.Scene;
import javafx.scene.control.Tab;
import javafx.scene.layout.StackPane;
import org.rangerrobotics.pathplanner.GeneralPreferences;
import org.rangerrobotics.pathplanner.io.FileManager;

import java.awt.*;
import java.net.URI;
import java.net.URL;

public class MainScene {
    public static final int WIDTH = 1200;
    public static final int HEIGHT = 800;
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane tabs;
    private static Tab tab18 = new Tab("2018 - Power Up");
    private static Tab tab19 = new Tab("2019 - Deep Space");
    private static JFXSnackbar snackbar;
    private static GeneralPreferences generalPreferences;

    public static Scene getScene(){
        if(scene == null){
            createScene();
        }
        return scene;
    }

    private static void createScene(){
        generalPreferences = FileManager.loadGeneralSettings();

        root = new StackPane();

        tabs = new JFXTabPane();
        tab18.setContent(new PathEditor("18"));
        tab19.setContent(new PathEditor("19"));
        tabs.getTabs().addAll(tab18, tab19);
        tabs.getSelectionModel().selectedIndexProperty().addListener((ov, from, to) -> {
            int currentTab = to.intValue();
            generalPreferences.tabIndex = currentTab;
            FileManager.saveGeneralSettings(generalPreferences);
        });
        tabs.getSelectionModel().select(generalPreferences.tabIndex);

        root.getChildren().add(tabs);
        snackbar = new JFXSnackbar(root);

        scene = new Scene(root, WIDTH, HEIGHT);
        scene.getStylesheets().add("org/rangerrobotics/pathplanner/gui/res/styles.css");
    }

    public static void showSnackbarMessage(String message, String type){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type, null, 3500, false, null));
    }

    public static void showSnackbarMessage(String message, String type, int timeout){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type, null, timeout, false, null));
    }

    public static void showUpdateSnackbar(String message){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, "success", "Download", -1, true, event -> {
            try{
                URI githubLink =  new URL("https://github.com/mjansen4857/PathPlanner/releases").toURI();
                Desktop desktop = Desktop.isDesktopSupported() ? Desktop.getDesktop() : null;
                if(desktop != null && desktop.isSupported(Desktop.Action.BROWSE)){
                    desktop.browse(githubLink);
                }
            }catch (Exception e){
                e.printStackTrace();
            }
        }));
    }
}
