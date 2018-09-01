package org.rangerrobotics.pathplanner.gui.dialog;

import com.jfoenix.controls.JFXButton;
import com.jfoenix.controls.JFXDialog;
import com.jfoenix.controls.JFXTextField;
import com.jfoenix.validation.DoubleValidator;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.input.KeyCode;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import org.rangerrobotics.pathplanner.generation.PlannedPath;
import org.rangerrobotics.pathplanner.generation.Vector2;
import org.rangerrobotics.pathplanner.gui.MainScene;
import org.rangerrobotics.pathplanner.gui.PathEditor;

public class PointConfigDialog extends JFXDialog {
    public PointConfigDialog(PathEditor editor, int configIndex){
        super();
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
        xPositionLabel.getStyleClass().addAll("input-label");
        JFXTextField xPositionTxtField = new JFXTextField();
        xPositionTxtField.setValidators(new DoubleValidator());
        xPositionTxtField.setAlignment(Pos.CENTER);
        xPositionTxtField.setText("" + (editor.plannedPath.get(configIndex).getX() - PlannedPath.xPixelOffset) / PlannedPath.pixelsPerFoot);
        xPositionContainer.getChildren().addAll(xPositionLabel, xPositionTxtField);

        HBox yPositionContainer = new HBox(20);
        yPositionContainer.setAlignment(Pos.CENTER);
        Label yPositionLabel = new Label("Y Position:");
        yPositionLabel.getStyleClass().addAll("input-label");
        JFXTextField yPositionTxtField = new JFXTextField();
        yPositionTxtField.setValidators(new DoubleValidator());
        yPositionTxtField.setAlignment(Pos.CENTER);
        yPositionTxtField.setText("" + (editor.plannedPath.get(configIndex).getY() - PlannedPath.yPixelOffset) / PlannedPath.pixelsPerFoot);
        yPositionContainer.getChildren().addAll(yPositionLabel, yPositionTxtField);

        HBox angleContainer = new HBox(20);
        angleContainer.setAlignment(Pos.CENTER);
        Label angleLabel = new Label("Angle:");
        angleLabel.getStyleClass().addAll("input-label");
        JFXTextField angleTxtField = new JFXTextField();
        angleTxtField.setValidators(new DoubleValidator());
        angleTxtField.setAlignment(Pos.CENTER);
        Vector2 anchor = editor.plannedPath.get(configIndex);
        Vector2 control;
        if(configIndex == editor.plannedPath.numPoints() - 1){
            control = Vector2.subtract(anchor, Vector2.subtract(editor.plannedPath.get(configIndex - 1), anchor));
        }else{
            control = editor.plannedPath.get(configIndex + 1);
        }
        double angle = Math.toDegrees(Math.atan2(control.getY() - anchor.getY(), control.getX() - anchor.getX()));
        angleTxtField.setText("" + angle);
        angleContainer.getChildren().addAll(angleLabel, angleTxtField);

        dialogCenter.getChildren().addAll(dialogHeading, xPositionContainer, yPositionContainer, angleContainer);

        HBox dialogBottom = new HBox();
        dialogBottom.setPadding(new Insets(0, 3, 2, 0));
        dialogBottom.setAlignment(Pos.BOTTOM_RIGHT);
        JFXButton dialogButton = new JFXButton("ACCEPT");
        dialogButton.setDefaultButton(true);
        dialogButton.getStyleClass().addAll("button-flat");
        dialogButton.setPadding(new Insets(10));
        final int anchorIndex = configIndex;
        dialogButton.setOnAction(action -> {
            if(xPositionTxtField.validate() && yPositionTxtField.validate() && angleTxtField.validate() && (Double.parseDouble(angleTxtField.getText()) >= -180 && Double.parseDouble(angleTxtField.getText()) <= 180)){
                editor.plannedPath.movePoint(anchorIndex, new Vector2((Double.parseDouble(xPositionTxtField.getText()) * PlannedPath.pixelsPerFoot) + PlannedPath.xPixelOffset, (Double.parseDouble(yPositionTxtField.getText()) * PlannedPath.pixelsPerFoot) + PlannedPath.yPixelOffset));
                double theta = Math.toRadians(Double.parseDouble(angleTxtField.getText()));
                double h = Vector2.subtract(anchor, control).getMagnitude();
                double o = Math.sin(theta) * h;
                double a = Math.cos(theta) * h;
                int controlIndex;
                if(anchorIndex == editor.plannedPath.numPoints() - 1){
                    controlIndex = anchorIndex - 1;
                    editor.plannedPath.movePoint(controlIndex, Vector2.subtract(editor.plannedPath.get(anchorIndex), new Vector2(a, o)));
                }else{
                    controlIndex = anchorIndex + 1;
                    editor.plannedPath.movePoint(controlIndex, Vector2.add(editor.plannedPath.get(anchorIndex), new Vector2(a, o)));
                }
                editor.updatePathCanvas();
            }else{
                MainScene.showSnackbarMessage("Invalid Inputs!", "error");
            }
            this.close();
        });
        dialogBottom.getChildren().addAll(dialogButton);

        dialogPane.setBottom(dialogBottom);
        dialogPane.setCenter(dialogCenter);
        this.setDialogContainer(editor);
        this.setContent(dialogPane);
        this.setTransitionType(JFXDialog.DialogTransition.CENTER);
    }
}
