package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import com.jfoenix.validation.DoubleValidator;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Label;
import javafx.scene.control.Tab;
import javafx.scene.image.Image;
import javafx.scene.input.KeyCode;
import javafx.scene.input.MouseButton;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import org.rangerrobotics.pathplanner.generation.RobotPath;
import org.rangerrobotics.pathplanner.generation.PlannedPath;
import org.rangerrobotics.pathplanner.generation.Util;
import org.rangerrobotics.pathplanner.generation.Vector2;

public class MainScene {
    private static final int WIDTH = 1174;
    private static final int HEIGT = 740;
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static Tab pathTab = new Tab("Path");
    private static Tab settingsTab = new Tab("Settings");
    private static Tab aboutTab = new Tab("About");
    private static JFXSnackbar snackbar;
    public static PlannedPath plannedPath;
    private static Canvas canvas;
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
        field = new Image(MainScene.class.getResourceAsStream("field.png"));
        root = new StackPane();
        layout = new JFXTabPane();

        BorderPane pathTabLayout = new BorderPane();
        StackPane generateContainer = new StackPane();
        generateContainer.setPrefWidth(WIDTH/2);
        generateContainer.setAlignment(Pos.BOTTOM_RIGHT);
        JFXButton generateButton = new JFXButton("Generate Path");
        generateButton.setOnAction(action -> {
            new Thread(() -> {
                long start = System.currentTimeMillis();
                RobotPath robotPath = new RobotPath(plannedPath);
                System.out.println("FINISHED! Total Time: " + ((double)(System.currentTimeMillis() - start)) / 1000 + " s");
                System.out.println("LEFT:\n" + robotPath.left.toString());
                System.out.println("RIGHT:\n" + robotPath.right.toString());
            }).start();
        });
        generateButton.getStyleClass().add("button-raised");
        generateContainer.getChildren().add(generateButton);

        JFXButton configButton = new JFXButton("Config Robot");
        StackPane configContainer = new StackPane();
        configContainer.setPrefWidth(WIDTH/2);
        configContainer.setAlignment(Pos.BOTTOM_LEFT);
        configButton.setOnAction(action -> {

        });
        configButton.getStyleClass().add("button-raised");
        configContainer.getChildren().add(configButton);
        pathTabLayout.getStyleClass().add("dark-bg");

        setupSettingsTab();

        BorderPane aboutTabLayout = new BorderPane();
        aboutTabLayout.setCenter(new Label("Put things here"));
        aboutTab.setContent(aboutTabLayout);

        setupCanvas();

        HBox bottom = new HBox(10);
        bottom.setPadding(new Insets(10));
        bottom.getChildren().addAll(configContainer, generateContainer);
        pathTabCenter.getChildren().add(bottom);
        pathTabLayout.setCenter(pathTabCenter);
//        pathTabLayout.setBottom(bottom);
        pathTab.setContent(pathTabLayout);

        layout.getTabs().addAll(pathTab, settingsTab, aboutTab);
        root.getChildren().add(layout);
        snackbar = new JFXSnackbar(root);
        snackbar.setPrefWidth(WIDTH);

        scene = new Scene(root, WIDTH, HEIGT);
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

