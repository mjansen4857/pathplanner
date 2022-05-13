import 'package:flutter/material.dart';

class CustomAppBar extends AppBar {
  final String titleText;
  final double height;

  CustomAppBar({this.titleText = 'PathPlanner', this.height = 56, Key? key})
      : super(
          key: key,
          toolbarHeight: height,
          actions: [],
          title: SizedBox(
            height: height,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      titleText,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}
