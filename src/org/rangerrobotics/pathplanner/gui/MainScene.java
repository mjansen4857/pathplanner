package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Label;
import javafx.scene.control.Tab;
import javafx.scene.input.KeyCode;
import javafx.scene.input.MouseButton;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import org.rangerrobotics.pathplanner.RobotPath;
import org.rangerrobotics.pathplanner.geometry.PlannedPath;
import org.rangerrobotics.pathplanner.geometry.Util;
import org.rangerrobotics.pathplanner.geometry.Vector2;

public class MainScene {
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static JFXSnackbar snackbar;
    public static PlannedPath plannedPath;
    private static Canvas canvas;
    private static int pointDragIndex = -1;
    private static boolean isCtrlPressed = false;

    public static Scene getScene(){
        if(scene == null){
            createScene();
        }
        return scene;
    }

    private static void createScene(){
        root = new StackPane();
        layout = new JFXTabPane();
        Tab genTab = new Tab("Path");
        Tab outTab = new Tab("Output");
        Tab aboutTab = new Tab("About");

        BorderPane genTabLayout = new BorderPane();
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

        BorderPane outputTabLayout = new BorderPane();
        outputTabLayout.setCenter(new Label("Put output stuff here"));

        BorderPane aboutTabLayout = new BorderPane();
        aboutTabLayout.setCenter(new Label("Put things here"));

        canvas = new Canvas(800, 507);
        canvas.setOnMousePressed(event -> {
            if(event.getButton() == MouseButton.SECONDARY){
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(event.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(event.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        if(i % 3 == 0 && plannedPath.numSplines() > 1) {
                            if(isCtrlPressed) {
                                plannedPath.deleteSpline(i);
                                updateCanvas();
                            }
                        }
                        return;
                    }
                }
                plannedPath.addSpline(new Vector2(event.getX(), event.getY()));
                updateCanvas();
            }else if(event.getButton() == MouseButton.PRIMARY) {
                for (int i = 0; i < plannedPath.numPoints(); i++) {
                    if ((Math.pow(event.getX() - plannedPath.get(i).getX(), 2) + (Math.pow(event.getY() - plannedPath.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        if(isCtrlPressed){
                            BorderPane dialogPane = new BorderPane();
                            dialogPane.setPrefSize(350, 300);

                            HBox dialogBottom = new HBox();
                            dialogBottom.setAlignment(Pos.BOTTOM_RIGHT);
                            JFXButton dialogButton = new JFXButton("Accept");
                            dialogButton.getStyleClass().addAll("button-flat");
                            dialogButton.setPadding(new Insets(10));
                            dialogBottom.getChildren().addAll(dialogButton);

                            VBox dialogCenter = new VBox();
                            dialogCenter.setAlignment(Pos.TOP_LEFT);
                            Label dialogLabel = new Label("Test");
                            dialogLabel.setPadding(new Insets(0, 0, 50, 0));
                            dialogCenter.getChildren().addAll(dialogLabel);

                            dialogPane.setBottom(dialogBottom);
                            dialogPane.setCenter(dialogCenter);
                            JFXDialog dialog = new JFXDialog(root, dialogPane, JFXDialog.DialogTransition.CENTER);
                            dialog.show();
                        }else {
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
                        return;
                    }
                }
                updateCanvas(-1);
            }
        });
        canvas.setOnMouseDragged(event -> {
            if(pointDragIndex != -1){
                if(event.getX() >= 0 && event.getY() >= 0 && event.getX() <= canvas.getWidth() && event.getY() <= canvas.getHeight()) {
                    plannedPath.movePoint(pointDragIndex, new Vector2(event.getX(), event.getY()));
                    updateCanvas(pointDragIndex);
                }
            }
        });
        plannedPath = new PlannedPath(new Vector2(canvas.getWidth()/2, canvas.getHeight()/2));
        updateCanvas();
        HBox bottom = new HBox();
        bottom.setPadding(new Insets(10));
        bottom.setAlignment(Pos.CENTER);
        bottom.getChildren().addAll(generateButton);
        genTabLayout.setCenter(canvas);
        genTabLayout.setBottom(bottom);
        genTab.setContent(genTabLayout);

        outTab.setContent(outputTabLayout);

        aboutTab.setContent(aboutTabLayout);

        layout.getTabs().addAll(genTab, outTab, aboutTab);
        root.getChildren().add(layout);
        snackbar = new JFXSnackbar(root);

        scene = new Scene(root, 800, 600);
        scene.getStylesheets().add("org/rangerrobotics/pathplanner/gui/styles.css");

        scene.setOnKeyPressed(event -> {
            if(event.getCode() == KeyCode.CONTROL){
                isCtrlPressed = true;
            }
        });
        scene.setOnKeyReleased(event -> {
            if(event.getCode() == KeyCode.CONTROL){
                isCtrlPressed = false;
            }
        });
    }

    private static void draw(GraphicsContext g, int highlightedPoint){
        g.setFill(Color.color(0.35, 0.35, 0.35));
        g.fillRect(0, 0, canvas.getWidth(), canvas.getHeight());
        g.setLineWidth(3);
        g.setStroke(Color.color(0, 0.95, 0));
        for(int i = 0; i < plannedPath.numSplines(); i ++){
            Vector2[] points = plannedPath.getPointsInSpline(i);
            for(double d = 0.01; d <= 1; d += 0.01){
                Vector2 p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
                Vector2 p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
                g.strokeLine(p0.getX(), p0.getY(), p1.getX(), p1.getY());
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
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type));
    }

    public static void showSnackbarWithButton(String message, String type){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type, "", 1000, true, event -> snackbar.close()));
    }
}
