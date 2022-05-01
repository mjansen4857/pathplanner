import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsTile extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  final VoidCallback? onGenerationEnabled;

  SettingsTile({this.onSettingsChanged, this.onGenerationEnabled});

  @override
  _SettingsTileState createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _easeInTween =
      CurveTween(curve: Curves.easeIn);
  static final Animatable<double> _halfTween =
      Tween<double>(begin: 0.0, end: 0.5);

  SharedPreferences? _prefs;
  double _width = 0.75;
  double _length = 1.0;
  bool _holonomic = false;
  bool _generateJSON = false;
  bool _generateCSV = false;
  List<FieldImage> _fieldImages = [
    FieldImage.official(OfficialField.RapidReact),
    FieldImage.official(OfficialField.Test),
  ];
  FieldImage? _selectedField;

  late AnimationController _controller;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _iconTurns = _controller.drive(_halfTween.chain(_easeInTween));

    SharedPreferences.getInstance().then((value) {
      setState(() {
        _prefs = value;
        if (_prefs != null) {
          _width = _prefs!.getDouble('robotWidth') ?? 0.75;
          _length = _prefs!.getDouble('robotLength') ?? 1.0;
          _holonomic = _prefs!.getBool('holonomicMode') ?? false;
          _generateJSON = _prefs!.getBool('generateJSON') ?? false;
          _generateCSV = _prefs!.getBool('generateCSV') ?? false;
        }
      });
    });

    _selectedField = _fieldImages[0];
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(
        Icons.settings,
        color: Colors.white,
      ),
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
        child: Icon(
          Icons.expand_less,
          color: Colors.white,
        ),
      ),
      title: Text(
        'Settings',
        style: TextStyle(color: Colors.white),
      ),
      children: [
        buildTextField(context, 'Robot Width', (value) {
          if (value != null && _prefs != null) {
            _prefs!.setDouble('robotWidth', value);
            setState(() {
              _width = value;
            });
          }
          if (widget.onSettingsChanged != null) {
            widget.onSettingsChanged!.call();
          }
        }, _width.toStringAsFixed(2)),
        buildTextField(context, 'Robot Length', (value) {
          if (value != null && _prefs != null) {
            _prefs!.setDouble('robotLength', value);
            setState(() {
              _length = value;
            });
          }
          if (widget.onSettingsChanged != null) {
            widget.onSettingsChanged!.call();
          }
        }, _length.toStringAsFixed(2)),
        buildFieldImageDropdown(context),
        SwitchListTile(
          value: _holonomic,
          activeColor: Colors.indigoAccent,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          onChanged: (val) {
            _prefs!.setBool('holonomicMode', val);
            setState(() {
              _holonomic = val;
            });
            if (widget.onSettingsChanged != null) {
              widget.onSettingsChanged!.call();
            }
          },
          title: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('Holonomic Mode'),
          ),
        ),
        SwitchListTile(
          value: _generateJSON,
          activeColor: Colors.indigoAccent,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          onChanged: (val) {
            _prefs!.setBool('generateJSON', val);
            setState(() {
              _generateJSON = val;
            });
            if (widget.onSettingsChanged != null) {
              widget.onSettingsChanged!.call();
            }
            if (widget.onGenerationEnabled != null && val) {
              widget.onGenerationEnabled!.call();
            }
          },
          title: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('Generate WPILib JSON'),
          ),
        ),
        SwitchListTile(
          value: _generateCSV,
          activeColor: Colors.indigoAccent,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          onChanged: (val) {
            _prefs!.setBool('generateCSV', val);
            setState(() {
              _generateCSV = val;
            });
            if (widget.onSettingsChanged != null) {
              widget.onSettingsChanged!.call();
            }
            if (widget.onGenerationEnabled != null && val) {
              widget.onGenerationEnabled!.call();
            }
          },
          title: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('Generate CSV'),
          ),
        ),
      ],
    );
  }

  Widget buildTextField(BuildContext context, String label,
      ValueChanged? onSubmitted, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 24, 6),
      child: Container(
        height: 45,
        child: TextField(
          onSubmitted: (val) {
            if (onSubmitted != null) {
              var parsed = double.tryParse(val)!;
              onSubmitted.call(parsed);
            }
            _unfocus(context);
          },
          controller: TextEditingController(text: text)
            ..selection =
                TextSelection.fromPosition(TextPosition(offset: text.length)),
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

  Widget buildFieldImageDropdown(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 24, 0),
      child: Container(
        height: 45,
        child: Row(
          children: [
            Text(
              'Field Image:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                width: 129,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey),
                ),
                child: ExcludeFocus(
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(canvasColor: Colors.grey[800]),
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<FieldImage>(
                        value: _selectedField,
                        isExpanded: true,
                        underline: Container(),
                        icon: Icon(Icons.arrow_drop_down),
                        style: TextStyle(fontSize: 14),
                        onChanged: (FieldImage? newValue) {
                          setState(() {
                            _selectedField = newValue;
                          });
                        },
                        items: _fieldImages.map<DropdownMenuItem<FieldImage>>(
                            (FieldImage value) {
                          return DropdownMenuItem<FieldImage>(
                            value: value,
                            child: Text(value.name),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 2),
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.upload),
              splashRadius: 18,
              tooltip: 'Import Field Image',
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _unfocus(BuildContext context) {
    FocusScopeNode currentScope = FocusScope.of(context);
    if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
      FocusManager.instance.primaryFocus!.unfocus();
    }
  }
}
