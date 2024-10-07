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
import 'package:pathplanner/services/update_checker.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/dialogs/settings_dialog.dart';
import 'package:pathplanner/widgets/pplib_update_card.dart';
import 'package:pathplanner/widgets/update_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final String appVersion;
  final SharedPreferences prefs;
  final ValueChanged<Color> onTeamColorChanged;
  final FileSystem fs;
  final ChangeStack undoStack;
  final PPLibTelemetry telemetry;
  final UpdateChecker updateChecker;

  const HomePage({
    required this.appVersion,
    required this.prefs,
    required this.onTeamColorChanged,
    required this.fs,
    required this.undoStack,
    required this.telemetry,
    required this.updateChecker,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  Directory? _projectDir;
  late Directory _pathplannerDir;
  late Directory _choreoDir;
  final SecureBookmarks? _bookmarks =
      Platform.isMacOS ? SecureBookmarks() : null;
  final List<FieldImage> _fieldImages = FieldImage.offialFields();
  FieldImage? _fieldImage;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  final GlobalKey _key = GlobalKey();
  static const _settingsDir = 'settings.json';
  int _selectedPage = 0;
  final PageController _pageController = PageController();
  late bool _hotReload;

  FileSystem get fs => widget.fs;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.ease);

    _loadFieldImages().then((_) async {
      String? projectDir = widget.prefs.getString(PrefsKeys.currentProjectDir);
      if (projectDir != null && Platform.isMacOS && fs is LocalFileSystem) {
        if (widget.prefs.getString(PrefsKeys.macOSBookmark) != null) {
          try {
            await _bookmarks!.resolveBookmark(
                widget.prefs.getString(PrefsKeys.macOSBookmark)!);

            await _bookmarks
                .startAccessingSecurityScopedResource(fs.file(projectDir));
          } catch (e) {
            Log.error('Failed to resolve secure bookmarks', e);
            projectDir = null;
          }
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
      }

      _initFromProjectDir(projectDir!);

      setState(() {
        _hotReload = widget.prefs.getBool(PrefsKeys.hotReloadEnabled) ??
            Defaults.hotReloadEnabled;

        String? selectedFieldName =
            widget.prefs.getString(PrefsKeys.fieldImage);
        if (selectedFieldName != null) {
          for (FieldImage image in _fieldImages) {
            if (image.name == selectedFieldName) {
              _fieldImage = image;
              break;
            }
          }
        }
      });

      _animController.forward();

      if (!(widget.prefs.getBool(PrefsKeys.seen2024ResetPopup) ?? false) &&
          _fieldImage?.name != 'Crescendo' &&
          mounted) {
        showDialog(
          context: this.context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('New Field Image Available'),
              content: const SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        'The 2024 field image is now available. Would you like to set your field image to the 2024 field and reset the default navgrid for the 2024 field?'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.prefs.setBool(PrefsKeys.seen2024ResetPopup, true);
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    widget.prefs.setBool(PrefsKeys.seen2024ResetPopup, true);
                    setState(() {
                      _fieldImage = FieldImage.defaultField;
                      widget.prefs
                          .setString(PrefsKeys.fieldImage, _fieldImage!.name);
                    });

                    // Load default grid
                    String fileContent =
                        await DefaultAssetBundle.of(this.context)
                            .loadString('resources/default_navgrid.json');
                    fs
                        .file(join(_pathplannerDir.path, 'navgrid.json'))
                        .writeAsString(fileContent);
                  },
                  child: const Text('Yes (Recommended)'),
                ),
              ],
            );
          },
        );
      }

      if (!(widget.prefs.getBool(PrefsKeys.seen2024Warning) ?? false) &&
          mounted) {
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
                          'The 2024 FRC game has non-standard field mirroring that would prevent using the same auto path for both alliances without transformation.'),
                      SizedBox(height: 16),
                      Text(
                          'PathPlannerLib has functionality to automatically transform paths to work for the correct alliance depending on the current alliance color.'),
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
                      widget.prefs.setBool(PrefsKeys.seen2024Warning, true);
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
          onDestinationSelected: _handleDestinationSelected,
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          children: [
            _buildDrawerHeader(colorScheme),
            ..._buildNavigationDestinations(),
          ],
        ),
        _buildBottomButtons(colorScheme),
      ],
    );
  }

  Widget _buildDrawerHeader(ColorScheme colorScheme) {
    return DrawerHeader(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                basename(_projectDir!.path),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'v${widget.appVersion}',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                tooltip: 'Open Project',
                onPressed: () => _openProjectDialog(this.context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavigationDestinations() {
    return [
      const NavigationDrawerDestination(
        icon: Icon(Icons.folder_rounded),
        label: Text('Project Browser'),
      ),
      const SizedBox(height: 5),
      NavigationDrawerDestination(
        icon: Icon(
          _getConnectedIcon(widget.telemetry.isConnected),
          color: _getConnectedIconColor(widget.telemetry.isConnected),
        ),
        label: const Text('Telemetry'),
      ),
      const SizedBox(height: 5),
      const NavigationDrawerDestination(
        icon: Icon(Icons.grid_on_rounded),
        label: Text('Navigation Grid'),
      ),
    ];
  }

  Widget _buildBottomButtons(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
        child: Row(
          children: [
            _buildButton(
              onPressed: () => launchUrl(Uri.parse('https://pathplanner.dev')),
              icon: const Icon(Icons.description),
              label: 'Docs',
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            _buildButton(
              onPressed: () {
                Navigator.pop(this.context);
                _showSettingsDialog();
              },
              icon: const Icon(Icons.settings),
              label: 'Settings',
              backgroundColor: colorScheme.surfaceContainer,
              foregroundColor: colorScheme.onSurface,
              surfaceTintColor: colorScheme.surfaceTint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    Color? surfaceTintColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(141, 50),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        surfaceTintColor: surfaceTintColor,
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    setState(() {
      _selectedPage = index;
      _pageController.animateToPage(
        _selectedPage,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
      );
    });
    Navigator.pop(this.context);
  }

  IconData _getConnectedIcon(bool isConnected) {
    return isConnected ? Icons.lan : Icons.lan_outlined;
  }

  Color _getConnectedIconColor(bool isConnected) {
    return isConnected ? Colors.green : Colors.red;
  }

  void _showSettingsDialog() {
    showDialog(
      context: this.context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context), // Use the current theme
          child: SettingsDialog(
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
                widget.prefs.setString(PrefsKeys.fieldImage, image.name);
              });
            },
            onSettingsChanged: _onProjectSettingsChanged,
          ),
        );
      },
    ).then((_) {
      // Ensure the app rebuilds correctly after dialog is closed
      setState(() {});
    });
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
                  key: ValueKey(_projectDir!.path.hashCode),
                  prefs: widget.prefs,
                  fieldImage: _fieldImage ?? FieldImage.defaultField,
                  pathplannerDirectory: _pathplannerDir,
                  choreoDirectory: _choreoDir,
                  fs: fs,
                  undoStack: widget.undoStack,
                  telemetry: widget.telemetry,
                  hotReload: _hotReload,
                  onFoldersChanged: () =>
                      _saveProjectSettingsToFile(_projectDir!),
                  simulatePath: true,
                  watchChorDir: true,
                ),
                TelemetryPage(
                  fieldImage: _fieldImage ?? FieldImage.defaultField,
                  telemetry: widget.telemetry,
                  prefs: widget.prefs,
                ),
                NavGridPage(
                  deployDirectory: _pathplannerDir,
                  fs: fs,
                  fieldImage: _fieldImage ?? FieldImage.defaultField,
                ),
              ],
            ),
          ),
          Align(
            alignment: FractionalOffset.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UpdateCard(
                    currentVersion: widget.appVersion,
                    updateChecker: widget.updateChecker,
                  ),
                  PPLibUpdateCard(
                    projectDir: _projectDir!,
                    fs: widget.fs,
                    updateChecker: widget.updateChecker,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return Container();
    }
  }

  void _onProjectSettingsChanged() {
    ProjectPage.settingsUpdated = true;
    _saveProjectSettingsToFile(_projectDir!);

    String serverAddress = widget.prefs.getString(PrefsKeys.ntServerAddress) ??
        Defaults.ntServerAddress;
    if (serverAddress != widget.telemetry.getServerAddress()) {
      widget.telemetry.setServerAddress(serverAddress);
    }

    setState(() {
      _hotReload = widget.prefs.getBool(PrefsKeys.hotReloadEnabled) ??
          Defaults.hotReloadEnabled;
    });
  }

  Future<void> _loadProjectSettingsFromFile(Directory projectDir) async {
    File settingsFile = fs.file(join(_pathplannerDir.path, _settingsDir));

    var json = {};

    if (await settingsFile.exists()) {
      try {
        final fileContents = await settingsFile.readAsString();
        json = jsonDecode(fileContents);
      } catch (err, stack) {
        Log.error(
            'An error occurred while loading project settings', err, stack);
      }
    }

    widget.prefs.setDouble(PrefsKeys.robotWidth,
        json[PrefsKeys.robotWidth]?.toDouble() ?? Defaults.robotWidth);
    widget.prefs.setDouble(PrefsKeys.robotLength,
        json[PrefsKeys.robotLength]?.toDouble() ?? Defaults.robotLength);
    widget.prefs.setBool(PrefsKeys.holonomicMode,
        json[PrefsKeys.holonomicMode] ?? Defaults.holonomicMode);
    widget.prefs.setStringList(
        PrefsKeys.pathFolders,
        (json[PrefsKeys.pathFolders] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            Defaults.pathFolders);
    widget.prefs.setStringList(
        PrefsKeys.autoFolders,
        (json[PrefsKeys.autoFolders] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            Defaults.autoFolders);
    widget.prefs.setDouble(PrefsKeys.defaultMaxVel,
        json[PrefsKeys.defaultMaxVel]?.toDouble() ?? Defaults.defaultMaxVel);
    widget.prefs.setDouble(
        PrefsKeys.defaultMaxAccel,
        json[PrefsKeys.defaultMaxAccel]?.toDouble() ??
            Defaults.defaultMaxAccel);
    widget.prefs.setDouble(
        PrefsKeys.defaultMaxAngVel,
        json[PrefsKeys.defaultMaxAngVel]?.toDouble() ??
            Defaults.defaultMaxAngVel);
    widget.prefs.setDouble(
        PrefsKeys.defaultMaxAngAccel,
        json[PrefsKeys.defaultMaxAngAccel]?.toDouble() ??
            Defaults.defaultMaxAngAccel);
    widget.prefs.setDouble(PrefsKeys.robotMass,
        json[PrefsKeys.robotMass]?.toDouble() ?? Defaults.robotMass);
    widget.prefs.setDouble(PrefsKeys.robotMOI,
        json[PrefsKeys.robotMOI]?.toDouble() ?? Defaults.robotMOI);
    widget.prefs.setDouble(PrefsKeys.robotWheelbase,
        json[PrefsKeys.robotWheelbase]?.toDouble() ?? Defaults.robotWheelbase);
    widget.prefs.setDouble(
        PrefsKeys.robotTrackwidth,
        json[PrefsKeys.robotTrackwidth]?.toDouble() ??
            Defaults.robotTrackwidth);
    widget.prefs.setDouble(
        PrefsKeys.driveWheelRadius,
        json[PrefsKeys.driveWheelRadius]?.toDouble() ??
            Defaults.driveWheelRadius);
    widget.prefs.setDouble(PrefsKeys.driveGearing,
        json[PrefsKeys.driveGearing]?.toDouble() ?? Defaults.driveGearing);
    widget.prefs.setDouble(PrefsKeys.maxDriveSpeed,
        json[PrefsKeys.maxDriveSpeed]?.toDouble() ?? Defaults.maxDriveSpeed);
    widget.prefs.setString(PrefsKeys.driveMotor,
        json[PrefsKeys.driveMotor] ?? Defaults.driveMotor);
    widget.prefs.setDouble(
        PrefsKeys.driveCurrentLimit,
        json[PrefsKeys.driveCurrentLimit]?.toDouble() ??
            Defaults.driveCurrentLimit);
    widget.prefs.setDouble(PrefsKeys.wheelCOF,
        json[PrefsKeys.wheelCOF]?.toDouble() ?? Defaults.wheelCOF);
  }

  void _saveProjectSettingsToFile(Directory projectDir) {
    File settingsFile = fs.file(join(_pathplannerDir.path, _settingsDir));

    if (!settingsFile.existsSync()) {
      settingsFile.createSync(recursive: true);
    }

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');

    Map<String, dynamic> settings = {
      PrefsKeys.robotWidth:
          widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth,
      PrefsKeys.robotLength:
          widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength,
      PrefsKeys.holonomicMode: widget.prefs.getBool(PrefsKeys.holonomicMode) ??
          Defaults.holonomicMode,
      PrefsKeys.pathFolders:
          widget.prefs.getStringList(PrefsKeys.pathFolders) ??
              Defaults.pathFolders,
      PrefsKeys.autoFolders:
          widget.prefs.getStringList(PrefsKeys.autoFolders) ??
              Defaults.autoFolders,
      PrefsKeys.defaultMaxVel:
          widget.prefs.getDouble(PrefsKeys.defaultMaxVel) ??
              Defaults.defaultMaxVel,
      PrefsKeys.defaultMaxAccel:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAccel) ??
              Defaults.defaultMaxAccel,
      PrefsKeys.defaultMaxAngVel:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAngVel) ??
              Defaults.defaultMaxAngVel,
      PrefsKeys.defaultMaxAngAccel:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAngAccel) ??
              Defaults.defaultMaxAccel,
      PrefsKeys.robotMass:
          widget.prefs.getDouble(PrefsKeys.robotMass) ?? Defaults.robotMass,
      PrefsKeys.robotMOI:
          widget.prefs.getDouble(PrefsKeys.robotMOI) ?? Defaults.robotMOI,
      PrefsKeys.robotWheelbase:
          widget.prefs.getDouble(PrefsKeys.robotWheelbase) ??
              Defaults.robotWheelbase,
      PrefsKeys.robotTrackwidth:
          widget.prefs.getDouble(PrefsKeys.robotTrackwidth) ??
              Defaults.robotTrackwidth,
      PrefsKeys.driveWheelRadius:
          widget.prefs.getDouble(PrefsKeys.driveWheelRadius) ??
              Defaults.driveWheelRadius,
      PrefsKeys.driveGearing: widget.prefs.getDouble(PrefsKeys.driveGearing) ??
          Defaults.driveGearing,
      PrefsKeys.maxDriveSpeed:
          widget.prefs.getDouble(PrefsKeys.maxDriveSpeed) ??
              Defaults.maxDriveSpeed,
      PrefsKeys.driveMotor:
          widget.prefs.getString(PrefsKeys.driveMotor) ?? Defaults.driveMotor,
      PrefsKeys.driveCurrentLimit:
          widget.prefs.getDouble(PrefsKeys.driveCurrentLimit) ??
              Defaults.driveCurrentLimit,
      PrefsKeys.wheelCOF:
          widget.prefs.getDouble(PrefsKeys.wheelCOF) ?? Defaults.wheelCOF,
    };

    settingsFile.writeAsString(encoder.convert(settings)).then((_) {
      Log.debug('Wrote project settings to file');
    }).catchError((err) {
      Log.error('Error writing project settings', err);
    });
  }

  void _openProjectDialog(BuildContext context) async {
    String initialDirectory = _projectDir?.path ?? fs.currentDirectory.path;
    String? projectFolder = await getDirectoryPath(
        confirmButtonText: 'Open Project', initialDirectory: initialDirectory);
    if (projectFolder != null) {
      _initFromProjectDir(projectFolder);
    }
  }

  void _initFromProjectDir(String projectDir) async {
    widget.prefs.setString(PrefsKeys.currentProjectDir, projectDir);

    if (Platform.isMacOS) {
      // Bookmark project on macos so it can be accessed again later
      String bookmark = await _bookmarks!.bookmark(fs.file(projectDir));
      widget.prefs.setString(PrefsKeys.macOSBookmark, bookmark);
    }

    // Check if WPILib project
    setState(() {
      if (fs.file(join(projectDir, 'build.gradle')).existsSync()) {
        _pathplannerDir = fs.directory(
            join(projectDir, 'src', 'main', 'deploy', 'pathplanner'));
        _choreoDir =
            fs.directory(join(projectDir, 'src', 'main', 'deploy', 'choreo'));
      } else {
        _pathplannerDir =
            fs.directory(join(projectDir, 'deploy', 'pathplanner'));
        _choreoDir = fs.directory(join(projectDir, 'deploy', 'choreo'));
      }
    });

    await _pathplannerDir.create(recursive: true);

    // Assure that a navgrid file is present
    File navgridFile = fs.file(join(_pathplannerDir.path, 'navgrid.json'));
    navgridFile.exists().then((value) async {
      if (!value && mounted) {
        // Load default grid
        String fileContent = await DefaultAssetBundle.of(this.context)
            .loadString('resources/default_navgrid.json');
        fs
            .file(join(_pathplannerDir.path, 'navgrid.json'))
            .writeAsString(fileContent);
      }
    });

    // Clear event names
    if (projectDir != _projectDir?.path) {
      ProjectPage.events.clear();
    }

    setState(() {
      _projectDir = fs.directory(projectDir);
    });

    await _loadProjectSettingsFromFile(_projectDir!);
  }

  Future<void> _loadFieldImages() async {
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
