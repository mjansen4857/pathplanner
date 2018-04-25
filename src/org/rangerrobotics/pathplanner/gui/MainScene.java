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
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import org.rangerrobotics.pathplanner.geometry.Util;
import org.rangerrobotics.pathplanner.geometry.Vector2;

import java.util.ArrayList;
import java.util.function.Function;

public class MainScene {
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static JFXSnackbar snackbar;
    private static JFXTreeTableView<Vector2> waypointTable = new JFXTreeTableView<>();
    private static JFXTreeTableColumn<Vector2, Double> xCol = new JFXTreeTableColumn<>("X Position");
    private static JFXTreeTableColumn<Vector2, Double> yCol = new JFXTreeTableColumn<>("Y Position");
    private static ObservableList<Vector2> points;
    private static Canvas canvas;
    private static int pointDragIndex = -1;

    public static Scene getScene(){
        if(scene == null){
            createScene();
        }
        return scene;
    }

    private static void createScene(){
        points = FXCollections.observableArrayList();
        points.add(new Vector2(20, 20));
        points.add(new Vector2(170, 20));
        points.add(new Vector2(50, 200));
        points.add(new Vector2(200, 200));

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
            System.out.println("Pressed X: " + event.getX() + ", Y: " + event.getY());
            for(int i = 0; i < points.size(); i++){
                System.out.println((Math.pow(event.getX() - points.get(i).getX() + 8, 2) + (Math.pow(event.getY() - points.get(i).getY() + 8, 2))));
                if((Math.pow(event.getX() - points.get(i).getX(), 2) + (Math.pow(event.getY() - points.get(i).getY(), 2))) <= Math.pow(8, 2)){
                    pointDragIndex = i;
                    System.out.println(pointDragIndex);
                }
            }
        });
        canvas.setOnMouseReleased(event -> {
            pointDragIndex = -1;
        });
        canvas.setOnMouseDragged(event -> {
            System.out.println("Dragged X: " + event.getX() + ", Y: " + event.getY());
            //TODO: Move points on canvas, update curve
            if(pointDragIndex != -1){
                if(event.getX() >= 0 && event.getY() >= 0 && event.getX() <= canvas.getWidth() && event.getY() <= canvas.getHeight()) {
                    points.get(pointDragIndex).setX(Math.round(event.getX()));
                    points.get(pointDragIndex).setY(Math.round(event.getY()));
                    updateCanvas();
                }
            }
        });
        drawCurve(canvas.getGraphicsContext2D());
        genTabLayout.setRight(canvas);

        genTab.setContent(genTabLayout);

        layout.getTabs().addAll(genTab, outTab);
        root.getChildren().add(layout);
        snackbar = new JFXSnackbar(root);

        scene = new Scene(root, 800, 600);
        scene.getStylesheets().add("org/rangerrobotics/pathplanner/gui/styles.css");
    }

    private static void drawCurve(GraphicsContext g){
        g.setStroke(Color.color(0, 0.95, 0));
        g.setLineWidth(3);
        for(double d = 0.01; d <= 1; d += 0.01){
            Vector2 p0 = Util.cubicCurve(points.get(0), points.get(1), points.get(2), points.get(3), d);
            Vector2 p1 = Util.cubicCurve(points.get(0), points.get(1), points.get(2), points.get(3), d + 0.01);
            g.strokeLine(p0.getX(), p0.getY(), p1.getX(), p1.getY());
        }

        g.setStroke(Color.color(0.1, 0.1, 0.1));
        g.setLineWidth(2);
        g.strokeLine(points.get(0).getX(), points.get(0).getY(), points.get(1).getX(), points.get(1).getY());
        g.strokeLine(points.get(2).getX(), points.get(2).getY(), points.get(3).getX(), points.get(3).getY());

        g.setFill(Color.RED);
        for(Vector2 p : points){
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

        final TreeItem<Vector2> root = new RecursiveTreeItem<>(points, RecursiveTreeObject::getChildren);
        waypointTable.setRoot(root);
        waypointTable.setShowRoot(false);
        waypointTable.setEditable(true);
        waypointTable.getColumns().setAll(xCol, yCol);
    }

    private static void updateCanvas(){
        canvas.getGraphicsContext2D().clearRect(0, 0, canvas.getWidth(), canvas.getHeight());
        drawCurve(canvas.getGraphicsContext2D());
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
