package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Tab;
import javafx.scene.image.Image;
import javafx.scene.input.KeyCode;
import javafx.scene.input.MouseButton;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.paint.Color;
import org.rangerrobotics.pathplanner.Preferences;
import org.rangerrobotics.pathplanner.generation.PlannedPath;
import org.rangerrobotics.pathplanner.generation.Util;
import org.rangerrobotics.pathplanner.generation.Vector2;
import org.rangerrobotics.pathplanner.io.FileManager;

public class MainScene {
    private static final int WIDTH = 1200;
    private static final int HEIGHT = 800;
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static Tab pathTab = new Tab("Path");
    private static Tab aboutTab = new Tab("About");
    private static JFXSnackbar snackbar;
    public static PlannedPath plannedPath;
    private static Canvas pathCanvas;
    private static StackPane pathTabCenter;
    private static int pointDragIndex = -1;
    private static boolean isCtrlPressed = false;
    private static boolean isShiftPressed = false;
    private static Image field;
    private static Vector2 lastMousePos = new Vector2(0, 0);

    public static Scene getScene(){
        if(scene == null){
            createScene();
        }
        return scene;
    }

    private static void createScene(){
        FileManager.loadRobotSettings();
        field = new Image(MainScene.class.getResourceAsStream("field18.png"));
        root = new StackPane();
        layout = new JFXTabPane();

        BorderPane pathTabLayout = new BorderPane();

        aboutTab.setContent(new AboutTab());

        setupCanvas();

        HBox bottom = new HBox(663);
        bottom.setPadding(new Insets(10));

        HBox bottomLeft = new HBox(10);
        bottomLeft.setAlignment(Pos.BOTTOM_LEFT);
        JFXButton saveButton = new JFXButton("Save Path");
        saveButton.setOnAction(action -> FileManager.savePath());
        saveButton.getStyleClass().add("button-raised");
        JFXButton loadButton = new JFXButton("Load Path");
        loadButton.setOnAction(action -> FileManager.loadPath());
        loadButton.getStyleClass().add("button-raised");
        bottomLeft.getChildren().addAll(saveButton, loadButton);

        HBox bottomRight = new HBox(10);
        bottomRight.setAlignment(Pos.BOTTOM_RIGHT);
        JFXButton settingsButton = new JFXButton("Robot Settings");
        settingsButton.setOnAction(action -> new RobotSettingsDialog(root).show());
        settingsButton.getStyleClass().add("button-raised");
        JFXButton generateButton = new JFXButton("Generate Path");
        generateButton.setOnAction(action -> new GenerateDialog(root).show());
        generateButton.getStyleClass().add("button-raised");
        bottomRight.getChildren().addAll(settingsButton, generateButton);

        bottom.getChildren().addAll(bottomLeft, bottomRight);
        pathTabCenter.getChildren().add(bottom);
        pathTabLayout.setCenter(pathTabCenter);
        pathTab.setContent(pathTabLayout);

        layout.getTabs().addAll(pathTab, aboutTab);
        root.getChildren().add(layout);
        snackbar = new JFXSnackbar(root);
        snackbar.setPrefWidth(WIDTH);

        scene = new Scene(root, WIDTH, HEIGHT);
        scene.getStylesheets().add("org/rangerrobotics/pathplanner/gui/styles.css");

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

    private static void drawPath(GraphicsContext g, int highlightedPoint){
        g.setLineWidth(3);
        g.setStroke(Color.color(0, 0.95, 0));
        for(int i = 0; i < plannedPath.numSplines(); i ++){
            Vector2[] points = plannedPath.getPointsInSpline(i);
            for(double d = 0; d <= 1; d += 0.01){
                Vector2 p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
                Vector2 p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
                double angle = Math.atan2(p1.getY() - p0.getY(), p1.getX() - p0.getX());
                Vector2 p0L = new Vector2(p0.getX() + (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p0.getY() - (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p0R = new Vector2(p0.getX() - (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p0.getY() + (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p1L = new Vector2(p1.getX() + (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p1.getY() - (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p1R = new Vector2(p1.getX() - (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p1.getY() + (Preferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));

                g.strokeLine(p0L.getX(), p0L.getY(), p1L.getX(), p1L.getY());
                g.strokeLine(p0R.getX(), p0R.getY(), p1R.getX(), p1R.getY());
            }
        }
        g.setStroke(Color.BLACK);
        for(int i = 0; i < plannedPath.numSplines(); i++){
            Vector2[] points = plannedPath.getPointsInSpline(i);

            g.setLineWidth(2);
            g.strokeLine(points[0].getX(), points[0].getY(), points[1].getX(), points[1].getY());
            g.strokeLine(points[2].getX(), points[2].getY(), points[3].getX(), points[3].getY());
        }

        for(int i = 0; i < plannedPath.numPoints(); i++){
            g.setStroke(Color.BLACK);
            g.setLineWidth(4);
            if(i == highlightedPoint){
                g.setFill(Color.YELLOW);
            }else if(i == 0){
                g.setFill(Color.GREEN);
            }else if(i == plannedPath.numPoints() - 1){
                g.setFill(Color.RED);
            }else{
                g.setFill(Color.WHITE);
            }
            Vector2 p = plannedPath.get(i);
            g.strokeOval(p.getX() - 6, p.getY() - 6, 12, 12);
            g.fillOval(p.getX() - 6, p.getY() - 6, 12, 12);
        }
    }

    public static void updatePathCanvas(){
        updatePathCanvas(-1);
    }

    public static void updatePathCanvas(int highlightedPoint){
        pathCanvas.getGraphicsContext2D().clearRect(0, 0, pathCanvas.getWidth(), pathCanvas.getHeight());
        drawPath(pathCanvas.getGraphicsContext2D(), highlightedPoint);
    }

    public static void showSnackbarMessage(String message, String type){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type, null, 3500, false, null));
    }

    private static void setupCanvas(){
        pathTabCenter = new StackPane();
        pathCanvas = new Canvas(WIDTH, HEIGHT - 35);
        pathTabCenter.setOnMousePressed(event -> {
            if(event.getButton() == MouseButton.SECONDARY){
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(event.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(event.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        if(i % 3 == 0 && plannedPath.numSplines() > 1) {
                            plannedPath.deleteSpline(i);
                            updatePathCanvas();
                        }
                        return;
                    }
                }
                plannedPath.addSpline(new Vector2(event.getX(), event.getY()));
                updatePathCanvas();
            }else if(event.getButton() == MouseButton.PRIMARY || event.getButton() == MouseButton.MIDDLE) {
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(event.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(event.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        if((isCtrlPressed || event.getButton() == MouseButton.MIDDLE) && i % 3 == 0){
                            PointConfigDialog dialog = new PointConfigDialog(root, i);
                            dialog.show();
                        }else if(event.getButton() != MouseButton.MIDDLE){
                            pointDragIndex = i;
                        }
                    }
                }
            }
        });
        pathTabCenter.setOnMouseReleased(event -> {
            pointDragIndex = -1;
        });
        pathTabCenter.setOnMouseMoved(event -> {
            if(event.getButton() == MouseButton.NONE){
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(event.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(event.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        updatePathCanvas(i);
                        lastMousePos = new Vector2(event.getX(), event.getY());
                        return;
                    }
                }
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(lastMousePos.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(lastMousePos.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        updatePathCanvas(-1);
                        lastMousePos = new Vector2(event.getX(), event.getY());
                        return;
                    }
                }
                lastMousePos = new Vector2(event.getX(), event.getY());
            }
            lastMousePos = new Vector2(event.getX(), event.getY());
        });
        pathTabCenter.setOnMouseDragged(event -> {
            if(pointDragIndex != -1){
                if(event.getX() >= 0 && event.getY() >= 0 && event.getX() <= pathCanvas.getWidth() && event.getY() <= pathCanvas.getHeight()) {
                    if(isShiftPressed && pointDragIndex % 3 != 0){
                        int controlIndex = pointDragIndex;
                        boolean nextIsAnchor = (controlIndex + 1) % 3 == 0;
                        int anchorIndex = (nextIsAnchor) ? controlIndex + 1 : controlIndex - 1;
                        Vector2 lineStart = plannedPath.get(anchorIndex);
                        Vector2 lineEnd = Vector2.add(plannedPath.get(controlIndex), Vector2.subtract(plannedPath.get(controlIndex), plannedPath.get(anchorIndex)));
                        Vector2 p = new Vector2(event.getX(), event.getY());
                        Vector2 newPoint = Util.closestPointOnLine(lineStart, lineEnd, p);
                        if(newPoint.getX() - lineStart.getX() != 0 || newPoint.getY() - lineStart.getY() != 0){
                            plannedPath.movePoint(controlIndex, newPoint);
                        }
                    }else{
                        plannedPath.movePoint(pointDragIndex, new Vector2(event.getX(), event.getY()));
                    }
                    updatePathCanvas(pointDragIndex);
                }
            }
        });
        plannedPath = new PlannedPath(new Vector2(pathCanvas.getWidth()/2, pathCanvas.getHeight()/2));
        updatePathCanvas();
        Canvas fieldCanvas = new Canvas(WIDTH, HEIGHT - 35);
        fieldCanvas.getGraphicsContext2D().drawImage(field, 0, 80);
        pathTabCenter.getChildren().addAll(fieldCanvas, pathCanvas);
    }
}
