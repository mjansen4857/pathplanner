package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;

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

        HBox name = new HBox(20);
        name.setAlignment(Pos.CENTER);
        Label nameLabel = new Label("Path Name:");
        nameLabel.getStyleClass().add("input-label");
        JFXTextField nameTxt = new JFXTextField();
        nameTxt.setPromptText("Enter Name");
        nameTxt.setAlignment(Pos.CENTER);
        name.getChildren().addAll(nameLabel, nameTxt);

        HBox value1 = new HBox(20);
        value1.setAlignment(Pos.CENTER);
        Label value1Label = new Label("Value 1:");
        value1Label.getStyleClass().add("input-label");
        JFXComboBox<Label> value1Combo = new JFXComboBox<>();
        value1Combo.getItems().addAll(new Label("Position"), new Label("Velocity"), new Label("Acceleration"), new Label("None"));
        value1Combo.setPromptText("Select Value");
        value1.getChildren().addAll(value1Label, value1Combo);

        HBox value2 = new HBox(20);
        value2.setAlignment(Pos.CENTER);
        Label value2Label = new Label("Value 2:");
        value2Label.getStyleClass().add("input-label");
        JFXComboBox<Label> value2Combo = new JFXComboBox<>();
        value2Combo.getItems().addAll(new Label("Position"), new Label("Velocity"), new Label("Acceleration"), new Label("None"));
        value2Combo.setPromptText("Select Value");
        value2.getChildren().addAll(value2Label, value2Combo);

        HBox value3 = new HBox(20);
        value3.setAlignment(Pos.CENTER);
        Label value3Label = new Label("Value 3:");
        value3Label.getStyleClass().add("input-label");
        JFXComboBox<Label> value3Combo = new JFXComboBox<>();
        value3Combo.getItems().addAll(new Label("Position"), new Label("Velocity"), new Label("Acceleration"), new Label("None"));
        value3Combo.setPromptText("Select Value");
        value3.getChildren().addAll(value3Label, value3Combo);

        HBox format = new HBox(20);
        format.setAlignment(Pos.CENTER);
        Label formatLabel = new Label("Output Format:");
        formatLabel.getStyleClass().add("input-label");
        JFXComboBox<Label> formatCombo = new JFXComboBox<>();
        formatCombo.getItems().addAll(new Label("Text File"), new Label("CSV File"), new Label("Java Array"), new Label("C++ Array"));
        formatCombo.setPromptText("Select Format");
        format.getChildren().addAll(formatLabel, formatCombo);

        HBox reversed = new HBox(20);
        reversed.setAlignment(Pos.CENTER);
        Label reversedLabel = new Label("Reversed:");
        reversedLabel.getStyleClass().add("input-label");
        JFXCheckBox reversedCheck = new JFXCheckBox();
        reversed.getChildren().addAll(reversedLabel, reversedCheck);

        dialogCenter.getChildren().addAll(dialogHeading, name, value1, value2, value3, format, reversed);

        HBox dialogBottom = new HBox();
        dialogBottom.setPadding(new Insets(0, 3, 2, 0));
        dialogBottom.setAlignment(Pos.BOTTOM_RIGHT);
        JFXButton dialogButton = new JFXButton("GENERATE");
        dialogButton.getStyleClass().addAll("button-flat");
        dialogButton.setPadding(new Insets(10));
        dialogButton.setOnAction(action -> {
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
