package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Tab;
import javafx.scene.input.MouseButton;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.paint.Color;
import org.rangerrobotics.pathplanner.Path;
import org.rangerrobotics.pathplanner.RobotPath;
import org.rangerrobotics.pathplanner.geometry.CurvyBoi;
import org.rangerrobotics.pathplanner.geometry.SegmentGroup;
import org.rangerrobotics.pathplanner.geometry.Util;
import org.rangerrobotics.pathplanner.geometry.Vector2;

public class MainScene {
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static JFXSnackbar snackbar;
    public static CurvyBoi curvyBoi;
    private static Canvas canvas;
    private static int pointDragIndex = -1;

    public static Scene getScene(){
        if(scene == null){
            createScene();
        }
        return scene;
    }

    private static void createScene(){
        curvyBoi = new CurvyBoi();

        root = new StackPane();
        layout = new JFXTabPane();
        Tab genTab = new Tab();
        genTab.setText("Path");
        Tab outTab = new Tab();
        outTab.setText("Output");

        BorderPane genTabLayout = new BorderPane();
        JFXButton test = new JFXButton("Generate");
        test.setOnAction(action -> {
            //TEST FINALIZE PATH
            new Thread(() -> {
                SegmentGroup s = curvyBoi.join(0.000005);
                Path path = new Path(s);
                RobotPath bot = new RobotPath(path);
            }).start();
        });
//        VBox genLeft = new VBox(10);
//        genLeft.getChildren().addAll(new Label("Henlo"), test);
//        genTabLayout.setLeft(genLeft);

        canvas = new Canvas(800, 507);
        canvas.setOnMousePressed(event -> {
            if(event.getButton() == MouseButton.SECONDARY){
                for (int i = 0; i < curvyBoi.numPoints(); i++) {
                    if ((Math.pow(event.getX() - curvyBoi.get(i).getX(), 2) + (Math.pow(event.getY() - curvyBoi.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        if(i % 3 == 0 && curvyBoi.numSplines() > 1) {
                            curvyBoi.deleteSpline(i);
                            updateCanvas();
                        }
                        return;
                    }
                }
                curvyBoi.addSpline(new Vector2(event.getX(), event.getY()));
                updateCanvas();
            }else if(event.getButton() == MouseButton.PRIMARY) {
                for (int i = 0; i < curvyBoi.numPoints(); i++) {
                    if ((Math.pow(event.getX() - curvyBoi.get(i).getX(), 2) + (Math.pow(event.getY() - curvyBoi.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        pointDragIndex = i;
                    }
                }
            }
        });
        canvas.setOnMouseReleased(event -> {
            pointDragIndex = -1;
        });
        canvas.setOnMouseMoved(event -> {
            if(event.getButton() == MouseButton.NONE){
                for (int i = 0; i < curvyBoi.numPoints(); i++) {
                    if ((Math.pow(event.getX() - curvyBoi.get(i).getX(), 2) + (Math.pow(event.getY() - curvyBoi.get(i).getY(), 2))) <= Math.pow(8, 2)) {
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
                    curvyBoi.movePoint(pointDragIndex, new Vector2(event.getX(), event.getY()));
                    updateCanvas(pointDragIndex);
                }
            }
        });
        draw(canvas.getGraphicsContext2D(), -1);
        HBox bottom = new HBox();
        bottom.setPadding(new Insets(10));
        bottom.setAlignment(Pos.CENTER);
        bottom.getChildren().addAll(test);
        genTabLayout.setCenter(canvas);
        genTabLayout.setBottom(bottom);

        genTab.setContent(genTabLayout);

        layout.getTabs().addAll(genTab, outTab);
        root.getChildren().add(layout);
        snackbar = new JFXSnackbar(root);

        scene = new Scene(root, 800, 600);
        scene.getStylesheets().add("org/rangerrobotics/pathplanner/gui/styles.css");
    }

    private static void draw(GraphicsContext g, int highlightedPoint){
        g.setFill(Color.color(0.35, 0.35, 0.35));
        g.fillRect(0, 0, canvas.getWidth(), canvas.getHeight());
        g.setLineWidth(3);
        g.setStroke(Color.color(0, 0.95, 0));
        for(int i = 0; i < curvyBoi.numSplines(); i ++){
            Vector2[] points = curvyBoi.getPointsInSpline(i);
            for(double d = 0.01; d <= 1; d += 0.01){
                Vector2 p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
                Vector2 p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
                g.strokeLine(p0.getX(), p0.getY(), p1.getX(), p1.getY());
            }
        }
        g.setStroke(Color.BLACK);
        for(int i = 0; i < curvyBoi.numSplines(); i++){
            Vector2[] points = curvyBoi.getPointsInSpline(i);

            g.setLineWidth(2);
            g.strokeLine(points[0].getX(), points[0].getY(), points[1].getX(), points[1].getY());
            g.strokeLine(points[2].getX(), points[2].getY(), points[3].getX(), points[3].getY());
        }

        for(int i = 0; i < curvyBoi.numPoints(); i++){
            if(i == highlightedPoint){
                g.setFill(Color.YELLOW);
            }else{
                g.setFill(Color.RED);
            }
            Vector2 p = curvyBoi.get(i);
            g.fillOval(p.getX() - 8, p.getY() - 8, 16, 16);
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
