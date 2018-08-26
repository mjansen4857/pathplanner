package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.JFXButton;
import javafx.animation.AnimationTimer;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Tooltip;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.input.MouseButton;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.paint.Color;
import javafx.stage.Stage;
import org.rangerrobotics.pathplanner.PathPreferences;
import org.rangerrobotics.pathplanner.generation.*;
import org.rangerrobotics.pathplanner.gui.dialog.GenerateDialog;
import org.rangerrobotics.pathplanner.gui.dialog.PointConfigDialog;
import org.rangerrobotics.pathplanner.gui.dialog.RobotSettingsDialog;
import org.rangerrobotics.pathplanner.io.FileManager;

import java.util.ArrayList;

public class PathEditor extends StackPane {
    public PlannedPath plannedPath;
    private Canvas pathCanvas;
    private StackPane center;
    private int pointDragIndex = -1;
    private Image field;
    private Vector2 lastMousePos = new Vector2(0, 0);
    public PathPreferences pathPreferences;

    public PathEditor(String year){
        this.field = new Image(this.getClass().getResourceAsStream("res/field" + year + ".png"));
        this.pathPreferences = FileManager.loadRobotSettings(year);

        setupCanvas();

        BorderPane layout = new BorderPane();

        HBox bottom = new HBox(965);
        bottom.setPadding(new Insets(10));

        HBox bottomLeft = new HBox(5);
        bottomLeft.setAlignment(Pos.BOTTOM_LEFT);
        JFXButton saveButton = new JFXButton();
        saveButton.setTooltip(new Tooltip("Save Path"));
        saveButton.getStyleClass().add("icon-button");
        saveButton.setGraphic(new ImageView(new Image(this.getClass().getResourceAsStream("res/save.png"))));
        saveButton.setOnAction(action -> FileManager.savePath(this));
        JFXButton loadButton = new JFXButton();
        loadButton.setTooltip(new Tooltip("Load Path"));
        loadButton.getStyleClass().add("icon-button");
        loadButton.setGraphic(new ImageView(new Image(this.getClass().getResourceAsStream("res/load.png"))));
        loadButton.setOnAction(action -> FileManager.loadPath(this));
        bottomLeft.getChildren().addAll(saveButton, loadButton);

        HBox bottomRight = new HBox(5);
        bottomRight.setAlignment(Pos.BOTTOM_RIGHT);
        JFXButton settingsButton = new JFXButton();
        settingsButton.setTooltip(new Tooltip("Robot Settings"));
        settingsButton.getStyleClass().add("icon-button");
        settingsButton.setGraphic(new ImageView(new Image(this.getClass().getResourceAsStream("res/settings.png"))));
        settingsButton.setOnAction(action -> new RobotSettingsDialog(this).show());
        JFXButton generateButton = new JFXButton();
        generateButton.setTooltip(new Tooltip("Generate Path"));
        generateButton.setOnAction(action -> new GenerateDialog(this).show());
        generateButton.getStyleClass().add("icon-button");
        generateButton.setGraphic(new ImageView(new Image(this.getClass().getResourceAsStream("res/generate.png"))));
        JFXButton previewButton = new JFXButton();
        previewButton.setTooltip(new Tooltip("Preview Path"));
        previewButton.setOnAction(action -> {
            pathCanvas.getGraphicsContext2D().clearRect(0,  0, pathCanvas.getWidth(), pathCanvas.getHeight());
            pathCanvas.getGraphicsContext2D().setStroke(Color.web("eeeeee"));
            pathCanvas.getGraphicsContext2D().setLineWidth(3);
            final RobotPath previewPath = new RobotPath(this);
            final ArrayList<Segment> leftSegments = previewPath.left.segments;
            final ArrayList<Segment> rightSegments = previewPath.right.segments;
            new Thread(() -> {
                int pointIndex = 1;
                long startTime = System.currentTimeMillis();
                while(true){
                    double t = (System.currentTimeMillis() - startTime) / 1000.0;
                    if(leftSegments.get(pointIndex).time <= t){
                        double lastLeftX = (leftSegments.get(pointIndex - 1).x * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getX() + PlannedPath.xPixelOffset;
                        double lastLeftY = (leftSegments.get(pointIndex - 1).y * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getY() + PlannedPath.yPixelOffset;
                        double lastRightX = (rightSegments.get(pointIndex - 1).x * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getX() + PlannedPath.xPixelOffset;
                        double lastRightY = (rightSegments.get(pointIndex - 1).y * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getY() + PlannedPath.yPixelOffset;
                        double currentLeftX = (leftSegments.get(pointIndex - 1).x * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getX() + PlannedPath.xPixelOffset;
                        double currentLeftY = (leftSegments.get(pointIndex - 1).y * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getY() + PlannedPath.yPixelOffset;
                        double currentRightX = (rightSegments.get(pointIndex - 1).x * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getX() + PlannedPath.xPixelOffset;
                        double currentRightY = (rightSegments.get(pointIndex - 1).y * PlannedPath.pixelsPerFoot) + previewPath.firstPointPixels.getY() + PlannedPath.yPixelOffset;
                        pathCanvas.getGraphicsContext2D().strokeLine(lastLeftX, lastLeftY, currentLeftX, currentLeftY);
                        pathCanvas.getGraphicsContext2D().strokeLine(lastRightX, lastRightY, currentRightX, currentRightY);
                        pointIndex++;
                    }
                    if(pointIndex >= leftSegments.size() - 1){
                        updatePathCanvas();
                        break;
                    }
                }
            }).start();
        });
        previewButton.getStyleClass().add("icon-button");
        previewButton.setGraphic(new ImageView(new Image(this.getClass().getResourceAsStream("res/preview.png"))));
        bottomRight.getChildren().addAll(settingsButton, generateButton, previewButton);

        bottom.getChildren().addAll(bottomLeft, bottomRight);
        center.getChildren().add(bottom);
        layout.setCenter(center);

        this.getChildren().add(layout);
    }

    private void setupCanvas(){
        center = new StackPane();
        pathCanvas = new Canvas(MainScene.WIDTH, MainScene.HEIGHT - 35);
        center.setOnMousePressed(event -> {
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
                        if((MainScene.isCtrlPressed || event.getButton() == MouseButton.MIDDLE) && i % 3 == 0){
                            PointConfigDialog dialog = new PointConfigDialog(this, i);
                            dialog.show();
                        }else if(event.getButton() != MouseButton.MIDDLE){
                            pointDragIndex = i;
                        }
                    }
                }
            }
        });
        center.setOnMouseReleased(event -> {
            pointDragIndex = -1;
        });
        center.setOnMouseMoved(event -> {
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
        center.setOnMouseDragged(event -> {
            if(pointDragIndex != -1){
                if(event.getX() >= 0 && event.getY() >= 0 && event.getX() <= pathCanvas.getWidth() && event.getY() <= pathCanvas.getHeight()) {
                    if(MainScene.isShiftPressed && pointDragIndex % 3 != 0){
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
        Canvas fieldCanvas = new Canvas(MainScene.WIDTH, MainScene.HEIGHT - 35);
        fieldCanvas.getGraphicsContext2D().drawImage(field, 0, 80);
        center.getChildren().addAll(fieldCanvas, pathCanvas);
    }

    private void drawPath(GraphicsContext g, int highlightedPoint){
        g.setLineWidth(3);
        g.setStroke(Color.web("eeeeee"));
        for(int i = 0; i < plannedPath.numSplines(); i ++){
            Vector2[] points = plannedPath.getPointsInSpline(i);
            for(double d = 0; d <= 1; d += 0.01){
                Vector2 p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
                Vector2 p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
                double angle = Math.atan2(p1.getY() - p0.getY(), p1.getX() - p0.getX());
                Vector2 p0L = new Vector2(p0.getX() + (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p0.getY() - (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p0R = new Vector2(p0.getX() - (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p0.getY() + (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p1L = new Vector2(p1.getX() + (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p1.getY() - (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));
                Vector2 p1R = new Vector2(p1.getX() - (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.sin(angle)), p1.getY() + (pathPreferences.wheelbaseWidth /2*PlannedPath.pixelsPerFoot*Math.cos(angle)));

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
                g.setFill(Color.web("ffeb3b"));
            }else if(i == 0){
                g.setFill(Color.web("388e3c"));
            }else if(i == plannedPath.numPoints() - 1){
                g.setFill(Color.web("d32f2f"));
            }else{
                g.setFill(Color.web("eeeeee"));
            }
            Vector2 p = plannedPath.get(i);
            g.strokeOval(p.getX() - 6, p.getY() - 6, 12, 12);
            g.fillOval(p.getX() - 6, p.getY() - 6, 12, 12);
        }
    }

    public void updatePathCanvas(){
        updatePathCanvas(-1);
    }

    public void updatePathCanvas(int highlightedPoint){
        pathCanvas.getGraphicsContext2D().clearRect(0, 0, pathCanvas.getWidth(), pathCanvas.getHeight());
        drawPath(pathCanvas.getGraphicsContext2D(), highlightedPoint);
    }
}
