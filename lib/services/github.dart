import 'package:github/github.dart';
import 'package:version/version.dart';

class GitHubAPI {
  static GitHub _github = GitHub();

  static Future<bool> isUpdateAvailable(String currentVersion) async {
    Release latestRelease = await _github.repositories
        .getLatestRelease(RepositorySlug('mjansen4857', 'pathplanner'));
    String latestVersion = latestRelease.tagName.substring(1);

    print('Current Version: $currentVersion, Latest Release: $latestVersion');

    Version current = Version.parse(currentVersion);
    Version latest = Version.parse(latestVersion);

    return latest > current;
  }
}
