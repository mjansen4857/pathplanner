import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/pages/nav_grid_page.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/pages/telemetry_page.dart';
import 'package:pathplanner/pages/welcome_page.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/dialogs/settings_dialog.dart';
import 'package:pathplanner/widgets/pplib_update_card.dart';
import 'package:pathplanner/widgets/update_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final String appVersion;
  final bool appStoreBuild;
  final SharedPreferences prefs;
  final ValueChanged<Color> onTeamColorChanged;

  const HomePage({
    required this.appVersion,
    required this.appStoreBuild,
    required this.prefs,
    required this.onTeamColorChanged,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  Directory? _projectDir;
  late Directory _deployDir;
  Size _robotSize = const Size(0.75, 1.0);
  bool _holonomicMode = false;
  bool _isWpiLib = false;
  final SecureBookmarks? _bookmarks =
      Platform.isMacOS ? SecureBookmarks() : null;
  final List<FieldImage> _fieldImages = FieldImage.offialFields();
  FieldImage? _fieldImage;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  final GlobalKey _key = GlobalKey();
  static const _settingsDir = '.pathplanner/settings.json';
  int _selectedPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.ease);

    var fs = const LocalFileSystem();

    _loadFieldImages().then((_) async {
      String? projectDir = widget.prefs.getString('currentProjectDir');
      if (projectDir != null && Platform.isMacOS) {
        if (widget.prefs.getString('macOSBookmark') != null) {
          await _bookmarks!
              .resolveBookmark(widget.prefs.getString('macOSBookmark')!);

          await _bookmarks!
              .startAccessingSecurityScopedResource(fs.file(projectDir));
        } else {
          projectDir = null;
        }
      }

      if (projectDir == null || !fs.directory(projectDir).existsSync()) {
        projectDir = await Navigator.push(
          _key.currentContext!,
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => WelcomePage(
              appVersion: widget.appVersion,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );

        widget.prefs.setString('currentProjectDir', projectDir!);

        if (Platform.isMacOS) {
          // Bookmark project on macos so it can be accessed again later
          String bookmark = await _bookmarks!.bookmark(fs.file(projectDir));
          widget.prefs.setString('macOSBookmark', bookmark);
        }
      }

      // Check if WPILib project
      if (fs.file(join(projectDir, 'build.gradle')).existsSync()) {
        _deployDir = fs.directory(
            join(projectDir, 'src', 'main', 'deploy', 'pathplanner'));
      } else {
        _deployDir = fs.directory(join(projectDir, 'deploy', 'pathplanner'));
      }

      // Assure that a navgrid file is present
      File navgridFile = fs.file(join(_deployDir.path, 'navgrid.json'));
      navgridFile.exists().then((value) async {
        if (!value) {
          // Load default grid
          String fileContent = await DefaultAssetBundle.of(this.context)
              .loadString('resources/default_navgrid.json');
          fs
              .file(join(_deployDir.path, 'navgrid.json'))
              .writeAsString(fileContent);
        }
      });

      setState(() {
        _projectDir = fs.directory(projectDir!);

        _loadProjectSettingsFromFile(_projectDir!);

        String? selectedFieldName = widget.prefs.getString('fieldImage');
        if (selectedFieldName != null) {
          for (FieldImage image in _fieldImages) {
            if (image.name == selectedFieldName) {
              _fieldImage = image;
              break;
            }
          }
        }

        _animController.forward();
      });

      if (!(widget.prefs.getBool('seen2023Warning') ?? false) && mounted) {
        showDialog(
            context: this.context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: const Text('Non-standard Field Mirroring'),
                content: const SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          'The 2023 FRC game has non-standard field mirroring that would prevent using the same auto path for both alliances.'),
                      SizedBox(height: 16),
                      Text(
                          'To work around this, PathPlannerLib has added functionality to automatically transform paths to work for the correct alliance depending on the current alliance color while using PathPlannerLib\'s path following commands.'),
                      SizedBox(height: 16),
                      Text(
                          'In order for this to work correctly, you MUST create all of your paths on the blue (left) side of the field.'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.prefs.setBool('seen2023Warning', true);
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            });
      }
    });
  }

  @override
  void dispose() {
    var fs = const LocalFileSystem();

    if (Platform.isMacOS && _projectDir != null) {
      _bookmarks!
          .stopAccessingSecurityScopedResource(fs.file(_projectDir!.path));
    }

    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      appBar: CustomAppBar(
        titleWidget: Text(
          _projectDir == null ? 'PathPlanner' : basename(_projectDir!.path),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ),
      drawer: _projectDir == null ? null : _buildDrawer(context),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        NavigationDrawer(
          selectedIndex: _selectedPage,
          onDestinationSelected: (idx) {
            setState(() {
              _selectedPage = idx;
              _pageController.animateToPage(_selectedPage,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut);
            });
          },
          children: [
            DrawerHeader(
              child: Stack(
                children: [
                  Align(
                    alignment: FractionalOffset.bottomLeft,
                    child: Text(
                      'v${widget.appVersion}',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                  Align(
                    alignment: FractionalOffset.bottomRight,
                    child: StreamBuilder(
                      stream: PPLibTelemetry.connectionStatusStream(),
                      builder: (context, snapshot) {
                        bool connected =
                            snapshot.hasData ? snapshot.data! : false;

                        if (connected) {
                          return const Tooltip(
                            message: 'Connected to Robot',
                            child: Icon(
                              Icons.lan,
                              size: 20,
                              color: Colors.green,
                            ),
                          );
                        } else {
                          return const Tooltip(
                            message: 'Not Connected to Robot',
                            child: Icon(
                              Icons.lan_outlined,
                              size: 20,
                              color: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            basename(_projectDir!.path),
                            style: const TextStyle(
                              fontSize: 20,
                            ),
                          ),
                        ),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: colorScheme.onPrimaryContainer,
                              backgroundColor: colorScheme.primaryContainer,
                            ),
                            onPressed: () {
                              _openProjectDialog(context);
                            },
                            child: const Text('Switch Project')),
                        Expanded(
                          flex: 4,
                          child: Container(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const NavigationDrawerDestination(
              icon: Icon(Icons.folder_outlined),
              label: Text('Project Browser'),
            ),
            const NavigationDrawerDestination(
              icon: Icon(Icons.bar_chart),
              label: Text('Telemetry'),
            ),
            const NavigationDrawerDestination(
              icon: Icon(Icons.grid_on),
              label: Text('Navigation Grid'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SettingsDialog(
                      prefs: widget.prefs,
                      onTeamColorChanged: widget.onTeamColorChanged,
                      fieldImages: _fieldImages,
                      selectedField: _fieldImage ?? FieldImage.defaultField,
                      onFieldSelected: (FieldImage image) {
                        setState(() {
                          _fieldImage = image;
                          if (!_fieldImages.contains(image)) {
                            _fieldImages.add(image);
                          }
                          widget.prefs.setString('fieldImage', image.name);
                        });
                      },
                      onSettingsChanged: _onProjectSettingsChanged,
                    );
                  },
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
                elevation: 4.0,
                fixedSize: const Size(270, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_projectDir != null) {
      return Stack(
        children: [
          Center(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ProjectPage(
                  key: ValueKey(_projectDir!.path),
                  prefs: widget.prefs,
                  fieldImage: _fieldImage ?? FieldImage.defaultField,
                  deployDirectory: _deployDir,
                ),
                const TelemetryPage(),
                NavGridPage(
                  deployDirectory: _deployDir,
                ),
              ],
            ),
          ),
          Align(
            alignment: FractionalOffset.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UpdateCard(currentVersion: widget.appVersion),
                if (_isWpiLib && !widget.appStoreBuild)
                  PPLibUpdateCard(projectDir: _projectDir!),
              ],
            ),
          ),
        ],
      );
    } else {
      return Container();
    }
  }

  bool _isWpiLibProject(Directory projectDir) {
    var fs = const LocalFileSystem();
    File buildFile = fs.file(join(projectDir.path, 'build.gradle'));

    return buildFile.existsSync();
  }

  void _onProjectSettingsChanged() {
    _loadSettingsFromPrefs();
    _saveProjectSettingsToFile(_projectDir!);
  }

  void _loadSettingsFromPrefs() {
    setState(() {
      _robotSize = Size(
        widget.prefs.getDouble('robotWidth') ?? 0.75,
        widget.prefs.getDouble('robotLength') ?? 1.0,
      );
      _holonomicMode = widget.prefs.getBool('holonomicMode') ?? false;
    });
  }

  void _loadProjectSettingsFromFile(Directory projectDir) async {
    var fs = const LocalFileSystem();
    File settingsFile = fs.file(join(projectDir.path, _settingsDir));

    if (await settingsFile.exists()) {
      try {
        final fileContents = await settingsFile.readAsString();
        final json = jsonDecode(fileContents);

        widget.prefs
            .setDouble('robotWidth', json['robotWidth']?.toDouble() ?? 0.75);
        widget.prefs
            .setDouble('robotLength', json['robotLength']?.toDouble() ?? 1.0);
        widget.prefs.setBool('holonomicMode', json['holonomicMode'] ?? false);
      } catch (err, stack) {
        Log.error(
            'An error occurred while loading project settings', err, stack);
      }
    }

    _loadSettingsFromPrefs();
  }

  void _saveProjectSettingsToFile(Directory projectDir) {
    var fs = const LocalFileSystem();
    File settingsFile = fs.file(join(projectDir.path, _settingsDir));

    if (!settingsFile.existsSync()) {
      settingsFile.createSync(recursive: true);
    }

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');

    Map<String, dynamic> settings = {
      'robotWidth': _robotSize.width,
      'robotLength': _robotSize.height,
      'holonomicMode': _holonomicMode,
    };

    settingsFile.writeAsString(encoder.convert(settings)).then((_) {
      Log.debug('Wrote project settings to file');
    }).catchError((err) {
      Log.error('Error writing project settings', err);
    });
  }

  void _openProjectDialog(BuildContext context) async {
    var fs = const LocalFileSystem();
    String initialDirectory = _projectDir?.path ?? fs.currentDirectory.path;
    String? projectFolder = await getDirectoryPath(
        confirmButtonText: 'Open Project', initialDirectory: initialDirectory);
    if (projectFolder != null) {
      widget.prefs.setString('currentProjectDir', projectFolder);

      if (Platform.isMacOS) {
        // Bookmark project on macos so it can be accessed again later
        String bookmark = await _bookmarks!.bookmark(fs.file(projectFolder));
        widget.prefs.setString('macOSBookmark', bookmark);
      }

      setState(() {
        _projectDir = fs.directory(projectFolder);
        _loadProjectSettingsFromFile(_projectDir!);
        _isWpiLib = _isWpiLibProject(_projectDir!);
      });
    }
  }

  Future<void> _loadFieldImages() async {
    var fs = const LocalFileSystem();
    Directory appDir =
        fs.directory((await getApplicationSupportDirectory()).path);
    Directory imagesDir = fs.directory(join(appDir.path, 'custom_fields'));

    imagesDir.createSync(recursive: true);

    List<FileSystemEntity> fileEntities = imagesDir.listSync();
    for (FileSystemEntity e in fileEntities) {
      _fieldImages.add(FieldImage.custom(fs.file(e.path)));
    }
  }
}
