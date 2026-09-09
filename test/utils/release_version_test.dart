import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/utils/release_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release API follows the fork repository', () {
    expect(
      Api.latestApp,
      'https://api.github.com/repos/${Constants.githubRepository}/releases/latest',
    );
  });
  test('numeric ordering covers flavor and upstream increments', () {
    final versions = [
      '2.1.3.0',
      '2.1.3.1',
      '2.1.3.9',
      '2.1.3.10',
      '2.1.4.0',
      '2.2.0.0',
      '3.0.0.0',
    ];
    for (var i = 1; i < versions.length; i++) {
      expect(
        ReleaseVersion.parse(versions[i])!
            .compareTo(ReleaseVersion.parse(versions[i - 1])!),
        greaterThan(0),
      );
    }
    expect(
      ReleaseVersion.parse('v2.1.3.0')!
          .compareTo(ReleaseVersion.parse('2.1.3.0')!),
      0,
    );
  });
  test('first flavor release replaces legacy hash builds', () {
    for (final old in ['2.1.3', '2.1.3-dfb675530', '2.1.3-dfb675530-dirty']) {
      expect(
        ReleaseVersion.parse('2.1.3.0')!
            .compareTo(ReleaseVersion.parse(old, allowLegacy: true)!),
        greaterThan(0),
      );
    }
  });
  test('invalid and prerelease remote tags are rejected', () {
    for (final tag in [
      '',
      'SNAPSHOT',
      '2.1.3',
      'v2.1.3.0-beta',
      '2.1.3.0.1',
      '2.1.3.-1',
    ]) {
      expect(ReleaseVersion.parse(tag), isNull);
    }
  });
}
