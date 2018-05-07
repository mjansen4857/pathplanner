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
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static Tab pathTab = new Tab("Path");
    private static Tab settingsTab = new Tab("Settings");
    private static Tab aboutTab = new Tab("About");
    private static JFXSnackbar snackbar;
    public static PlannedPath plannedPath;
    private static Canvas canvas;
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
        JFXButton generateButton = new JFXButton("Generate");
        generateButton.setOnAction(action -> {
            new Thread(() -> {
                long start = System.currentTimeMillis();
                RobotPath robotPath = new RobotPath(plannedPath);
                System.out.println("FINISHED! Total Time: " + ((double)(System.currentTimeMillis() - start)) / 1000 + " s");
                System.out.println("LEFT:\n" + robotPath.left.toString());
                System.out.println("RIGHT:\n" + robotPath.right.toString());
            }).start();
        });
        generateButton.getStyleClass().addAll("button-raised");
        pathTabLayout.getStyleClass().add("dark-bg");

        setupSettingsTab();

        BorderPane aboutTabLayout = new BorderPane();
        aboutTabLayout.setCenter(new Label("Put things here"));
        aboutTab.setContent(aboutTabLayout);

        setupCanvas();

        HBox bottom = new HBox();
        bottom.setPadding(new Insets(10));
        bottom.setAlignment(Pos.CENTER);
        bottom.getChildren().addAll(generateButton);
        pathTabLayout.setCenter(canvas);
        pathTabLayout.setBottom(bottom);
        pathTab.setContent(pathTabLayout);

        layout.getTabs().addAll(pathTab, settingsTab, aboutTab);
        root.getChildren().add(layout);
        snackbar = new JFXSnackbar(root);
        snackbar.setPrefWidth(800);

        scene = new Scene(root, 800, 740);
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
        g.drawImage(field, 0, 50);
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

    private static void updateCanvas(){
        updateCanvas(-1);
    }

    private static void updateCanvas(int highlightedPoint){
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
        canvas = new Canvas(800, 647);
        canvas.setOnMousePressed(event -> {
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
                            final JFXDialog dialog = new JFXDialog();
                            BorderPane dialogPane = new BorderPane();
                            dialogPane.setPrefSize(350, 300);

                            VBox dialogCenter = new VBox(20);
                            dialogCenter.setAlignment(Pos.TOP_LEFT);
                            dialogCenter.setPadding(new Insets(5, 8, 5, 8));
                            Label dialogHeading = new Label("Anchor Point Configuration");
                            dialogHeading.getStyleClass().addAll("dialog-heading");
                            dialogHeading.setPadding(new Insets(0, 0, 10, 0));

                            HBox xPositionContainer = new HBox(20);
                            xPositionContainer.setAlignment(Pos.CENTER);
                            Label xPositionLabel = new Label("X Position:");
                            xPositionLabel.getStyleClass().addAll("text-field-label");
                            JFXTextField xPositionTxtField = new JFXTextField();
                            xPositionTxtField.setValidators(new DoubleValidator());
                            xPositionTxtField.setAlignment(Pos.CENTER);
                            xPositionTxtField.setText("" + (plannedPath.get(i).getX() - PlannedPath.xPixelOffset) / PlannedPath.pixelsPerFoot);
                            xPositionContainer.getChildren().addAll(xPositionLabel, xPositionTxtField);

                            HBox yPositionContainer = new HBox(20);
                            yPositionContainer.setAlignment(Pos.CENTER);
                            Label yPositionLabel = new Label("Y Position:");
                            yPositionLabel.getStyleClass().addAll("text-field-label");
                            JFXTextField yPositionTxtField = new JFXTextField();
                            yPositionTxtField.setValidators(new DoubleValidator());
                            yPositionTxtField.setAlignment(Pos.CENTER);
                            yPositionTxtField.setText("" + (plannedPath.get(i).getY() - PlannedPath.yPixelOffset) / PlannedPath.pixelsPerFoot);
                            yPositionContainer.getChildren().addAll(yPositionLabel, yPositionTxtField);

                            HBox angleContainer = new HBox(20);
                            angleContainer.setAlignment(Pos.CENTER);
                            Label angleLabel = new Label("Angle:");
                            angleLabel.getStyleClass().addAll("text-field-label");
                            JFXTextField angleTxtField = new JFXTextField();
                            angleTxtField.setValidators(new DoubleValidator());
                            angleTxtField.setAlignment(Pos.CENTER);
                            Vector2 anchor = plannedPath.get(i);
                            Vector2 control;
                            if(i == plannedPath.numPoints() - 1){
                                control = Vector2.subtract(anchor, Vector2.subtract(plannedPath.get(i - 1), anchor));
                            }else{
                                control = plannedPath.get(i + 1);
                            }
                            double angle = Math.toDegrees(Math.atan2(control.getY() - anchor.getY(), control.getX() - anchor.getX()));
                            angleTxtField.setText("" + angle);
                            angleContainer.getChildren().addAll(angleLabel, angleTxtField);

                            dialogCenter.getChildren().addAll(dialogHeading, xPositionContainer, yPositionContainer, angleContainer);

                            HBox dialogBottom = new HBox();
                            dialogBottom.setPadding(new Insets(0, 3, 2, 0));
                            dialogBottom.setAlignment(Pos.BOTTOM_RIGHT);
                            JFXButton dialogButton = new JFXButton("ACCEPT");
                            dialogButton.getStyleClass().addAll("button-flat");
                            dialogButton.setPadding(new Insets(10));
                            final int anchorIndex = i;
                            dialogButton.setOnAction(action -> {
                                if(xPositionTxtField.validate() && yPositionTxtField.validate() && angleTxtField.validate() && (Double.parseDouble(angleTxtField.getText()) >= -180 && Double.parseDouble(angleTxtField.getText()) <= 180)){
                                    plannedPath.movePoint(anchorIndex, new Vector2((Double.parseDouble(xPositionTxtField.getText()) * PlannedPath.pixelsPerFoot) + PlannedPath.xPixelOffset, (Double.parseDouble(yPositionTxtField.getText()) * PlannedPath.pixelsPerFoot) + PlannedPath.yPixelOffset));
                                    double theta = Math.toRadians(Double.parseDouble(angleTxtField.getText()));
                                    double h = Vector2.subtract(anchor, control).getMagnitude();
                                    double o = Math.sin(theta) * h;
                                    double a = Math.cos(theta) * h;
                                    int controlIndex;
                                    if(anchorIndex == plannedPath.numPoints() - 1){
                                        controlIndex = anchorIndex - 1;
                                        plannedPath.movePoint(controlIndex, Vector2.subtract(plannedPath.get(anchorIndex), new Vector2(a, o)));
                                    }else{
                                        controlIndex = anchorIndex + 1;
                                        plannedPath.movePoint(controlIndex, Vector2.add(plannedPath.get(anchorIndex), new Vector2(a, o)));
                                    }
                                    updateCanvas();
                                }else{
                                    showSnackbarMessage("Invalid Inputs!", "error");
                                }
                                dialog.close();
                            });
                            dialogBottom.getChildren().addAll(dialogButton);

                            dialogPane.setBottom(dialogBottom);
                            dialogPane.setCenter(dialogCenter);
                            dialog.setDialogContainer(root);
                            dialog.setContent(dialogPane);
                            dialog.setTransitionType(JFXDialog.DialogTransition.CENTER);
                            dialog.show();
                        }else if(event.getButton() != MouseButton.MIDDLE){
                            pointDragIndex = i;
                        }
                    }
                }
            }
        });
        canvas.setOnMouseReleased(event -> {
            pointDragIndex = -1;
        });
        canvas.setOnMouseMoved(event -> {
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
        canvas.setOnMouseDragged(event -> {
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
    }
}
