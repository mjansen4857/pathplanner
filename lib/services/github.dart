import 'package:github/github.dart';
import 'package:version/version.dart';

class GitHubAPI {
  static final GitHub _github = GitHub();

  static Future<bool> isUpdateAvailable(String currentVersion) async {
    try {
      Release latestRelease = await _github.repositories
          .getLatestRelease(RepositorySlug('mjansen4857', 'pathplanner'));
      String latestVersion = latestRelease.tagName!.substring(1);

      print('Current Version: $currentVersion, Latest Release: $latestVersion');

      Version current = Version.parse(currentVersion);
      Version latest = Version.parse(latestVersion);

      return latest > current;
    } catch (_) {
      return false;
    }
  }
}
