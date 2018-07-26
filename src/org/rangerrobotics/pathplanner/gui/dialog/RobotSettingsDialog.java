package org.rangerrobotics.pathplanner.gui.dialog;

import com.jfoenix.controls.JFXButton;
import com.jfoenix.controls.JFXDialog;
import com.jfoenix.controls.JFXTextField;
import com.jfoenix.validation.DoubleValidator;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import org.rangerrobotics.pathplanner.gui.MainScene;
import org.rangerrobotics.pathplanner.gui.PathEditor;
import org.rangerrobotics.pathplanner.io.FileManager;

public class RobotSettingsDialog extends JFXDialog {
    public RobotSettingsDialog(PathEditor editor){
        super();
        BorderPane dialogPane = new BorderPane();
        dialogPane.setPrefWidth(440);

        VBox dialogCenter = new VBox(20);
        dialogCenter.setAlignment(Pos.TOP_LEFT);
        dialogCenter.setPadding(new Insets(5, 8, 5, 8));
        Label dialogHeading = new Label("Robot Settings");
        dialogHeading.getStyleClass().addAll("dialog-heading");

        HBox maxV = new HBox(20);
        maxV.setAlignment(Pos.CENTER);
        Label maxVLabel = new Label("Max Velocity:");
        maxVLabel.getStyleClass().add("input-label");
        JFXTextField maxVTxt = new JFXTextField();
        maxVTxt.setText("" + editor.pathPreferences.maxVel);
        maxVTxt.setValidators(new DoubleValidator());
        maxVTxt.setAlignment(Pos.CENTER);
        maxV.getChildren().addAll(maxVLabel, maxVTxt);

        HBox maxAcc = new HBox(20);
        maxAcc.setAlignment(Pos.CENTER);
        Label maxAccLabel = new Label("Max Acceleration:");
        maxAccLabel.getStyleClass().add("input-label");
        JFXTextField maxAccTxt = new JFXTextField();
        maxAccTxt.setText("" + editor.pathPreferences.maxAcc);
        maxAccTxt.setValidators(new DoubleValidator());
        maxAccTxt.setAlignment(Pos.CENTER);
        maxAcc.getChildren().addAll(maxAccLabel, maxAccTxt);

        HBox maxDcc = new HBox(20);
        maxDcc.setAlignment(Pos.CENTER);
        Label maxDccLabel = new Label("Max Deceleration:");
        maxDccLabel.getStyleClass().add("input-label");
        JFXTextField maxDccTxt = new JFXTextField();
        maxDccTxt.setText("" + editor.pathPreferences.maxDcc);
        maxDccTxt.setValidators(new DoubleValidator());
        maxDccTxt.setAlignment(Pos.CENTER);
        maxDcc.getChildren().addAll(maxDccLabel, maxDccTxt);

        HBox wheelbaseWidth = new HBox(20);
        wheelbaseWidth.setAlignment(Pos.CENTER);
        Label wheelbaseWidthLabel = new Label("Wheelbase Width:");
        wheelbaseWidthLabel.getStyleClass().add("input-label");
        JFXTextField wheelbaseWidthTxt = new JFXTextField();
        wheelbaseWidthTxt.setText("" + editor.pathPreferences.wheelbaseWidth);
        wheelbaseWidthTxt.setValidators(new DoubleValidator());
        wheelbaseWidthTxt.setAlignment(Pos.CENTER);
        wheelbaseWidth.getChildren().addAll(wheelbaseWidthLabel, wheelbaseWidthTxt);

        HBox timestep = new HBox(20);
        timestep.setAlignment(Pos.CENTER);
        Label timestepLabel = new Label("Time Step:");
        timestepLabel.getStyleClass().add("input-label");
        JFXTextField timestepTxt = new JFXTextField();
        timestepTxt.setText("" + editor.pathPreferences.timeStep);
        timestepTxt.setValidators(new DoubleValidator());
        timestepTxt.setAlignment(Pos.CENTER);
        timestep.getChildren().addAll(timestepLabel, timestepTxt);

        dialogCenter.getChildren().addAll(dialogHeading, maxV, maxAcc, maxDcc, wheelbaseWidth, timestep);

        HBox dialogBottom = new HBox();
        dialogBottom.setPadding(new Insets(0, 3, 2, 0));
        dialogBottom.setAlignment(Pos.BOTTOM_RIGHT);
        JFXButton dialogButton = new JFXButton("ACCEPT");
        dialogButton.getStyleClass().addAll("button-flat");
        dialogButton.setPadding(new Insets(10));
        dialogButton.setOnAction(action -> {
            if(maxVTxt.validate() && maxAccTxt.validate() && maxDccTxt.validate() && wheelbaseWidthTxt.validate() && timestepTxt.validate()){
                editor.pathPreferences.maxVel = Double.parseDouble(maxVTxt.getText());
                editor.pathPreferences.maxAcc = Double.parseDouble(maxAccTxt.getText());
                editor.pathPreferences.maxDcc = Double.parseDouble(maxDccTxt.getText());
                editor.pathPreferences.wheelbaseWidth = Double.parseDouble(wheelbaseWidthTxt.getText());
                editor.pathPreferences.timeStep = Double.parseDouble(timestepTxt.getText());
                FileManager.saveRobotSettings(editor);
                editor.updatePathCanvas();
                this.close();
            }else{
                MainScene.showSnackbarMessage("Invalid Inputs!", "error");
            }
        });
        dialogBottom.getChildren().addAll(dialogButton);

        dialogPane.setBottom(dialogBottom);
        dialogPane.setCenter(dialogCenter);
        this.setDialogContainer(editor);
        this.setContent(dialogPane);
        this.setTransitionType(JFXDialog.DialogTransition.CENTER);
    }
}
