package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import com.jfoenix.controls.cells.editors.DoubleTextFieldEditorBuilder;
import com.jfoenix.controls.cells.editors.base.GenericEditableTreeTableCell;
import com.jfoenix.controls.datamodels.treetable.RecursiveTreeObject;
import javafx.beans.value.ObservableValue;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Label;
import javafx.scene.control.Tab;
import javafx.scene.control.TreeItem;
import javafx.scene.control.TreeTableColumn;
import javafx.scene.input.MouseButton;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import org.rangerrobotics.pathplanner.geometry.Path;
import org.rangerrobotics.pathplanner.geometry.Util;
import org.rangerrobotics.pathplanner.geometry.Vector2;

import java.util.function.Function;

public class MainScene {
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static JFXSnackbar snackbar;
    private static JFXTreeTableView<Vector2> waypointTable = new JFXTreeTableView<>();
    private static JFXTreeTableColumn<Vector2, Double> xCol = new JFXTreeTableColumn<>("X Position");
    private static JFXTreeTableColumn<Vector2, Double> yCol = new JFXTreeTableColumn<>("Y Position");
//    private static ObservableList<Vector2> points;
    private static Path path;
    private static Canvas canvas;
    private static int pointDragIndex = -1;

    public static Scene getScene(){
        if(scene == null){
            createScene();
        }
        return scene;
    }

