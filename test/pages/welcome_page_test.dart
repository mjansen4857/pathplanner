import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/pages/welcome_page.dart';
import 'package:pathplanner/widgets/field_image.dart';

void main() {
  testWidgets('welcome page', (widgetTester) async {
    await widgetTester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: WelcomePage(
          appVersion: '1.2.3',
        ),
      ),
    ));
    await widgetTester.pumpAndSettle();

    var versionText = find.text('v1.2.3');
    var logo = find.image(const AssetImage('images/icon.png'));
    var fieldImage = find.image(FieldImage.defaultField.image.image);
    var openButton = find.byType(ElevatedButton);

    expect(versionText, findsOneWidget);
    expect(logo, findsOneWidget);
    expect(fieldImage, findsOneWidget);
    expect(openButton, findsOneWidget);
  });
}
