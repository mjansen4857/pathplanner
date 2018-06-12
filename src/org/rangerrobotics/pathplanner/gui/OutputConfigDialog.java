package org.rangerrobotics.pathplanner.gui;

import com.jfoenix.controls.*;
import com.jfoenix.validation.RequiredFieldValidator;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import org.rangerrobotics.pathplanner.Preferences;
import org.rangerrobotics.pathplanner.generation.RobotPath;
import org.rangerrobotics.pathplanner.io.FileManager;

import java.awt.*;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.StringSelection;

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
        nameTxt.setValidators(new RequiredFieldValidator());
        nameTxt.setPromptText("Enter Name");
        nameTxt.setAlignment(Pos.CENTER);
        nameBox.getChildren().addAll(nameLabel, nameTxt);

        HBox value1Box = new HBox(20);
        value1Box.setAlignment(Pos.CENTER);
        Label value1Label = new Label("Value 1:");
        value1Label.getStyleClass().add("input-label");
        JFXComboBox<String> value1Combo = new JFXComboBox<>();
        value1Combo.setValue(Preferences.outputValue1);
        value1Combo.getItems().addAll("Position", "Velocity", "Acceleration", "Time");
        value1Box.getChildren().addAll(value1Label, value1Combo);

        HBox value2Box = new HBox(20);
        value2Box.setAlignment(Pos.CENTER);
        Label value2Label = new Label("Value 2:");
        value2Label.getStyleClass().add("input-label");
        JFXComboBox<String> value2Combo = new JFXComboBox<>();
        value2Combo.setValue(Preferences.outputValue2);
        value2Combo.getItems().addAll("Position", "Velocity", "Acceleration", "Time", "None");
        value2Box.getChildren().addAll(value2Label, value2Combo);

        HBox value3Box = new HBox(20);
        value3Box.setAlignment(Pos.CENTER);
        Label value3Label = new Label("Value 3:");
        value3Label.getStyleClass().add("input-label");
        JFXComboBox<String> value3Combo = new JFXComboBox<>();
        value3Combo.setValue(Preferences.outputValue3);
        value3Combo.getItems().addAll("Position", "Velocity", "Acceleration", "Time", "None");
        value3Box.getChildren().addAll(value3Label, value3Combo);

        HBox formatBox = new HBox(20);
        formatBox.setAlignment(Pos.CENTER);
        Label formatLabel = new Label("Output Format:");
        formatLabel.getStyleClass().add("input-label");
        JFXComboBox<String> formatCombo = new JFXComboBox<>();
        formatCombo.setValue(Preferences.outputFormat);
        formatCombo.getItems().addAll("CSV File", "Java Array", "C++ Array");
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
            RobotPath.generatedPath = null;
            Preferences.outputValue1 = value1Combo.getValue();
            Preferences.outputValue2 = value2Combo.getValue();
            Preferences.outputValue3 = value3Combo.getValue();
            Preferences.outputFormat = formatCombo.getValue();
            FileManager.saveRobotSettings();
            if(nameTxt.validate()){
                this.close();
                new Thread(() -> {
                    long start = System.currentTimeMillis();
                    RobotPath.generatedPath = new RobotPath(MainScene.plannedPath);
                    System.out.println("Generation Finished! Total Time: " + ((double)(System.currentTimeMillis() - start)) / 1000 + " segments");
                }).start();
                if(formatCombo.getValue().equals("CSV File")){
                    FileManager.savePathFiles(nameTxt.getText(), reversedCheck.isSelected());
                }else if(formatCombo.getValue().equals("Java Array")){
                    while(RobotPath.generatedPath == null){
                        try {
                            Thread.sleep(10);
                        }catch (InterruptedException e){
                            e.printStackTrace();
                        }
                    }
                    String leftArray;
                    String rightArray;
                    if(reversedCheck.isSelected()){
                        leftArray = RobotPath.generatedPath.right.formatJavaArray(nameTxt.getText() + "Left", true);
                        rightArray = RobotPath.generatedPath.left.formatJavaArray(nameTxt.getText() + "Right", true);
                    }else{
                        leftArray = RobotPath.generatedPath.left.formatJavaArray(nameTxt.getText() + "Left", false);
                        rightArray = RobotPath.generatedPath.right.formatJavaArray(nameTxt.getText() + "Right", false);
                    }

                    StringSelection selection = new StringSelection(leftArray + "\n\n    " + rightArray);
                    Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
                    clipboard.setContents(selection, selection);
                    MainScene.showSnackbarMessage("Arrays copied to clipboard!", "success");
                }
            }else{
                MainScene.showSnackbarMessage("A path name is required!", "error");
            }
        });
        dialogBottom.getChildren().add(dialogButton);

        dialogPane.setBottom(dialogBottom);
        dialogPane.setCenter(dialogCenter);
        this.setDialogContainer(root);
        this.setContent(dialogPane);
        this.setTransitionType(JFXDialog.DialogTransition.CENTER);
    }
}