    private static void createScene(){
        path = new Path();
//        points = FXCollections.observableArrayList();
//        points.add(new Vector2(20, 20, true));
//        points.add(new Vector2(170, 20, false));
//        points.add(new Vector2(50, 200, false));
//        points.add(new Vector2(200, 200, true));
//        points.add(new Vector2(250, 200));
//        points.add(new Vector2(150, 100));
//        points.add(new Vector2(200, 50));

        root = new StackPane();
        layout = new JFXTabPane();
        Tab genTab = new Tab();
        genTab.setText("Path");
        Tab outTab = new Tab();
        outTab.setText("Output");

        BorderPane genTabLayout = new BorderPane();
        JFXButton test = new JFXButton("Beep");
        setupWaypointTable();
        waypointTable.setMaxSize(202, 500);
        VBox genLeft = new VBox(10);
        genLeft.getChildren().addAll(new Label("Henlo"), test, waypointTable);
        genTabLayout.setLeft(genLeft);

        canvas = new Canvas(400, 400);
        canvas.setOnMousePressed(event -> {
            if(event.getButton() == MouseButton.SECONDARY){
                for (int i = 0; i < path.numPoints(); i++) {
                    if ((Math.pow(event.getX() - path.get(i).getX(), 2) + (Math.pow(event.getY() - path.get(i).getY(), 2))) <= Math.pow(8, 2)) {
                        if(i % 3 == 0 && path.numSegments() > 1) {
                            path.deleteSegment(i);
                            updateCanvas();
                        }
                        return;
                    }
                }
                path.addSegment(new Vector2(event.getX(), event.getY()));
                updateCanvas();
            }else if(event.getButton() == MouseButton.PRIMARY) {
                for (int i = 0; i < path.numPoints(); i++) {
                    if ((Math.pow(event.getX() - path.get(i).getX(), 2) + (Math.pow(event.getY() - path.get(i).getY(), 2))) <= Math.pow(8, 2)) {
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
                for (int i = 0; i < path.numPoints(); i++) {
                    if ((Math.pow(event.getX() - path.get(i).getX(), 2) + (Math.pow(event.getY() - path.get(i).getY(), 2))) <= Math.pow(8, 2)) {
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
                    path.movePoint(pointDragIndex, new Vector2(event.getX(), event.getY()));
                    updateCanvas(pointDragIndex);
                }
            }
        });
        drawCurve(canvas.getGraphicsContext2D(), -1);
        genTabLayout.setCenter(canvas);

        genTab.setContent(genTabLayout);

        layout.getTabs().addAll(genTab, outTab);
        root.getChildren().add(layout);
        snackbar = new JFXSnackbar(root);

        scene = new Scene(root, 800, 600);
        scene.getStylesheets().add("org/rangerrobotics/pathplanner/gui/styles.css");
    }

    private static void drawCurve(GraphicsContext g, int highlightedPoint){
        g.setFill(Color.color(0.35, 0.35, 0.35));
        g.fillRect(0, 0, canvas.getWidth(), canvas.getHeight());
        g.setLineWidth(3);
        g.setStroke(Color.color(0, 0.95, 0));
        for(int i = 0; i < path.numSegments(); i ++){
            Vector2[] points = path.getPointsInSegment(i);
            for(double d = 0.01; d <= 1; d += 0.01){
                Vector2 p0 = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
                Vector2 p1 = Util.cubicCurve(points[0], points[1], points[2], points[3], d + 0.01);
                g.strokeLine(p0.getX(), p0.getY(), p1.getX(), p1.getY());
            }
        }
        g.setStroke(Color.BLACK);
        for(int i = 0; i < path.numSegments(); i++){
            Vector2[] points = path.getPointsInSegment(i);

            g.setLineWidth(2);
            g.strokeLine(points[0].getX(), points[0].getY(), points[1].getX(), points[1].getY());
            g.strokeLine(points[2].getX(), points[2].getY(), points[3].getX(), points[3].getY());
        }

        for(int i = 0; i < path.numPoints(); i++){
            if(i == highlightedPoint){
                g.setFill(Color.YELLOW);
            }else{
                g.setFill(Color.RED);
            }
            Vector2 p = path.get(i);
            g.fillOval(p.getX() - 8, p.getY() - 8, 16, 16);
        }
    }

    private static void setupWaypointTable(){
        xCol.setPrefWidth(100);
        yCol.setPrefWidth(100);
        setupCellValueFactory(xCol, w -> w.x.asObject());
        setupCellValueFactory(yCol, w -> w.y.asObject());

        //add editors
        xCol.setCellFactory((TreeTableColumn<Vector2, Double> param) -> new GenericEditableTreeTableCell<>(new DoubleTextFieldEditorBuilder()));
        xCol.setOnEditCommit((TreeTableColumn.CellEditEvent<Vector2, Double> t) -> {
            t.getTreeTableView().getTreeItem(t.getTreeTablePosition().getRow()).getValue().x.set(t.getNewValue());
            updateCanvas();
        });
        yCol.setCellFactory((TreeTableColumn<Vector2, Double> param) -> new GenericEditableTreeTableCell<>(new DoubleTextFieldEditorBuilder()));
        yCol.setOnEditCommit((TreeTableColumn.CellEditEvent<Vector2, Double> t) -> {
            t.getTreeTableView().getTreeItem(t.getTreeTablePosition().getRow()).getValue().y.set(t.getNewValue());
            updateCanvas();
        });

        final TreeItem<Vector2> root = new RecursiveTreeItem<>(path.points, RecursiveTreeObject::getChildren);
        waypointTable.setRoot(root);
        waypointTable.setShowRoot(false);
        waypointTable.setEditable(true);
        waypointTable.getColumns().setAll(xCol, yCol);
    }

    private static void updateCanvas(){
        updateCanvas(-1);
    }

    private static void updateCanvas(int highlightedPoint){
        canvas.getGraphicsContext2D().clearRect(0, 0, canvas.getWidth(), canvas.getHeight());
        drawCurve(canvas.getGraphicsContext2D(), highlightedPoint);
    }

    private static <T> void setupCellValueFactory(JFXTreeTableColumn<Vector2, T> column, Function<Vector2, ObservableValue<T>> mapper){
        column.setCellValueFactory((TreeTableColumn.CellDataFeatures<Vector2, T> param) -> {
            if(column.validateValue(param)){
                return mapper.apply(param.getValue().getValue());
            }else{
                return column.getComputedValue(param);
            }
        });
    }

    public static void showSnackbarMessage(String message, String type){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type));
    }

    public static void showSnackbarWithButton(String message, String type){
        snackbar.enqueue(new JFXSnackbar.SnackbarEvent(message, type, "", 1000, true, event -> snackbar.close()));
    }
}