    private static void draw(GraphicsContext g, int highlightedPoint){
//        g.setFill(Color.color(0.35, 0.35, 0.35));
        g.setFill(Color.color(133/255., 132/255., 141/255.));
        g.fillRect(0, 0, canvas.getWidth(), canvas.getHeight());
        g.drawImage(field, 0, 79);
        g.setLineWidth(3);
        g.setStroke(Color.color(0, 0.95, 0));
        for(int i = 0; i < plannedPath.numSplines(); i ++){
            Vector2[] points = plannedPath.getPointsInSpline(i);
            for(double d = 0; d <= 1; d += 0.01){
                Vector2 p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
                Vector2 p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
                double angle = Math.atan2(p1.getY() - p0.getY(), p1.getX() - p0.getX());
                Vector2 p0L = new Vector2(p0.getX() + (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p0.getY() - (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p0R = new Vector2(p0.getX() - (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p0.getY() + (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p1L = new Vector2(p1.getX() + (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p1.getY() - (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p1R = new Vector2(p1.getX() - (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p1.getY() + (RobotPath.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));

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

    public static void updateCanvas(){
        updateCanvas(-1);
    }

    public static void updateCanvas(int highlightedPoint){
        canvas.getGraphicsContext2D().clearRect(0, 0, canvas.getWidth(), canvas.getHeight());
        draw(canvas.getGraphicsContext2D(), highlightedPoint);
    }

    public static void showSnackbarMessage(String message, String type){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type, null, 3500, false, null));
    }

    private static void setupSettingsTab(){
        BorderPane settingsTabLayout = new BorderPane();
        VBox settingsLeft = new VBox(20);
        settingsLeft.setPadding(new Insets(0, 0, 0, 10));

        HBox maxV = new HBox(20);
        maxV.setAlignment(Pos.CENTER_LEFT);
        Label maxVLabel = new Label("Max Velocity:");
        maxVLabel.getStyleClass().add("text-field-label");
        JFXTextField maxVTxt = new JFXTextField();
        maxVTxt.setText("" + RobotPath.maxVel);
        maxVTxt.setValidators(new DoubleValidator());
        maxVTxt.setAlignment(Pos.CENTER);
        maxV.getChildren().addAll(maxVLabel, maxVTxt);
        settingsLeft.getChildren().add(maxV);

        HBox maxAcc = new HBox(20);
        maxAcc.setAlignment(Pos.CENTER_LEFT);
        Label maxAccLabel = new Label("Max Acceleration:");
        maxAccLabel.getStyleClass().add("text-field-label");
        JFXTextField maxAccTxt = new JFXTextField();
        maxAccTxt.setText("" + RobotPath.maxAcc);
        maxAccTxt.setValidators(new DoubleValidator());
        maxAccTxt.setAlignment(Pos.CENTER);
        maxAcc.getChildren().addAll(maxAccLabel, maxAccTxt);
        settingsLeft.getChildren().add(maxAcc);

        HBox maxDcc = new HBox(20);
        maxDcc.setAlignment(Pos.CENTER_LEFT);
        Label maxDccLabel = new Label("Max Deceleration:");
        maxDccLabel.getStyleClass().add("text-field-label");
        JFXTextField maxDccTxt = new JFXTextField();
        maxDccTxt.setText("" + RobotPath.maxDcc);
        maxDccTxt.setValidators(new DoubleValidator());
        maxDccTxt.setAlignment(Pos.CENTER);
        maxDcc.getChildren().addAll(maxDccLabel, maxDccTxt);
        settingsLeft.getChildren().add(maxDcc);

        HBox wheelbaseWidth = new HBox(20);
        wheelbaseWidth.setAlignment(Pos.CENTER_LEFT);
        Label wheelbaseWidthLabel = new Label("Wheelbase Width:");
        wheelbaseWidthLabel.getStyleClass().add("text-field-label");
        JFXTextField wheelbaseWidthTxt = new JFXTextField();
        wheelbaseWidthTxt.setText("" + RobotPath.wheelbaseWidth);
        wheelbaseWidthTxt.setValidators(new DoubleValidator());
        wheelbaseWidthTxt.setAlignment(Pos.CENTER);
        wheelbaseWidth.getChildren().addAll(wheelbaseWidthLabel, wheelbaseWidthTxt);
        settingsLeft.getChildren().add(wheelbaseWidth);

        HBox timestep = new HBox(20);
        timestep.setAlignment(Pos.CENTER_LEFT);
        Label timestepLabel = new Label("Delta Time:");
        timestepLabel.getStyleClass().add("text-field-label");
        JFXTextField timestepTxt = new JFXTextField();
        timestepTxt.setText("" + RobotPath.segmentTime);
        timestepTxt.setValidators(new DoubleValidator());
        timestepTxt.setAlignment(Pos.CENTER);
        timestep.getChildren().addAll(timestepLabel, timestepTxt);
        settingsLeft.getChildren().add(timestep);

        settingsTabLayout.setLeft(settingsLeft);
        settingsTab.setContent(settingsTabLayout);
    }

    private static void setupCanvas(){
        pathTabCenter = new StackPane();
        canvas = new Canvas(WIDTH, 705);
        pathTabCenter.setOnMousePressed(event -> {
            if(event.getButton() == MouseButton.SECONDARY){
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(event.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(event.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        if(i % 3 == 0 && plannedPath.numSplines() > 1) {
                            plannedPath.deleteSpline(i);
                            updateCanvas();
                        }
                        return;
                    }
                }
                plannedPath.addSpline(new Vector2(event.getX(), event.getY()));
                updateCanvas();
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
                        updateCanvas(i);
                        lastMousePos = new Vector2(event.getX(), event.getY());
                        return;
                    }
                }
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(lastMousePos.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(lastMousePos.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        updateCanvas(-1);
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
                if(event.getX() >= 0 && event.getY() >= 0 && event.getX() <= canvas.getWidth() && event.getY() <= canvas.getHeight()) {
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
                    updateCanvas(pointDragIndex);
                }
            }
        });
        plannedPath = new PlannedPath(new Vector2(canvas.getWidth()/2, canvas.getHeight()/2));
        updateCanvas();
        pathTabCenter.getChildren().add(canvas);
    }
}
