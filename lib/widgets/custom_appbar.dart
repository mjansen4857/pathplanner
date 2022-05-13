import 'package:flutter/material.dart';

class CustomAppBar extends AppBar {
  final String titleText;

  CustomAppBar(
      {this.titleText = 'PathPlanner', super.toolbarHeight = 56, super.key})
      : super(
          actions: [],
          title: SizedBox(
            height: toolbarHeight,
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
