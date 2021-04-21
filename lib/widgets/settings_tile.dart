import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore: must_be_immutable
class SettingsTile extends StatefulWidget {
  final VoidCallback onSettingsChanged;

  SettingsTile({this.onSettingsChanged});

  @override
  _SettingsTileState createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _easeInTween =
      CurveTween(curve: Curves.easeIn);
  static final Animatable<double> _halfTween =
      Tween<double>(begin: 0.0, end: 0.5);

  SharedPreferences _prefs;
  TextEditingController _robotWidthController;
  TextEditingController _robotLengthController;
  bool _holonomic = false;

  AnimationController _controller;
  Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _iconTurns = _controller.drive(_halfTween.chain(_easeInTween));

    SharedPreferences.getInstance().then((value) {
      setState(() {
        _prefs = value;
        double width = 0.75;
        double length = 1.0;
        if (_prefs != null) {
          width = _prefs.getDouble('robotWidth') ?? 0.75;
          length = _prefs.getDouble('robotLength') ?? 1.0;
          _holonomic = _prefs.getBool('holonomicMode') ?? false;
        }
        _robotWidthController =
            TextEditingController(text: width.toStringAsFixed(2));
        _robotWidthController.selection = TextSelection.fromPosition(
            TextPosition(offset: _robotWidthController.text.length));
        _robotLengthController =
            TextEditingController(text: length.toStringAsFixed(2));
        _robotLengthController.selection = TextSelection.fromPosition(
            TextPosition(offset: _robotLengthController.text.length));
      });
    });
  }

  Widget buildTextField(BuildContext context, String label,
      ValueChanged onSubmitted, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 24, 6),
      child: Container(
        height: 45,
        child: TextField(
          onSubmitted: (val) {
            if (onSubmitted != null) {
              var parsed = double.tryParse(val);
              onSubmitted.call(parsed);
            }
            unfocus(context);
          },
          controller: controller,
          cursorColor: Colors.white,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)')),
          ],
          style: TextStyle(fontSize: 14),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            labelText: label,
            filled: true,
            border:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            labelStyle: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(Icons.settings),
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
        });
      },
      trailing: RotationTransition(
        turns: _iconTurns,
        child: Icon(Icons.expand_less),
      ),
      title: Text('Settings'),
      children: [
        buildTextField(context, 'Robot Width', (value) {
          if (value != null && _prefs != null) {
            _prefs.setDouble('robotWidth', value);
          }
          if (widget.onSettingsChanged != null) {
            widget.onSettingsChanged.call();
          }
        }, _robotWidthController),
        buildTextField(context, 'Robot Length', (value) {
          if (value != null && _prefs != null) {
            _prefs.setDouble('robotLength', value);
          }
          if (widget.onSettingsChanged != null) {
            widget.onSettingsChanged.call();
          }
        }, _robotLengthController),
        SwitchListTile(
          value: _holonomic,
          activeColor: Colors.indigoAccent,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          onChanged: (val) {
            _prefs.setBool('holonomicMode', val);
            setState(() {
              _holonomic = val;
            });
            if (widget.onSettingsChanged != null) {
              widget.onSettingsChanged.call();
            }
          },
          title: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('Holonomic Mode'),
          ),
        ),
      ],
    );
  }

  void unfocus(BuildContext context) {
    FocusScopeNode currentScope = FocusScope.of(context);
    if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
      FocusManager.instance.primaryFocus.unfocus();
    }
  }
}
