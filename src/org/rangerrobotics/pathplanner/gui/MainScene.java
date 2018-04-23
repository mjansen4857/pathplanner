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

import java.util.function.Function;

public class MainScene {
    private static Scene scene = null;
    private static StackPane root;
    private static JFXTabPane layout;
    private static JFXSnackbar snackbar;
    private static JFXTreeTableView<Waypoint> waypointTable = new JFXTreeTableView<>();
    private static JFXTreeTableColumn<Waypoint, Double> xCol = new JFXTreeTableColumn<>("X Position");
    private static JFXTreeTableColumn<Waypoint, Double> yCol = new JFXTreeTableColumn<>("Y Position");
    private static JFXTreeTableColumn<Waypoint, Double> angleCol = new JFXTreeTableColumn<>("Angle");
    private static JFXTreeTableColumn<Waypoint, Double> speedCol = new JFXTreeTableColumn<>("Speed");
    private static ObservableList<Waypoint> waypoints;
    private static Canvas canvas;
    private static Vector2[] testPoints = new Vector2[]{new Vector2(20, 20), new Vector2(170, 20), new Vector2(50, 200), new Vector2(200, 200)};

    public static Scene getScene(){
        if(scene == null){
            createScene();
        }
        return scene;
    }

    private static void createScene(){
        root = new StackPane();
        layout = new JFXTabPane();
        Tab genTab = new Tab();
        genTab.setText("Path");
        Tab outTab = new Tab();
        outTab.setText("Output");

        BorderPane genTabLayout = new BorderPane();
        JFXButton test = new JFXButton("Beep");
        setupWaypointTable();
        waypointTable.setMaxSize(302, 500);
        VBox genLeft = new VBox(10);
        genLeft.getChildren().addAll(new Label("Henlo"), test, waypointTable);
        genTabLayout.setLeft(genLeft);

        canvas = new Canvas(400, 400);
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
        g.setFill(Color.RED);
//        g.setStroke(Color.BLACK);
        for(Vector2 p : testPoints){
            g.fillOval(p.x, p.y, 5, 5);
        }

        g.setStroke(Color.BLACK);
        g.setLineWidth(1);
        g.strokeLine(testPoints[0].x, testPoints[0].y, testPoints[1].x, testPoints[1].y);
        g.strokeLine(testPoints[2].x, testPoints[2].y, testPoints[3].x, testPoints[3].y);

        g.setStroke(Color.BLUE);
        g.setLineWidth(3);
        for(double d = 0.01; d <= 1; d += 0.01){
            Vector2 p0 = Util.cubicCurve(testPoints[0], testPoints[1], testPoints[2], testPoints[3], d);
            Vector2 p1 = Util.cubicCurve(testPoints[0], testPoints[1], testPoints[2], testPoints[3], d + 0.01);
            g.strokeLine(p0.x, p0.y, p1.x, p1.y);
        }
    }

    private static void setupWaypointTable(){
        xCol.setPrefWidth(75);
        yCol.setPrefWidth(75);
        angleCol.setPrefWidth(75);
        speedCol.setPrefWidth(75);
        setupCellValueFactory(xCol, w -> w.x.asObject());
        setupCellValueFactory(yCol, w -> w.y.asObject());
        setupCellValueFactory(angleCol, w -> w.angle.asObject());
        setupCellValueFactory(speedCol, w -> w.speed.asObject());

        //add editors
        xCol.setCellFactory((TreeTableColumn<Waypoint, Double> param) -> new GenericEditableTreeTableCell<>(new DoubleTextFieldEditorBuilder()));
        xCol.setOnEditCommit((TreeTableColumn.CellEditEvent<Waypoint, Double> t) -> {
            t.getTreeTableView().getTreeItem(t.getTreeTablePosition().getRow()).getValue().x.set(t.getNewValue());
            canvas.getGraphicsContext2D().clearRect(0, 0, canvas.getWidth(), canvas.getHeight());
            drawCurve(canvas.getGraphicsContext2D());
        });
        yCol.setCellFactory((TreeTableColumn<Waypoint, Double> param) -> new GenericEditableTreeTableCell<>(new DoubleTextFieldEditorBuilder()));
        yCol.setOnEditCommit((TreeTableColumn.CellEditEvent<Waypoint, Double> t) -> t.getTreeTableView().getTreeItem(t.getTreeTablePosition().getRow()).getValue().y.set(t.getNewValue()));
        angleCol.setCellFactory((TreeTableColumn<Waypoint, Double> param) -> new GenericEditableTreeTableCell<>(new DoubleTextFieldEditorBuilder()));
        angleCol.setOnEditCommit((TreeTableColumn.CellEditEvent<Waypoint, Double> t) -> t.getTreeTableView().getTreeItem(t.getTreeTablePosition().getRow()).getValue().angle.set(t.getNewValue()));
        speedCol.setCellFactory((TreeTableColumn<Waypoint, Double> param) -> new GenericEditableTreeTableCell<>(new DoubleTextFieldEditorBuilder()));
        speedCol.setOnEditCommit((TreeTableColumn.CellEditEvent<Waypoint, Double> t) -> t.getTreeTableView().getTreeItem(t.getTreeTablePosition().getRow()).getValue().speed.set(t.getNewValue()));

        waypoints = FXCollections.observableArrayList();
        waypoints.add(new Waypoint(0, 10, 0, 0));
        waypoints.add(new Waypoint(5, 5, 0, 5));
        waypoints.add(new Waypoint(10, 10, 0, 0));
        final TreeItem<Waypoint> root = new RecursiveTreeItem<>(waypoints, RecursiveTreeObject::getChildren);
        waypointTable.setRoot(root);
        waypointTable.setShowRoot(false);
        waypointTable.setEditable(true);
        waypointTable.getColumns().setAll(xCol, yCol, angleCol, speedCol);
//        waypointTableCount.textProperty().bind(Bindings.createStringBinding(() -> "( " + waypointTable.getCurrentItemsCount() + waypointTable.currentItemsCountProperty() + " )"));
    }

    private static <T> void setupCellValueFactory(JFXTreeTableColumn<Waypoint, T> column, Function<Waypoint, ObservableValue<T>> mapper){
        column.setCellValueFactory((TreeTableColumn.CellDataFeatures<Waypoint, T> param) -> {
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
