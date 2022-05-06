import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/window_button/window_button.dart';

class CustomAppBar extends AppBar {
  final String titleText;
  final double height;

  CustomAppBar({this.titleText = 'PathPlanner', this.height = 56, Key? key})
      : super(
          key: key,
          backgroundColor: Colors.grey[900],
          toolbarHeight: height,
          actions: [
            MinimizeWindowBtn(),
            MaximizeWindowBtn(),
            CloseWindowBtn(),
          ],
          title: SizedBox(
            height: height,
            child: Row(
              children: [
                Expanded(
                  child: MoveWindow(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        titleText,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}
