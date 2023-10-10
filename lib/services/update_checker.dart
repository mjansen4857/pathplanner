import 'dart:convert';

import 'package:file/file.dart';
import 'package:github/github.dart';
import 'package:path/path.dart';
import 'package:pathplanner/services/log.dart';
import 'package:version/version.dart';
import 'package:http/http.dart' as http;

class UpdateChecker {
  final GitHub _github;
  static const String _jsonURL =
      'https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib.json';

  UpdateChecker() : _github = GitHub();

  Future<bool> isGuiUpdateAvailable(String currentVersion) async {
    try {
      Release latestRelease = await _github.repositories
          .getLatestRelease(RepositorySlug('mjansen4857', 'pathplanner'));
      String latestVersion = latestRelease.tagName!.substring(1);

      Log.verbose(
          'Current App Version: $currentVersion, Latest Release: $latestVersion');

      Version current = Version.parse(currentVersion);
      Version latest = Version.parse(latestVersion);

      if (current.major == 0 && current.minor == 0 && current.patch == 0) {
        // Dev build
        return false;
      }

      return latest > current;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isPPLibUpdateAvailable(
      {required Directory projectDir, required FileSystem fs}) async {
    File vendorDepFile =
        fs.file(join(projectDir.path, 'vendordeps', 'PathplannerLib.json'));

    if (await vendorDepFile.exists()) {
      String fileContent = await vendorDepFile.readAsString();
      Map<String, dynamic> localJson = jsonDecode(fileContent);

      try {
        String remote = await http.read(Uri.parse(_jsonURL));
        Map<String, dynamic> remoteJson = jsonDecode(remote);

        String localVersion = localJson['version'];
        String remoteVersion = remoteJson['version'];

        Log.verbose(
            'Current PPLib Version: $localVersion, Latest Release: $remoteVersion');

        if (Version.parse(remoteVersion) > Version.parse(localVersion)) {
          return true;
        }
      } catch (e) {
        // Can't get file. Probably not connected to internet
      }
    }

    return false;
  }
}
