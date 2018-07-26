package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import javafx.scene.Scene;
import javafx.scene.control.Tab;
import javafx.scene.input.KeyCode;
import javafx.scene.layout.StackPane;
import org.rangerrobotics.pathplanner.GeneralPreferences;
import org.rangerrobotics.pathplanner.io.FileManager;

public class MainScene {
    public static final int WIDTH = 1200;
    public static final int HEIGHT = 800;
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane tabs;
    private static Tab tab18 = new Tab("2018 - Power Up");
    private static Tab tab19 = new Tab("2019 - Deep Space");
    private static JFXSnackbar snackbar;
    public static boolean isCtrlPressed = false;
    public static boolean isShiftPressed = false;
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
        snackbar.setPrefWidth(WIDTH);

        scene = new Scene(root, WIDTH, HEIGHT);
        scene.getStylesheets().add("org/rangerrobotics/pathplanner/gui/res/styles.css");

        scene.setOnKeyPressed(event -> {
            if(event.getCode() == KeyCode.CONTROL){
                isCtrlPressed = true;
            }else if(event.getCode() == KeyCode.SHIFT){
                isShiftPressed = true;
            }
        });
        scene.setOnKeyReleased(event -> {
            if(event.getCode() == KeyCode.CONTROL){
                isCtrlPressed = false;
            }else if(event.getCode() == KeyCode.SHIFT){
                isShiftPressed = false;
            }
        });
    }

    public static void showSnackbarMessage(String message, String type){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type, null, 3500, false, null));
    }
}
