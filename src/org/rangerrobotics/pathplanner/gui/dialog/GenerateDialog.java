package org.rangerrobotics.pathplanner.gui.dialog;

import com.jfoenix.controls.*;
import com.jfoenix.validation.RequiredFieldValidator;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import org.rangerrobotics.pathplanner.generation.RobotPath;
import org.rangerrobotics.pathplanner.gui.MainScene;
import org.rangerrobotics.pathplanner.gui.PathEditor;
import org.rangerrobotics.pathplanner.io.FileManager;

import java.awt.*;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.StringSelection;

public class GenerateDialog extends JFXDialog {

    public GenerateDialog(PathEditor editor){
        BorderPane dialogPane = new BorderPane();
        dialogPane.setPrefWidth(400);

        VBox dialogCenter = new VBox(20);
        dialogCenter.setAlignment(Pos.TOP_LEFT);
        dialogCenter.setPadding(new Insets(5, 8, 5, 8));
        Label dialogHeading = new Label("Output Settings");
        dialogHeading.getStyleClass().addAll("dialog-heading");

        HBox nameBox = new HBox(20);
        nameBox.setAlignment(Pos.CENTER);
        Label nameLabel = new Label("Path Name:");
        nameLabel.getStyleClass().add("input-label");
        JFXTextField nameTxt = new JFXTextField();
        nameTxt.setText(editor.pathPreferences.currentPathName);
        nameTxt.setValidators(new RequiredFieldValidator());
        nameTxt.setPromptText("Enter Name");
        nameTxt.setAlignment(Pos.CENTER);
        nameBox.getChildren().addAll(nameLabel, nameTxt);

        HBox value1Box = new HBox(20);
        value1Box.setAlignment(Pos.CENTER);
        Label value1Label = new Label("Value 1:");
        value1Label.getStyleClass().add("input-label");
        JFXComboBox<String> value1Combo = new JFXComboBox<>();
        value1Combo.setValue(editor.pathPreferences.outputValue1);
        value1Combo.getItems().addAll("Position", "Velocity", "Acceleration", "Time");
        value1Box.getChildren().addAll(value1Label, value1Combo);

        HBox value2Box = new HBox(20);
        value2Box.setAlignment(Pos.CENTER);
        Label value2Label = new Label("Value 2:");
        value2Label.getStyleClass().add("input-label");
        JFXComboBox<String> value2Combo = new JFXComboBox<>();
        value2Combo.setValue(editor.pathPreferences.outputValue2);
        value2Combo.getItems().addAll("Position", "Velocity", "Acceleration", "Time", "None");
        value2Box.getChildren().addAll(value2Label, value2Combo);

        HBox value3Box = new HBox(20);
        value3Box.setAlignment(Pos.CENTER);
        Label value3Label = new Label("Value 3:");
        value3Label.getStyleClass().add("input-label");
        JFXComboBox<String> value3Combo = new JFXComboBox<>();
        value3Combo.setValue(editor.pathPreferences.outputValue3);
        value3Combo.getItems().addAll("Position", "Velocity", "Acceleration", "Time", "None");
        value3Box.getChildren().addAll(value3Label, value3Combo);

        HBox formatBox = new HBox(20);
        formatBox.setAlignment(Pos.CENTER);
        Label formatLabel = new Label("Output Format:");
        formatLabel.getStyleClass().add("input-label");
        JFXComboBox<String> formatCombo = new JFXComboBox<>();
        formatCombo.setValue(editor.pathPreferences.outputFormat);
        formatCombo.getItems().addAll("CSV File", "Java Array", "C++ Array", "Python Array");
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
        dialogButton.setDefaultButton(true);
        dialogButton.setOnAction(action -> {
            RobotPath.generatedPath = null;
            editor.pathPreferences.outputValue1 = value1Combo.getValue();
            editor.pathPreferences.outputValue2 = value2Combo.getValue();
            editor.pathPreferences.outputValue3 = value3Combo.getValue();
            editor.pathPreferences.outputFormat = formatCombo.getValue();
            editor.pathPreferences.currentPathName = nameTxt.getText();
            FileManager.saveRobotSettings(editor);
            if(nameTxt.validate()){
                this.close();
                new Thread(() -> {
                    long start = System.currentTimeMillis();
                    RobotPath.generatedPath = new RobotPath(editor);
                    System.out.println("Generation Finished! Total Time: " + ((double)(System.currentTimeMillis() - start)) / 1000 + " seconds");
                }).start();
                if(formatCombo.getValue().equals("CSV File")){
                    FileManager.saveGeneratedPath(nameTxt.getText(), reversedCheck.isSelected(), editor);
                }else if(formatCombo.getValue().equals("Java Array") || formatCombo.getValue().equals("C++ Array") || formatCombo.getValue().equals("Python Array")){
                    while(RobotPath.generatedPath == null){
                        try {
                            Thread.sleep(10);
                        }catch (InterruptedException e){
                            e.printStackTrace();
                        }
                    }
                    String leftArray;
                    String rightArray;
                    if(formatCombo.getValue().equals("Java Array")) {
                        if (reversedCheck.isSelected()) {
                            leftArray = RobotPath.generatedPath.right.formatJavaArray(nameTxt.getText() + "Left", true, editor);
                            rightArray = RobotPath.generatedPath.left.formatJavaArray(nameTxt.getText() + "Right", true, editor);
                        } else {
                            leftArray = RobotPath.generatedPath.left.formatJavaArray(nameTxt.getText() + "Left", false, editor);
                            rightArray = RobotPath.generatedPath.right.formatJavaArray(nameTxt.getText() + "Right", false, editor);
                        }
                    }else if(formatCombo.getValue().equals("C++ Array")){
                        if (reversedCheck.isSelected()) {
                            leftArray = RobotPath.generatedPath.right.formatCppArray(nameTxt.getText() + "Left", true, editor);
                            rightArray = RobotPath.generatedPath.left.formatCppArray(nameTxt.getText() + "Right", true, editor);
                        } else {
                            leftArray = RobotPath.generatedPath.left.formatCppArray(nameTxt.getText() + "Left", false, editor);
                            rightArray = RobotPath.generatedPath.right.formatCppArray(nameTxt.getText() + "Right", false, editor);
                        }
                    }else{
                        if(reversedCheck.isSelected()){
                            leftArray = RobotPath.generatedPath.right.formatPythonArray(nameTxt.getText() + "_left", true, editor);
                            rightArray = RobotPath.generatedPath.left.formatPythonArray(nameTxt.getText() + "_right", true, editor);
                        }else{
                            leftArray = RobotPath.generatedPath.left.formatPythonArray(nameTxt.getText() + "_left", false, editor);
                            rightArray = RobotPath.generatedPath.right.formatPythonArray(nameTxt.getText() + "_right", false, editor);
                        }
                    }
                    StringSelection selection = new StringSelection(leftArray + "\n\n    " + rightArray);
                    if(formatCombo.getValue().equals("Python Array")){
                        selection = new StringSelection(leftArray + "\n\n" + rightArray);
                    }
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
        this.setDialogContainer(editor);
        this.setContent(dialogPane);
        this.setTransitionType(JFXDialog.DialogTransition.CENTER);
    }
}
