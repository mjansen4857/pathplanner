package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import org.rangerrobotics.pathplanner.Preferences;
import org.rangerrobotics.pathplanner.io.FileManager;

public class OutputConfigDialog extends JFXDialog {
    public OutputConfigDialog(StackPane root){
        BorderPane dialogPane = new BorderPane();
        dialogPane.setPrefWidth(400);

        VBox dialogCenter = new VBox(20);
        dialogCenter.setAlignment(Pos.TOP_LEFT);
        dialogCenter.setPadding(new Insets(5, 8, 5, 8));
        Label dialogHeading = new Label("Output Configuration");
        dialogHeading.getStyleClass().addAll("dialog-heading");
        dialogHeading.setPadding(new Insets(0, 0, 10, 0));

        HBox nameBox = new HBox(20);
        nameBox.setAlignment(Pos.CENTER);
        Label nameLabel = new Label("Path Name:");
        nameLabel.getStyleClass().add("input-label");
        JFXTextField nameTxt = new JFXTextField();
        nameTxt.setPromptText("Enter Name");
        nameTxt.setAlignment(Pos.CENTER);
        nameBox.getChildren().addAll(nameLabel, nameTxt);

        HBox value1Box = new HBox(20);
        value1Box.setAlignment(Pos.CENTER);
        Label value1Label = new Label("Value 1:");
        value1Label.getStyleClass().add("input-label");
        JFXComboBox<String> value1Combo = new JFXComboBox<>();
        value1Combo.setValue(Preferences.outputValue1);
        value1Combo.getItems().addAll("Position", "Velocity", "Acceleration");
        value1Box.getChildren().addAll(value1Label, value1Combo);

        HBox value2Box = new HBox(20);
        value2Box.setAlignment(Pos.CENTER);
        Label value2Label = new Label("Value 2:");
        value2Label.getStyleClass().add("input-label");
        JFXComboBox<String> value2Combo = new JFXComboBox<>();
        value2Combo.setValue(Preferences.outputValue2);
        value2Combo.getItems().addAll("Position", "Velocity", "Acceleration", "None");
        value2Box.getChildren().addAll(value2Label, value2Combo);

        HBox value3Box = new HBox(20);
        value3Box.setAlignment(Pos.CENTER);
        Label value3Label = new Label("Value 3:");
        value3Label.getStyleClass().add("input-label");
        JFXComboBox<String> value3Combo = new JFXComboBox<>();
        value3Combo.setValue(Preferences.outputValue3);
        value3Combo.getItems().addAll("Position", "Velocity", "Acceleration", "None");
        value3Box.getChildren().addAll(value3Label, value3Combo);

        HBox formatBox = new HBox(20);
        formatBox.setAlignment(Pos.CENTER);
        Label formatLabel = new Label("Output Format:");
        formatLabel.getStyleClass().add("input-label");
        JFXComboBox<String> formatCombo = new JFXComboBox<>();
        formatCombo.setValue(Preferences.outputFormat);
        formatCombo.getItems().addAll("Text File", "CSV File", "Java Array", "C++ Array");
        formatCombo.setPromptText("Select Format");
        formatBox.getChildren().addAll(formatLabel, formatCombo);

        HBox reversedBox = new HBox(20);
        reversedBox.setAlignment(Pos.CENTER);
        Label reversedLabel = new Label("Reversed:");
        reversedLabel.getStyleClass().add("input-label");
        JFXCheckBox reversedCheck = new JFXCheckBox();
        reversedBox.getChildren().addAll(reversedLabel, reversedCheck);

        dialogCenter.getChildren().addAll(dialogHeading, nameBox, value1Box, value2Box, value3Box, formatBox, reversedBox);

        HBox dialogBottom = new HBox();
        dialogBottom.setPadding(new Insets(0, 3, 2, 0));
        dialogBottom.setAlignment(Pos.BOTTOM_RIGHT);
        JFXButton dialogButton = new JFXButton("GENERATE");
        dialogButton.getStyleClass().addAll("button-flat");
        dialogButton.setPadding(new Insets(10));
        dialogButton.setOnAction(action -> {
            Preferences.outputValue1 = value1Combo.getValue();
            Preferences.outputValue2 = value2Combo.getValue();
            Preferences.outputValue3 = value2Combo.getValue();
            Preferences.outputFormat = formatCombo.getValue();
            FileManager.saveRobotSettings();
            this.close();
        });
        dialogBottom.getChildren().add(dialogButton);

        dialogPane.setBottom(dialogBottom);
        dialogPane.setCenter(dialogCenter);
        this.setDialogContainer(root);
        this.setContent(dialogPane);
        this.setTransitionType(JFXDialog.DialogTransition.CENTER);
    }
}
